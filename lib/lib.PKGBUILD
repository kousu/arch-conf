
# Use this BOILERPLATE to import this in your PKGBUILDs.
# For makepkg '. ../lib/lib.PKGBUILD' would suffice, but
# makechrootpkg wants everything strictly isolated and
# builds in a clean env. But there's an escape hatch:
# it loads PKGBUILD once *outside* the chroot, giving
# a chance to glue everything together.
#
# ```
# # load common settings; be aware if you ever split up this repo.
# [ -f ../lib/lib.PKGBUILD ] && cp -lf ../lib/lib.PKGBUILD .lib.PKGBUILD
# . .lib.PKGBUILD || exit 1
# ```

arch=('any')
url="https://github.com/kousu/arch-conf"
license=("MIT")

_pkgver() {
  # construct a version number from how many commits are in the project
  [ -r "$startdir"/.pkgver ] && cat "$startdir"/.pkgver || (echo "r$(git rev-list --count HEAD).commit=$(git describe --always --dirty | sed s/-/+/g)")
}
pkgver="$(_pkgver)"
pkgrel=1

groups=(kousu)

if [ -f "${pkgname}.install" ]; then
  install="${pkgname}.install"
fi

# PKGBUILD's `source` has some basic support for handling individual local files
# but it expects them to all be in the top-level folder. It's not for bundling
# an entire directory tree; for that, it expects to be given a .tar to extract
# -into- src/. That's not maintainable so instead, in most cases,I've committed
# my package contents *directly* to src/ and subvert PKGBUILD slight with this.
_package() {
  # build the package directly from the contents of src/, if any
  if [ -d "${startdir}/src" ]; then
    # note the '/.'. it means "copy the contents of this directory"
    # whereas 'src/' would create nested '${pkgdir}/src/'.
    cp -rp "${startdir}/src/." "${pkgdir}"
  fi
}

# Override this per-package if needed.
package() {
  _package
}
