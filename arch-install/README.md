# `arch-install`

Arch used to have an install script, but at some point it got too unwieldly and they dropped it in favour of https://wiki.archlinux.org/wiki/Installation_guide.

It's 90% straightforward, but the 10% that is fiddly is really fiddly and takes a long time and makes reproducibility difficult: partitioning, installing a boot loader, and remembering to install networking, drivers, firmware. I especially always seem to fail at getting the bootloader right.

This is my solution. It builds a standard single-user, encrypted, single-disk, EFI-booting, desktop system.

The system has an LVM, so if you don't like the partition sizes is relatively safe and quick
to `e2resize` + `lvresize` or add new partitions as you like. And of course, if your system
has the connections, you can always add more disks.




## Installation

There's a PKGBUILD here so run `makepkg -si` to get it installed to your $PATH,
or build it and copy it to the target system and install it with `pacman -U`.

## Usage

```
arch-install [options] disk [packages...]
```

The way I recommend using this is in concert with the packages in [my arch-conf](https://github.com/kousu/arch-conf).
Pick one of the top level packages (e.g. `kousu-device-nigiri`) and install it (and only it).

```
sudo arch-install /dev/sda kousu-device-nigiri
```

If you don't provide a list of packages a minimally booting system with basically just the kernel and `pacman` (TODO: and enough networking to get back online??) is created.
and you can customize it [in the normal way](https://wiki.archlinux.org/title/Installation_guide#Configure_the_system) from there.
You can customize it manually from there.

## Development

1. Install the dependencies (listed in PKGBUILD)
2. Make a test disk

    ```
    truncate -s 256G arch.img
    ```

    Don't worry, the system won't actually use 256G, truncate makes a _sparse_ file
    that only uses the space filled in. But this is a good realistic size
    for the partition table to think it has access to.

3. Iterate:

    ```
    sudo ./arch-install arch.img
    ```

4. Test:

    ```
    $ sudo pacman -S --noconfirm qemu edk2-ovmf
    $ sudo qemu-system-x86_64 --enable-kvm -M q35 -m 2G -bios /usr/share/edk2-ovmf/x64/OVMF_CODE.fd -hda arch.img
    ```

    _actually_ no you have to do it this way; for some reason -bios will *boot* into a uefi environment but it won't boot syslinux or grub from there

    ```
    cp /usr/share/edk2-ovmf/x64/OVMF_VARS.fd /tmp/MY_VARS
    [kousu@nigiri arch-install]$ qemu-system-x86_64 --enable-kvm -M q35 -m 2G -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd -drive if=pflash,format=raw,file=/tmp/MY_VARS.fd -hda /tmp/arch.img
    ```

    or

    ```
    [kousu@nigiri arch-install]$ qemu-system-x86_64 --enable-kvm -M q35 -m 2G -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_VARS.fd -hda /tmp/arch.img
    ```

    `-M q35` is to use a modern system, where -hda implies a *SATA* disk; the default, -M pc, implies an IDE disk, and it seems like Arch doesn't even sh ip drivers for IDE disks anymore??

    or give up and use GNOME Boxes / virt-manager which use libvirt which hides all this cruft. Just make sure you configure the system for UEFI and not BIOS booting.



# Related Work

* @NovaViper's https://gitlab.com/NovaViper/aalis/ (https://bbs.archlinux.org/viewtopic.php?id=273531)
