#!/bin/bash
#
# Build several PKGBUILDs together.
# The correct dependency order is found and needed dependencies built first.
# Everything built is exported to a local file:// repo at $PKGDEST.
#
# This means a group of related unofficial/private packages can all be built without
# disrupting the build system too much -- makepkg requires tracking down and installing
# the dependencies one by one and pikaur can find them automatically but only if they're on the AUR.
#
# SPDX-License-Identifier: GPL-3.0-or-later
# This incorporates code from the archlinux devtools project.

# TODO:
# - [ ] Provide -c (clean container between builds) as a flag
# - [ ] Bug: setting PKGDEST anywhere under /tmp breaks in odd ways?
# - [ ] try to be smarter about rebuilds:
#  - there's no need to rebuild dependencies if they haven't changed
#    but the current logic generates a version number the same for EVERYONE
#    Only build a. things requested on the command line b. their *missing* dependencies


# Questions writing this raises for me:
# Q: how did Arch bootstrap its repos?
# Q: could arch bootstrap its repos from source at the moment?
#    Would it require someone to manually work out the build order
#    and manually run `makepkg` for each of the thousands of packages?
# Q: Or could arch bootstrap from source with `makepkg -d`?

# load makepkg lib, for below
MAKEPKG_LIBRARY=${MAKEPKG_LIBRARY:-'/usr/share/makepkg'}
# Import libmakepkg
for lib in "$MAKEPKG_LIBRARY"/*.sh; do
	source "$lib"
done
source /etc/makepkg.conf

set -eo pipefail # strict-ish mode

parsedeps() {
	if [[ -f "$1/PKGBUILD" ]]; then
		pkgname=() depends=() makedepends=() optdepends=()
		cd "$1"
		. "PKGBUILD" >&2
		cd - >/dev/null
		for dep in "${depends[@]}"; do
			# lose the version comparator, if any
			depname=${dep%%[<>=]*}
			if [[ -f "$depname/PKGBUILD" ]]; then echo "$depname (depends)"; fi
		done
		for dep in "${makedepends[@]}"; do
			# lose the version comparator, if any
			depname=${dep%%[<>=]*}
			if [[ -f "$depname/PKGBUILD" ]]; then echo "$depname (makedepends)"; fi
		done
		for dep in "${optdepends[@]/:*}"; do
			# lose the version comaparator, if any
			depname=${dep%%[<>=]*}
			if [[ -f "$depname/PKGBUILD" ]]; then echo "$depname (optdepends)"; fi
		done
	fi
}

finddeps() {
    # Find upstream dependencies, write as edges "B" "A" meaning "A depends on B"
    #
    # Arch's devtools has a `finddeps` but it finds downstream dependencies,
    # and it needs to examine an existing repo database, because it's meant
    # as a crutch for bumping the build when updating a single package, by hand.
    # It can't help bootstrap repo from PKGBUILD sources, but that's what we're doing here.

    local target dep kind
    for target in "$@"; do
      if [ -f "$target/PKGBUILD" ]; then
        echo "_" "$target" # ensure $target is always visible to tsort, by adding a dummy dependency
        parsedeps "$target" | while read -r dep kind; do

          if [ "$kind" = "(makedepends)" ] || [ "$kind" = "(depends)" ]; then
            # declare $target depends on $dep
            echo "$dep" "$target"
          fi

          # recurse:
          finddeps "$dep"
        done
      fi
    done
}

findtops() {
  # find the TOP LEVEL nodes in a tsort(1) input
  awk '
  $1 != "_" {       # ignore dummy dep
      nodes[$2]=1;  # right = parents
      deps[$1]=1;   # left = dependencies
  }
  END {
      # compute nodes - deps
      for (n in nodes)
          if (!deps[n]) print n;
  }
  '
}


# Based on https://wiki.archlinux.org/title/DeveloperWiki:Building_in_a_clean_chroot#Classic_way
#
# There's `pkgctl build`, `archbuild` which are supposed to be more convenient
# but they are only really designed for working against the Arch repos, and only
# one package at a time. This needs to work with multiple local packages with multiple
# local dependencies.
# And there's `arch-rebuild-order` to find related, but it finds *downstream*
# packages and needs an existing pacman DB, whereas I want to start from source
# only and build up, and ideally only rebuild the packages necessary for the device
# I'm imaging or updating at the moment.

# packages are output to $PKGDEST; _additionally_ a repo is built there.
#: "${PKGDEST:=/var/cache/pacman/site}"  # default value
: "${PKGDEST:=$(pwd)/pkg}"  # default value

PKGDEST="$(realpath "$PKGDEST")"
export PKGDEST

mkdir -p "$PKGDEST"
repo-add "$PKGDEST"/site.db.tar.zst # init repo if needed


# Configure makechrootpkg's container
CHROOT=/var/lib/archbuild/site
sudo mkdir -p "$CHROOT"
if [ ! -d "$CHROOT"/root ]; then
  # construct a new build container
  mkarchroot "$CHROOT"/root base-devel  # NB: this calls `sudo`
fi
# insert the output path so downstream local packages can depend on local packages.
# arch-nspawn parses pacman.conf and automagically bind-mounts any paths mentioned
# into the container at the *same path*.
#
#   _Alternate rejected solution_: adding just `Include = /etc/pacman.d/site.conf`.
#   and putting the repo details in there. arch-nspawn parses pacman.conf from
#   _outside_ the container, where /etc/pacman.d/site.conf doesn't exist. Too bad,
#   it would be cleaner...
#
for U in root "$USER"; do
if ! [ -d "$CHROOT"/"$U" ]; then continue; fi
sudo arch-chroot "$CHROOT"/"$U" sed -i '/# --- BEGIN makechrootpkg ---/,/# --- END makechrootpkg ---/{d}' /etc/pacman.conf
sudo arch-chroot "$CHROOT"/"$U" tee -a /etc/pacman.conf >/dev/null <<EOF
# --- BEGIN makechrootpkg ---
[site]
# the arch devtools magically recognize directories in the containerized
# pacman.conf and _bind mount_ them to the same paths inside as out.
Server = file://$PKGDEST
# Disable signature checking on local packages -- because we don't have signing configured
SigLevel = Optional TrustAll
# --- END makechrootpkg ---
EOF
done

## Extend makechrootpkg's sudo privileges until
## done, meaning the build can be left unattended.
( while true; do sudo -v; sleep 60; done ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

# Build packages in *topological sort order* (i.e. dependencies first) thanks
# to `tsort`. Products are built in order into $PKGDEST so that later builds can
# use them.
#
# To avoid fails due to conflicting dependencies, the chroot is cleaned between
# each "forest" -- each set of deps from each high level package (meaning, a
# package with no dependents in "$@", not necessarily no dependents at all).
# Compared to fully cleaning between each build, only cleaning between each
# forst saves a great deal of time.
DAG="$(finddeps "$@")"
TOPS=$(printf "%s\n" "$DAG" | findtops) # split so errors exit before trying to build
printf "%s\n" "$TOPS" | while read -r Target; do
build_flags="-c"  # clean the build but ONLY on the first time around
echo "==> Building forest below $Target"

# filter the DAG to only include $Target, then find the build order surrounding it
# TODO: is there a way to compute the, wazzit, transitive closure of $Target
# from $DAG
# it would be good to avoid re-parsing the PKGBUILDs, since they're live scripts
DEPS=$(finddeps "$Target" | tsort | grep -vx _)
printf "%s\n" "$DEPS" | while read -r target; do

  cd "$target"
  if [ -f PKGBUILD ]; then
    # determine if output already exists by reproducing makepkg's internal code
    # (could use makepkg --packagelist; but it sometimes outputs multiple lines)
    # because makepkg checks, but makechrootpkg doesn't: https://bugs.archlinux.org/task/63092.html
    . PKGBUILD
    fullver=$(get_full_version)
    pkgarch=$(get_pkg_arch)
    pkg="$PKGDEST/${pkgname}-${fullver}-${pkgarch}${PKGEXT}"

    if [[ -f "${pkg}" ]]; then
      echo "${pkgname} has already been built. Skipping."
    else
      # build
      makechrootpkg $build_flags -r "$CHROOT" -u
      build_flags=""

      # expose new package in repo
      repo-add "$PKGDEST"/site.db.tar.zst "${pkg}"
    fi
  fi
  cd - >/dev/null
done
done

# "upload"
sudo mkdir -p /var/cache/pacman/site
sudo cp -rp "${PKGDEST}/." /var/cache/pacman/site/
