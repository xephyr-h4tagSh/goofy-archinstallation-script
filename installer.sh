#!/bin/bash
# Arch Install Script - Robust Edition

set -e # Exit immediately if any command fails

echo "starting arch install gng..."
sleep 1
echo "im locking in"
lsblk
echo ""
read -p "what disk should I install it on? (e.g., /dev/sda) >:3: " DISK

if [ -b "$DISK" ]; then
    read -p "confirm my dumbass to erase $DISK? (y or Y to proceed): " CONFIRMATION
    if [[ ! $CONFIRMATION =~ ^[yY]$ ]]; then
        echo "Aborting."
        exit 1
    fi
    
    # Clean disk properly
    wipefs -af "$DISK"
    sgdisk --zap-all "$DISK"
    partprobe "$DISK"
else
    echo "invalid disk tut tut tut. aborting >:*(."
    exit 1
fi

read -p "BIOS or UEFI? (B/U): " SYSTEMTYPE
SYSTEMTYPE=${SYSTEMTYPE^^}

# Partitioning
if [ "$SYSTEMTYPE" == "B" ]; then
    echo "Partitioning for BIOS..."
    # 2G Swap, Rest Root
    printf "label: dos\n, 2G, S\n, , L, *\n" | sfdisk "$DISK"
else
    echo "Partitioning for UEFI..."
    # 1G EFI, 2G Swap, Rest Root
    printf "label: gpt\n, 1G, U\n, 2G, S\n, , L\n" | sfdisk "$DISK"
fi

partprobe "$DISK"
sleep 2 # Give the kernel time to breathe

# Detect partition names
P_PREFIX=""
[[ "$DISK" == *nvme* || "$DISK" == *mmcblk* ]] && P_PREFIX="p"

if [ "$SYSTEMTYPE" == "B" ]; then
    SWAP_PART="${DISK}${P_PREFIX}1"
    ROOT_PART="${DISK}${P_PREFIX}2"
else
    EFI_PART="${DISK}${P_PREFIX}1"
    SWAP_PART="${DISK}${P_PREFIX}2"
    ROOT_PART="${DISK}${P_PREFIX}3"
fi

# Formatting and CRITICAL MOUNT CHECK
mkswap "$SWAP_PART"
swapon "$SWAP_PART"
mkfs.ext4 -F "$ROOT_PART"
mount "$ROOT_PART" /mnt

# Check if mount actually worked
if ! mountpoint -q /mnt; then
    echo "hey uh: /mnt is not a mountpoint! Check your disk."
    exit 1
fi

if [ "$SYSTEMTYPE" == "U" ]; then
    mkfs.fat -F 32 "$EFI_PART"
    mkdir -p /mnt/boot/efi
    mount "$EFI_PART" /mnt/boot/efi
fi

# Install Base System
pacstrap -K /mnt base linux-lts linux-lts-headers linux-firmware grub networkmanager nano sudo sof-firmware alsa-ucm-conf
[[ "$SYSTEMTYPE" == "U" ]] && pacstrap -K /mnt efibootmgr

genfstab -U /mnt >> /mnt/etc/fstab

# Get info before entering chroot
read -p "set your root password :3 : " PASSWD
read -p "your new username: " USERNAME
read -p "and set the password for $USERNAME :0 : " USRPASSWD

# Config inside chroot
arch-chroot /mnt /bin/bash <<EOF
echo "root:$PASSWD" | chpasswd
useradd -m -G wheel "$USERNAME"
echo "$USERNAME:$USRPASSWD" | chpasswd

echo "archlinux" > /etc/hostname
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

systemctl enable NetworkManager

if [ "$SYSTEMTYPE" == "U" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable
else
    grub-install --target=i386-pc "$DISK"
fi
grub-mkconfig -o /boot/grub/grub.cfg
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-installer
EOF

echo "installation finished :0000! unmounting..."
umount -R /mnt
echo "i have completed thy assignment. type 'reboot' to start the new install :3."
