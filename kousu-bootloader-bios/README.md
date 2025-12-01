# `kousu-bootloader-bios`

Installs a BIOS (i.e. not EFI) bootloader.

This package is touchier than the others,
because it depends a lot on the partition layout.

If deployed to a disk with a MBR partition table,
the /boot partition needs to be marked bootable,
which my scripts don't do and I haven't tested.

If deployed to a GPT partition table,
there must be a spare "BIOS Boot" (GUID
21686148-6449-6E6F-744E-656564454649) partition
to give room for the 2nd stage bootloader.

Ref:
* [ArchWiki](https://wiki.archlinux.org/title/Limine#Deploying_the_boot_loader).

See the [top level](../README.md) for build instructions.

## TODO

- [ ] Consider having the hooks check /etc/mkinitcpio.d/linux.preset for /boot/initramfs-linux.img and ADD it if missing. BIOS booting WILL NOT work without that file, but that file is touchy and doesn't(?) support drop-ins.
