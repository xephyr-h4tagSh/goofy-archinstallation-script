#!/bin/bash
# ok here we go chat arch install script

echo "starting arch install gang"
sleep 1
echo "just a quick warning: i made this for fun, if you don't want your disk to be erased by my mildly bad scripting, don't use it."
sleep 1
echo "oh and this should only be used in the arch installation environment"
sleep 2
echo "im locking in now good luck but FIRST"
lsblk
echo "what disk should i install it on? (enter it as /dev/sda or like /dev/nvme0n1, so if the list said sdb and you wanted to install it there you input /dev/sdb)"
read DISK

if [ -b "$DISK" ]; then
    echo "good job. you entered a valid disk."
    sleep 0.5
    echo "just confirmation: you don't mind me erasing the disk right? (Y/N)"
    read CONFIRMATION

    if [ "$CONFIRMATION" = "Y" ]; then
        sleep 1
        echo "yay! good luck"
        
        wipefs -af "$DISK"
        dd if=/dev/zero of="$DISK" bs=1M count=100 conv=fdatasync
        partprobe "$DISK"
        
        echo "disk $DISK is now clean. ready for partitioning people"
    else
        echo "aw ok"
        sleep 3
        exit 1
    fi
else
    echo "enter a valid disk next time. the installation is aborting :3"
    sleep 3
    exit 1
fi

sleep 3
echo "ok SO"
sleep 0.5
echo "we will now be partitioning. will this be a BIOS or UEFI machine? :0 (B/U)"
read SYSTEMTYPE
if [ "$SYSTEMTYPE" = "B" ]; then
    sleep 1
    echo "damn that's old you have a bios machine"
    echo -e "label: dos\n, 2G, 82\n, , 83, *" | sfdisk "$DISK"
    PART1=$(lsblk -nxo NAME "$DISK" | sed -n '2p' | awk '{print "/dev/"$1}')
    PART2=$(lsblk -nxo NAME "$DISK" | sed -n '3p' | awk '{print "/dev/"$1}')
    mkswap "$PART1"
    swapon "$PART1"
    mkfs.ext4 "$PART2"
    mount "$PART2" /mnt
    echo "yay i finished partitioning formatting and mounting :0"
elif [ "$SYSTEMTYPE" = "U" ]; then
    sleep 1
    echo "ok UEFI!"
    echo -e "label: gpt\n, 1G, 1\n, , 20" | sfdisk "$DISK"
    PART1=$(lsblk -nxo NAME "$DISK" | sed -n '2p' | awk '{print "/dev/"$1}')
    PART2=$(lsblk -nxo NAME "$DISK" | sed -n '3p' | awk '{print "/dev/"$1}')
    mkfs.fat -F 32 "$PART1"
    mkfs.ext4 "$PART2"
    mount "$PART2" /mnt
    mkdir -p /mnt/boot/efi
    mount "$PART1" /mnt/boot/efi
    echo "yay i finished formatting and mounting."
else
    echo "enter a valid system type next time. you were supposed to enter B or U. >:("
    sleep 2
    exit 1
fi

sleep 2
echo "ok im gonna install you some packages. linux-zen, base, linux-firmware, and if you are UEFI then efibootmgr"
sleep 1
if [ "$SYSTEMTYPE" = "U" ]; then
    echo "oh yes i need to enable the swap on uefi first :0"
    sleep 1
    fallocate -l 4G /mnt/swapfile
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
    pacstrap -K /mnt linux-zen linux-firmware base efibootmgr
else
    pacstrap -K /mnt linux-zen linux-firmware base
fi

sleep 1
echo "i installed the necessary packages for you!!! yippee"
sleep 0.5
echo "im gonna generate the fstab"
genfstab -U /mnt >> /mnt/etc/fstab
sleep 1
echo "ok im gonna chroot into your new machine :0"
sleep 1

arch-chroot /mnt <<EOF
echo "setting root password..."
passwd
echo "what will your username be?"
read USERNAME
useradd -m -G wheel \$USERNAME
echo "and what will your user password be?"
read USRPASSWD
passwd $USERNAME $USRPASSWD
sleep 1
echo "ok that should be your root passwd, and username and its passwd done."
EOF

sleep 1
echo "now thats done, lets do the bootloader."
sleep 1
pacman -S --noconfirm grub
if [ "$SYSTEMTYPE" = "U" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
fi
if [ "$SYSTEMTYPE" = "B" ]; then
    grub-install --target=i386-pc $DISK
fi
grub-mkconfig -o /boot/grub/grub.cfg

sleep 1
echo "i think thats grub done?"
sleep 0.5
echo "hehee lol"
sleep 0.5
echo "ill finish off for you"

pacman -S --noconfirm networkmanager intel-ucode amd-ucode
systemctl enable NetworkManager
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "archlinux" > /etc/hostname
echo "en_UK.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_UK.UTF-8" > /etc/locale.conf

echo "think its done gng"
exit 
umount -R /mnt
echo "rebooting in 10 seconds"
sleep 10
reboot
