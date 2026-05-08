#!/bin/bash
# Arch Install Script - Fixed Gang Edition

echo "starting arch install gang"
sleep 1
echo "WARNING: This will erase your disk. Use only in the Arch live environment."
sleep 2

lsblk
echo ""
read -p "What disk should I install it on? (e.g., /dev/sda): " DISK

if [ -b "$DISK" ]; then
    read -p "Confirm erasing $DISK? (y/Y to proceed): " CONFIRMATION
    if [[ ! $CONFIRMATION =~ ^[yY]$ ]]; then
        echo "Aborting."
        exit 1
    fi
    
    # Clean disk
    wipefs -af "$DISK"
    dd if=/dev/zero of="$DISK" bs=1M count=100 conv=fdatasync
    partprobe "$DISK"
else
    echo "Invalid disk. Aborting."
    exit 1
fi

read -p "BIOS or UEFI? (B/U): " SYSTEMTYPE
SYSTEMTYPE=${SYSTEMTYPE^^} # Convert to uppercase

# Partitioning logic
if [ "$SYSTEMTYPE" == "B" ]; then
    # BIOS: 2G Swap, remaining Root
    sfdisk "$DISK" <<EOF
label: dos
size=2G, type=82
type=83, bootable
EOF
elif [ "$SYSTEMTYPE" == "U" ]; then
    # UEFI: 1G EFI, 2G Swap, remaining Root
    sfdisk "$DISK" <<EOF
label: gpt
size=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
size=2G, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF
else
    echo "Invalid type. Use B or U."
    exit 1
fi

# Detect partition names (handles nvme "p1" vs sda "1")
P_PREFIX=""
[[ "$DISK" == *nvme* ]] && P_PREFIX="p"

if [ "$SYSTEMTYPE" == "B" ]; then
    SWAP_PART="${DISK}${P_PREFIX}1"
    ROOT_PART="${DISK}${P_PREFIX}2"
else
    EFI_PART="${DISK}${P_PREFIX}1"
    SWAP_PART="${DISK}${P_PREFIX}2"
    ROOT_PART="${DISK}${P_PREFIX}3"
fi

# Formatting
mkswap "$SWAP_PART"
swapon "$SWAP_PART"
mkfs.ext4 -F "$ROOT_PART"
mount "$ROOT_PART" /mnt

if [ "$SYSTEMTYPE" == "U" ]; then
    mkfs.fat -F 32 "$EFI_PART"
    mkdir -p /mnt/boot/efi
    mount "$EFI_PART" /mnt/boot/efi
fi

# Essential packages
pacstrap -K /mnt base linux-zen linux-firmware grub networkmanager nano
[[ "$SYSTEMTYPE" == "U" ]] && pacstrap -K /mnt efibootmgr

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Capture user info BEFORE chroot (heredocs block interactive 'read')
read -p "Set root password: " PASSWD
read -p "New username: " USERNAME
read -p "Set password for $USERNAME: " USRPASSWD

# Configure system inside chroot
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
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
    grub-install --target=i386-pc "$DISK"
fi
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "Installation complete! Unmounting and rebooting..."
umount -R /mnt
reboot
