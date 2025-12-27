# `kousu-archiso-mod`

Customize the Arch install .iso with:

- modified packages on the _live_ system
- a custom package repo the _live_ system can use when `pacstrap`ing
- ssh keys to allow [headless installs](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH#Installation_on_a_headless_server) via `ssh root@${NEW_SERVER_IP}`.

This is aimed at building installers that can bootstrap from custom packages, taking deployments from a tedious base install, followed by manual key deployment, speeding up deployments. It is not intended to build general Arch live systems. For those deeper changes, follow the [guide on ArchWiki](https://wiki.archlinux.org/title/Archiso#Prepare_a_custom_profile) directly.

## Usage

...

## Examples

Combined with the other tooling in arch-conf, build an image that has my installer script instead of the official installer, and install my ssh keys so that it becomes accessible online. For this to build, a custom repo containing kousu-arch-install needs to be configured in the host /etc/pacman.conf.

```
./mk-pkg-archiso \
  --add kousu-arch-install \
  --remove archinstall \
  --key "$(cat ~/.ssh/id_ed25519.pub)"
  --key "$(cat ~/.ssh/id_rsa.pub)"
```

Build an image without most of the loadable firmware, saving about half a gig (30%) from the final ISO. This only applies to the live system during install, you can install any or all firmeware during the install, so long as this doesn't prevent the install from working.

```
archiso-mod \
  --remove linux-firmware \
  --remove linux-firmware-marvell \
  --add linux-firmware-intel
```

Build an image with a custom repo added. The repo will be available in the image as 'customrepo' and stored in /var/cache/pacman/customrepo. Also, put the output in the Downloads folder.

```
archiso-mod ~/projects/my-arch-repo/customrepo.db ~/Downloads/
```
