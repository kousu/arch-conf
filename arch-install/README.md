# `arch-install`

Arch used to have an install script, but at some point it got too unwieldly and they dropped it in favour of https://wiki.archlinux.org/wiki/Installation_guide.

It's 90% straightforward, but the 10% that is fiddly is really fiddly and takes a long time and makes reproducibility difficult: partitioning, installing a boot loader, and remembering to install networking (`inetutils`, `iwd`, `netctl`, `dialog`, and/or `NetworkManager` and of course `linux-firmware`).
It seems like every time I install arch I fail at the bootloader, or networking, and then I need to boot back into the installer and fiddle until I get it right.

This is my custom. It builds a standard single-user desktop system:

- assumes a single disk, and partitions  -- 
  - deploys on *MBR* (not GPT) for widest compatibility
  - you can choose the shares
- does/doesn't use swap
- uses syslinux
  - deploys both and MBR boot sector *and* EFI system partition -- again for widest compatibility
-

So, this installer *does not* cover more exotic setups like combining multiple disks under LVM or mdadm.
My advice is: get a relatively small system disk and use this to bootstrap the system onto it, then once it's up add those asonce it's up  

and that make it hard to make a reproducible system.
But the installation process there's some things 

## Installation

There's a PKGBUILD here too so, if you're currently on arch you can do `makepkg && sudo pacman -U *.pkg.tar*` to get it installed to your $PATH.

You can use it without making the package too, just do `sudo pacman -S arch-install-scripts` and then run `./arch-install` directly.


## Development

### Test Harness

- losetup
- qemu
