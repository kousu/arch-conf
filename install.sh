#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
# This code is based on code from the archlinux devtools project.

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


targets() {
  finddeps "$@" | while read A B; do echo "$A"; echo "$B"; done
}

# TODO:
# - can anything in devtools help here? maybe archbuild? what about `pkgctl build`?
# - none of those seem to really be set up for a _local_ build like this...
# I fully realize this is not the canon way to do custom packages;
# either you do them one at a time (with makepkg) or you upload them to the AUR
# (makepkg + yaourt).

(targets "$@" | while read -r target; do
  echo "$target/PKGBUILD"
done) | tee /dev/stderr | xargs pikaur -Pi

#mkdir -p .chroot
#mkarchroot .chroot/root base-devel
#makechrootpkg

