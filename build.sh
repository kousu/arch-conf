#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
# This code is based on code from the archlinux devtools project.

set -euo pipefail # strict-ish mode


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

# Q: how did Arch bootstrap its repos?
# Q: could arch bootstrap its repos from source at the moment? Would it require someone to manually work out the build order and manually set up the build everyt manually buu manual intervention?
# Q: could arch bootstrap its repos from source simply by `find . -name PKGBUILD -exec makepkg -d`

finddeps() {
    # Find upstream dependencies, write as edges "B" "A" meaning "A depends on B"
    #
    # Arch's devtools has a `finddeps` but it finds downstream dependencies,
    # and it needs to examine an existing repo database, because it's meant
    # as a crutch for bumping the build when updating a single package, by hand.
    # It can't help bootstrap repo from PKGBUILD sources, but that's what we're doing here.

    local target dep kind
    for target in "$@"; do
      parsedeps "$target" | while read -r dep kind; do

        if [ "$kind" = "(makedepends)" -o "$kind" = "(depends)" ]; then
          echo "$dep" "$target"
        fi

        # recurse:
        finddeps "$dep"

      done
    done
}

# Based on https://wiki.archlinux.org/title/DeveloperWiki:Building_in_a_clean_chroot#Classic_way
# 
# There's `pkgctl build` and `archbuild` which are supposed to be more convenient
# but they are only really designed for working against the Arch repos, and only
# one package at a time. This needs to work with multiple local packages with multiple
# local dependencies.
# which is necessary because local packages depend on other local packages.
# (when working against the arch repos, arch-rebuild-order finds the downstream
# packages that need to be rebuilt given an update to a given package.

export PKGDEST=/var/cache/pacman/site # -> output packages from container to here
sudo mkdir -p "$PKGDEST"
sudo chown "$USER" "$PKGDEST"  #XXX is this a dangerous idea? it's a privilege escalation vector.
repo-add "$PKGDEST"/site.db.tar.zst # init empty repo, or update existing one

CHROOT=/var/lib/archbuild/site
sudo mkdir -p "$CHROOT"
if [ ! -d "$CHROOT"/root ]; then
  mkarchroot "$CHROOT"/root base-devel  # NB: this calls `sudo` if needed
  sudo arch-chroot "$CHROOT"/root tee -a /etc/pacman.conf <<EOF
[site]
# the arch devtools magically recognize directories in the containerized
# pacman.conf and _bind mount_ them to the same paths inside as out.
SigLevel = Optional TrustAll
Server = file://$PKGDEST
EOF
fi

# make sure container is updated
arch-nspawn $CHROOT/root pacman -Syu

# build packages in *topological sort order* (i.e. deepest dependency first) thanks to `tsort`,
# and build into the local site repo so that later local packages can depend on earlier local packages.
finddeps "$@" | tsort | while read target; do
  (cd "$target"
    makechrootpkg -c -r "$CHROOT"
    repo-add "$PKGDEST"/site.db.tar.zst "$PKGDEST"/*.pkg.tar.*
    arch-nspawn $CHROOT/root pacman -Sy
  )
done
