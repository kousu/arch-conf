# `kousu-bootloader-efi`

Installs a EFI bootloader.

Actually, all this does is instruct [UKI](https://wiki.archlinux.org/title/Unified_kernel_image#mkinitcpio) to deploy to the
default x86_64 EFI boot path.

This assumes (not does not currently verify!) that /boot is your [ESP](https://wiki.archlinux.org/title/EFI_system_partition) -- and therefore that it is a FAT32 partition on a GPT-formatted disk with its type marked "EFI System Partition".
