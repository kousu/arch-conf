# Note: to *bootstrap* a system using this, you need to:
# 1. have pacman installed
# 2. pacman -S --noconfirm base-devel
# 3. makepkg --nodeps # because you won't have the dependencies yet and makepkg assumes you need them to build (even if they're only runtime dependencies; which, in this case, they are)
# 4. pacman -U kousu-nigiri*.pkg*

pkgname=kousu-device-nigiri
pkgver=v0.1.0
pkgrel=0
pkgdesc="Configuration management for kousu's \"nigiri\" thumddrive system"
arch=('any')
url="https://github.com/kousu/arch-conf"
#license=("MIT") # there..is no license? not really?


# TODO: try
#pkgver() {
#  # This numbers the package versions by how many commits went into it: every published commit is a newer package.
#  # This will break if we ever rebase the master branch. Don't do that.
#  git log --pretty=oneline | wc -l
#}

depends=(
  # Base system
  base
  man-db # the 'man' command
  man-pages # the core linux man pages (kernel, libc, file formats)
  reflector # for updating /etc/pacman.d/mirrorlist
  pacman-contrib # pactree, pacdiff, etc

  # hardware
  linux  # the kernel. on Arch, this is an *optional* package, so that you can install vanilla Arch inside a container.
  linux-firmware
  syslinux  # TODO: this package needs manual set up: you need to fiddle with /boot/syslinux/syslinux.cfg or /boot/EFI/syslinux/syslinux.cfg or /boot/EFI/BOOT/syslinux.cfg to edit the kernel command line to tell it where the root disk is; in ansible terms, it needs a 'lineinfile'
             # TODO: another bit of manual setup: syslinux's EFI mode
             # TODO: also, installing the package does not install the bootloader itself; for that you need to run syslinux-install_update -i -a -m (for MBR mode)
             #       or, **cp -r /#
             # these steps are tricky to get right even when doing them by hand
             # so, hm, i dunno maybe this part shouldn't be automated fully? idk
  intel-ucode
  amd-ucode # TODO: these two packages have an optional but difficult amount of manaul setup:
            # https://wiki.archlinux.org/title/Microcode#Early_loading
            # basically you need to edit your kernel command line to *prepend* initrd=/boot/amd-ucode.img,/boot/intel-ucode.img,
            # and making that edit by script is tricky. and also in the early boot that path is not always at /boot? ai yi yi

  iwd # wifi

  bluez-utils  # also pulls in the rest of bluetooth # XXX do I need to add `systemctl enable --now bluetooth` somewhere?
  pulseaudio-bluetooth # pairing some (most?) headphones is impossible without this: https://bbs.archlinux.org/viewtopic.php?id=270465&p=2

  # CLI
  bash-completion  # lets apps customize tab completion; it's handy for pass(1) and kubectl(1) and some others, but intereferes and is annoying when apps provide incomplete tab completion because it *disables* the default behaviour of files.
  sudo
  openssh
  alsa-utils
  pass # password manager
  pass-otp
  youtube-dl
  rsync

  #fio   # speed testing

  # CLI :: Programming
  #'base-devel' ### XXX not a package. this is a package group.
  # indeed if I try then I get 'warning: cannot resolve "base-devel", a dependency of "kousu-nigiri"'
  # but you need this to use the AUR

  # Here's the contents of base-devel, listed explicitly; this list extracted
  # (with the help of https://catonmat.net/set-operations-in-unix-shell) by
  # $ grep -vxF -f <(pacman -Qi base | grep Depends | cut -d ':' -f 2 | awk -v 'RS= ' '/.+/ {print}') <(pacman -Sqs base-devel)
  autoconf
  automake
  binutils
  bison
  fakeroot
  flex
  gcc
  groff
  libtool
  m4
  make
  patch
  pkgconf
  sudo
  texinfo
  which

  git
  python

  # TUI
  vi
  #vim
  htop

  # GUI
  #xorg-xinit # weirdly you can install X without xorg-xinit on Arch; I guess because lightdm/gdm/etc can serve its purpose?
  #xorg-server # weirdly, xorg-xinit doesn't pull this in; you'd think it would.
  sx # alternative to xorg-xinit; promises to be simpler; is it actually?
  xorg-xmodmap
  xorg-xkill
  xorg-xev
  xorg-fonts-100dpi
  xorg-fonts-75dpi
  noto-fonts-emoji # Google's Android emoji fonts, with the colourful faces and whatnot
  # lightdm ?
  xclip

  transmission-qt
  #transmission-gtk # more traditional? But I'm trying out a KDE-based system...

  ## GUI :: Desktop Environment
  plasma-desktop
  powerdevil # KDE plugin for power management
  bluedevil  # KDE plugin for Bluetooth
  plasma-pa  # KDE plugin for audio management
  plasma-systemmonitor # KDE task manager (i.e. GUI version of top)
  kscreen    # KDE plugin for screen management? I think?
  khotkeys   # KDE plugin to configure/listen for custom shortcut keys
  kde-applications-meta

  # for a tinier DE:
  # i3wm
  # arandr
  # xorg-xbacklight
  #redshift  # KDE has a setting for this built in
  # passmenu

  ## GUI :: Media
  audacity
  ardour

  ## GUI :: Productivity
  workrave

  ## GUI :: Editors
  ghostwriter # kde-applications-meta pulls in kate; maybe just use that?

  ## GUI :: Web
  firefox
  firefox-clearurls
  firefox-decentraleyes
  firefox-extension-passff
  firefox-extension-privacybadger
  firefox-ublock-origin

  ## GUI :: Comms
  dino
  signal-desktop

  ## GUI :: Media
  vlc # ?? or maybe i should just use whatever comes with KDE?

  # how do I handle packages from the aur?
  # there's no aur package manager in the standard arch packages -- probably because they want you to prove you can deal with the aur before you start pulling in packages from it willy-nilly

  # Things I would like from the AUR:
  # https://aur.archlinux.org/packages/apostrophe - a competitor to ghostwriter, in GTK instead of KDE
)

