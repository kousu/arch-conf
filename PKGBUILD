pkgname=kousu-art
pkgrel=1
pkgdesc="Configuration management for kousu's job life"
arch=('any')
url="https://github.com/kousu/arch-conf"
#license=("MIT") # there..is no license? not really?

# This numbers the package versions by how many commits went into it: every published commit is a newer package.
# This will break if we ever rebase the master branch. Don't do that.
# Also: if we use this across a monorepo this has the quirk/feature that
#       every package built out of it has the same version, but that won't be preserved if we split them up.
#pkgver="$(git log --pretty=oneline | wc -l)"
pkgver=96

depends=(
  kousu-device-nigiri

  # hardware
  # alsa-card-profiles # is this needed? it's for making fancy professional soundcards work, I think

  # graphics
  #pinta # -> TODO: only in aur, sooo pull to a separate package?
  inkscape # svg editor
  gimp     # raster editor

  # video/music
  yt-dlp
  kdenlive

  # music
  audacity
  sonic-visualiser

  # music :: djing
  mixxx # DJ app
  xwax  # ditto

  # music :: production
  ardour
  amsynth
  surge-xt
  ninjas2   # slicer
  bchopper  # also a slicer?
  polyphone # .sf2 editor
  stochas   # randomized rhythm generator
  infamousplugins  # filters

)
