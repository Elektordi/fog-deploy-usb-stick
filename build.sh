#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

mkdir -p cache
if [ -f cache/fos-usb.img ]; then
    rm -f cache/fos-usb.img
fi

if [ ! -f cache/bzImage ]; then
    wget -N -P cache/ https://github.com/FOGProject/fos/releases/download/20230331/bzImage
fi
if [ ! -f cache/init.xz ]; then
    wget -N -P cache/ https://github.com/FOGProject/fos/releases/download/20230331/init.xz
fi


echo Create custom init
unxz --verbose -kc cache/init.xz > /tmp/fos-init
LOOPINIT=$(losetup --show -f /tmp/fos-init)
MOUNTINIT=$(mktemp -d)
mount $LOOPINIT $MOUNTINIT
if [ $? -ne 0 ]; then
    echo Failed to mount $MOUNTINIT
    exit 1
fi
cp -prv patch/* $MOUNTINIT/
sync -f $MOUNTINIT
umount $MOUNTINIT
if [ $? -ne 0 ]; then
    sleep 1
    umount $MOUNTINIT
    if [ $? -ne 0 ]; then
        echo Failed to unmount $MOUNTINIT
        exit 1
    fi
fi
rmdir $MOUNTINIT
losetup -d $LOOPINIT
xz --check=crc32 --verbose -kc /tmp/fos-init > cache/custom-init.xz

echo Make a blank disk image
dd if=/dev/zero of=cache/fos-usb.img bs=1M count=256
 
echo Make the partition table, partition and set it bootable.
parted --script cache/fos-usb.img mklabel msdos mkpart primary ext2 1 128 set 1 boot on mkpart primary ntfs 129 256

echo Map the partitions from the image file
kpartx -a -s cache/fos-usb.img
LOOPDEV=$(losetup -a | grep "cache/fos-usb.img" | grep -o "loop[0-9]*")

if [ -z "${LOOPDEV}" ]; then
    echo "Failed to setup loop!"
    exit
fi
 
echo Make filesystems
mkfs -t ext2 -L GRUB /dev/mapper/${LOOPDEV}p1
mkfs -t ntfs -L IMAGES /dev/mapper/${LOOPDEV}p2
# fstab: LABEL=IMAGES
 
echo Mount the filesystem via loopback
MOUNT=$(mktemp -d)
mount /dev/mapper/${LOOPDEV}p1 $MOUNT
if [ $? -ne 0 ]; then
    echo Failed to mount $MOUNT
    exit 1
fi

echo Install GRUB
#grub-install --removable --no-nvram --no-uefi-secure-boot --efi-directory=$MOUNT --boot-directory=$MOUNT/boot --target=i386-efi
#grub-install --removable --no-nvram --no-uefi-secure-boot --efi-directory=$MOUNT --boot-directory=$MOUNT/boot --target=x86_64-efi
grub-install --removable --no-floppy --boot-directory=$MOUNT/boot --target=i386-pc /dev/${LOOPDEV}

echo Copy boot files
cp cache/bzImage $MOUNT/boot/
cp cache/custom-init.xz $MOUNT/boot/

echo Create the grub configuration file
cat > $MOUNT/boot/grub/grub.cfg << 'EOF'

set timeout=-1
insmod all_video

menuentry "FOG Deploy from USB" {
 echo loading kernel
 linux /boot/bzImage loglevel=4 initrd=custom-init.xz root=/dev/ram0 rw ramdisk_size=275000 keymap= boottype=usb consoleblank=0 rootfstype=ext4
 echo loading ram disk
 initrd /boot/custom-init.xz
 echo booting kernel...
}

menuentry "[DEBUG] FOG Deploy from USB" {
 echo loading kernel
 linux /boot/bzImage loglevel=7 initrd=custom-init.xz root=/dev/ram0 rw ramdisk_size=275000 keymap= boottype=usb consoleblank=0 rootfstype=ext4 isdebug=yes
 echo loading ram disk
 initrd /boot/custom-init.xz
 echo booting kernel...
}

menuentry "[DEBUG] FOG Deploy with serial console" {
 echo loading kernel
 linux /boot/bzImage loglevel=7 initrd=custom-init.xz root=/dev/ram0 rw ramdisk_size=275000 keymap= boottype=usb consoleblank=0 rootfstype=ext4 console=ttyS0,115200n8 isdebug=yes
 echo loading ram disk
 initrd /boot/custom-init.xz
 echo booting kernel...
}

EOF
 
echo Unmount the loopback
sync -f $MOUNT
umount $MOUNT
if [ $? -ne 0 ]; then
    sleep 1
    umount $MOUNT
    if [ $? -ne 0 ]; then
        echo Failed to unmount $MOUNT
        exit 1
    fi
fi
rmdir $MOUNT
 
echo Unmap the image
kpartx -d cache/fos-usb.img
