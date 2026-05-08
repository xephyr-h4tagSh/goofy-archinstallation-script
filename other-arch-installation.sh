```bash
#!/bin/bash
# ok here we go chat arch install script

echo "starting arch install gang"
sleep 1
echo "just a quick warning: i made this for fun, if you don't want your disk to be erased by my mildly bad scripting, don't use it."
sleep 1
echo "oh and this should only be used in the arch installation environment"
sleep 2
lsblk
sleep 1
echo "what disk should i install it on? (enter it as /dev/sda or like /dev/nvme0n1, so if the list said sdb and you wanted to install it there you input /dev/sdb)"
read DISK

if [ -b "$DISK" ]; then
    echo "good job. you entered a valid disk."
    sleep 0.5
    read -p "just confirmation: you don't mind me erasing the disk right? (Y/N): " CONFIRMATION

    if [[ $CONFIRMATION != [yY] ]]; then
        echo "aw ok"
        sleep 3
        exit 1
    fi

    wipefs -af "$DISK"
    dd if=/dev/zero of="$DISK" bs=1M count=100 conv=fdatasync
    partprobe "$DISK"

    echo "disk $DISK is now clean. ready for partitioning people"
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
    sfdisk "$DISK" <<EOF
label: dos
size=2G, type=82
type=83
EOF
elif [ "$SYSTEMTYPE" = "U" ]; then
    echo -e "label: gpt\n 1G,, * \n ,,, 20" | sfdisk "$DISK"
else
    echo "enter a valid system type next time. you were supposed to enter B or U. >:("
    sleep 2
    exit 1
fi

P_PREFIX=""
[[ "$DISK" == *nvme* ]] && P_PREFIX="p"

SWAP_PART="${DISK}${P_PREFIX}1"
2ROOT_PART="${DISK}${P_PREFIX}2"

mkswap "$SWAP_PART"
swapon "$SWAP_PART"
mkfs.ext4 "$ROOT_PART"
mount "$ROOT_PART" /mnt

if [ "$SYSTEMTYPE" = "U" ]; then
    PART1=$(lsblk -nxo NAME "$DISK" | sed -n '2p' | awk '{print "/dev/"$1}')
    PART2=$(lsblk -nxo NAME "$DISK" | sed -n '3p' | awk '{print "/dev/"$1}')
    mkfs.fat -F 32 "$PART1"
    mount "$PART1" /mnt/boot/efi
fi

pacstrap -K /mnt linux-zen linux-firmware base
if [ "$SYSTEMTYPE" = "U" ]; then
    pacstrap -K /mnt efibootmgr
fi

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt <<EOF
echo "what will your password be?: "
read PASSWD
passwd
$PASSWD
echo "what will your username be?: "
read USERNAME
useradd -m -G wheel \$USERNAME
echo "and what will your user password be?: "
read USRPASSWD
passwd \$USERNAME
$USRPASSWD
sleep 1
echo "ok that should be your root passwd, and username and its passwd done."
EOF

pacman -S --noconfirm networkmanager intel-ucode amd-ucode
systemctl enable NetworkManager
echo "archlinux" > /etc/hostname
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" >> /etc/locale.conf

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

pacman -S --noconfirm networkmanager intel-ucode amd-ucode
systemctl enable NetworkManager
echo "archlinux" > /etc/hostname
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" >> /etc/locale.conf

sleep 1

exit
umount -R /mnt
reboot
