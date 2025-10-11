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
		. "$1/PKGBUILD"
		for dep in "${depends[@]}"; do
			# lose the version comparator, if any
			depname=${dep%%[<>=]*}
			[[ -f "$depname/PKGBUILD" ]] && echo "$depname (depends)"
		done
		for dep in "${makedepends[@]}"; do
			# lose the version comparator, if any
			depname=${dep%%[<>=]*}
			[[ -f "$depname/PKGBUILD" ]] && echo "$depname (makedepends)"
		done
		for dep in "${optdepends[@]/:*}"; do
			# lose the version comaparator, if any
			depname=${dep%%[<>=]*}
			[[ -f "$depname/PKGBUILD" ]] && echo "$depname (optdepends)"
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
        echo "$target" "$target" # add a loop back on each dep for the
        parsedeps "$target" | while read -r dep kind; do

          if [ "$kind" = "(makedepends)" ] || [ "$kind" = "(depends)" ]; then
            echo "$dep" "$target"
          fi

          # recurse:
          finddeps "$dep"
        done
      fi
    done
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
: "${PKGDEST:=/var/cache/pacman/site}"  # default value
#: "${PKGDEST:=$(pwd)}"  # default value

PKGDEST="$(realpath "$PKGDEST")"
export PKGDEST

sudo mkdir -p "$PKGDEST"
sudo chown "$USER" "$PKGDEST"  #XXX is this a dangerous idea? it's a privilege escalation vector.
repo-add "$PKGDEST"/site.db.tar.zst # init repo if needed


# Configure makechrootpkg's container
CHROOT=/var/lib/archbuild/site
sudo mkdir -p "$CHROOT"
if [ ! -d "$CHROOT"/root ]; then
  # construct a new build container
  mkarchroot "$CHROOT"/root base-devel  # NB: this calls `sudo`
fi
## insert the output path so downstream local packages can depend on local packages.
# arch-nspawn parses pacman.conf and automagically bind-mounts any paths mentioned into the container.
#
#   _Alternate rejected solution_: adding just `Include = /etc/pacman.d/site.conf`.
#   and putting the repo details in there. arch-nspawn parses pacman.conf from
#   _outside_ the container, where /etc/pacman.d/site.conf doesn't exist. Too bad,
#   it would be cleaner...
#
sudo arch-chroot "$CHROOT"/root sed -i '/# --- BEGIN makechrootpkg ---/,/# --- END makechrootpkg ---/{d}' /etc/pacman.conf
sudo arch-chroot "$CHROOT"/root tee -a /etc/pacman.conf <<EOF
# --- BEGIN makechrootpkg ---
[site]
# the arch devtools magically recognize directories in the containerized
# pacman.conf and _bind mount_ them to the same paths inside as out.
Server = file://$PKGDEST
# Disable signature checking on local packages -- because we don't have signing configured
SigLevel = Optional TrustAll
# --- END makechrootpkg ---
EOF

# Extend makechrootpkg's sudo privileges until
# done, meaning the build can be left unattended.
( while true; do sudo -v; sleep 60; done ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

# build packages in *topological sort order* (i.e. deepest dependency first) thanks to `tsort`,
# and build into the local site repo so that later local packages can depend on earlier local packages.
finddeps "$@" | tsort | while read -r target; do

  ( # subshell to undo 'cd' at end
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
      makechrootpkg -c -r "$CHROOT" -u
      # does not using -c speed up the build?
      # does using makepkg -sr work here?
      repo-add "$PKGDEST"/site.db.tar.zst "${pkg}" # expose new package in repo
    fi
  fi
  )
done