# `source` has some basic support for handling local files
# but it expects them to all be in the top-level folder. It's not really meant for bundling an entire directory tree,
# and to handle a directory tree it expects to be given a .tar to extract into src/
# Instead, I've committed the contents of this package *directly* to src/.

install="arch-conf.install"

package() {
  # often PKGBUILDs use install(1) here, because it lets them control permissions
  # but install(1) can't do folders recursively; so instead, just cp -r, and set any permissions directly with chmod
  # that's safe enough: this is *building* a package for later deployment, not installing on a live system where a temporary gap in permissions is a risk
  cp -rp * "${pkgdir}"

  chmod 750 "${pkgdir}"/etc/sudoers.d
  chmod 600 "${pkgdir}"/etc/sudoers.d/wheel
}

# and then i want to also figure out how/where to set KDE system defaults
# with GTK I know it's 'dconf' or 'gconf' (why are there two? who knows)
# and Firefox defaults too; plus extra Firefox extensions


# To control KDE settings:
# - add a file to src/etc/skel/.config/kdedefaults/
#   you can figure out what you need to edit by making a change in the GUI, then examining ~/.config/{kdeglobals,kwinrc}
#   whatever settings you see, copy them to the corresponding file *under* ~/.config/kdedefaults/.
# To control GTK/GNOME settings:
# - ...
# To control Firefox settings:
# - ...
# To control xsession settings:
# - if you're using sx, or xinit, or ...whazzit ~/.xsession
#
# In general, if you can't figure it out how to write a config file for a given app, you can do:
#   1. cp -r ~/.config A
#   1. make the change in the app's settings/GUI
#   2. cp -r ~/.config B
#   3. diff -ru A/ B/
# This should identify the change.
# Some apps don't use ~/.config, but they're getting rarer.
