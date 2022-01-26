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


```
truncate -s 20G arch.img
```

Pass `arch.img` to the installer as its target disk:

```
arch-install arch.img
```

Wait, hang on, when do you need sudo again?

if you already losetup'd and *then* use fdisk on the underlying file you need to

```
sudo partprobe /dev/loop*
```

to get `/dev/loop0p1`, `/dev/loop0p2`, .. to show up.
To test, you need losetup and qemu and 

[kousu@nigiri arch-install]$ sudo pacman -S --noconfirm qemu 
[kousu@nigiri arch-install]$ qemu-system-x86_64 --enable-kvm -m 2G -M q35 -hda /tmp/arch2.img 

Test UEFI booting:

( from https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Plain_QEMU_without_libvirt ; maybe there's better docs ?)
The key thing is 

[kousu@nigiri arch-install]$ sudo pacman -S --noconfirm qemu edk2-ovmf
[kousu@nigiri arch-install]$ sudo qemu-system-x86_64 --enable-kvm -M q35 -m 2G -bios /usr/share/edk2-ovmf/x64/OVMF_CODE.fd -hda /tmp/arch2.img 

# actually no you have to do it this way; for some reason -bios will *boot* into a uefi environment but it won't boot syslinux or grub from there
cp /usr/share/edk2-ovmf/x64/OVMF_VARS.fd /tmp/MY_VARS
[kousu@nigiri arch-install]$ qemu-system-x86_64 --enable-kvm -M q35 -m 2G -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd -drive if=pflash,format=raw,file=/tmp/MY_VARS.fd -hda /tmp/arch.img

or
[kousu@nigiri arch-install]$ qemu-system-x86_64 --enable-kvm -M q35 -m 2G -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_VARS.fd -hda /tmp/arch.img


-M q35 is to use a modern system, where -hda implies a *SATA* disk; the default, -M pc, implies an IDE disk, and it seems like Arch doesn't even ship drivers for IDE disks anymore??


----------


so my input format is something like

/boot 1G
/ 30G
swap 2G
/var  20%
/home 100%r (%r = % remaining? is that actually useful? I think it's a feature fdisk has?)

is that it? i don't really want to give to anything else tbh

```
[kousu@nigiri arch-conf]$ df -h /boot
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb2      1022M   67M  956M   7% /boot
```

right so..a gig is too much.
but on debian, it's a different story. on debian it's easy to use up 2G on /boot, somehow, because debian freely keeps lots of kernels around and their initramfses are huuuge

the hard part that i want to script is:

- formatting and then running blkid
- running luksFormat
- setting up cryptswap (tricky!)
  - should it be... the same key all the time? a key generated at boot -- but not when de-hibernating)?  /dev/urandom at boot (so it changes on each boot
