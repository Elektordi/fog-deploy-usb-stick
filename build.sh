#!/bin/bash

if [ -f /tmp/fos-usb.img ]; then
    rm -f /tmp/fos-usb.img
fi

echo Make a blank 128MB disk image
dd if=/dev/zero of=/tmp/fos-usb.img bs=1M count=128
mkdir -p cache

echo Download the FOG kernels and inits
wget -N -P cache/ https://github.com/FOGProject/fos/releases/download/20230331/bzImage
wget -N -P cache/ https://github.com/FOGProject/fos/releases/download/20230331/init.xz

 
echo Make the partition table, partition and set it bootable.
parted --script /tmp/fos-usb.img mklabel msdos mkpart primary fat32 1 128 set 1 boot on
 
echo Map the partitions from the image file
kpartx -a -s /tmp/fos-usb.img
LOOPDEV=$(losetup -a | grep "/tmp/fos-usb.img" | grep -o "loop[0-9]*")

 
echo Make an vfat filesystem on the first partition.
mkfs -t vfat -n GRUB /dev/mapper/${LOOPDEV}p1
 
echo Mount the filesystem via loopback
mount /dev/mapper/${LOOPDEV}p1 $MOUNT

echo Install GRUB
#grub-install --removable --no-nvram --no-uefi-secure-boot --efi-directory=$MOUNT --boot-directory=$MOUNT/boot --target=i386-efi
#grub-install --removable --no-nvram --no-uefi-secure-boot --efi-directory=$MOUNT --boot-directory=$MOUNT/boot --target=x86_64-efi
grub-install --removable --no-floppy --boot-directory=$MOUNT/boot --target=i386-pc /dev/${LOOPDEV}

echo Copy boot files
cp cache/bzImage $MOUNT/boot/
cp cache/init.xz $MOUNT/boot/

echo Create the grub configuration file
cat > $MOUNT/boot/grub/grub.cfg << 'EOF'

set myfogip=http://192.168.1.100
set myimage=/boot/bzImage
set myinits=/boot/init.xz
set timeout=-1
insmod all_video

menuentry "FOG Deploy from USB" {
 echo loading the kernel
 linux  $myimage loglevel=4 initrd=init.xz root=/dev/ram0 rw ramdisk_size=275000 keymap= web=$myfogip/fog/ boottype=usb consoleblank=0 rootfstype=ext4
 echo loading the virtual hard drive
 initrd $myinits
 echo booting kernel...
}

menuentry "[DEBUG] FOG Deploy from USB" {
 echo loading the kernel
 linux  $myimage loglevel=7 initrd=init.xz root=/dev/ram0 rw ramdisk_size=275000 keymap= web=$myfogip/fog/ boottype=usb consoleblank=0 rootfstype=ext4 isdebug=yes
 echo loading the virtual hard drive
 initrd $myinits
 echo booting kernel...
}

EOF
 
echo Unmount the loopback
umount $MOUNT
rmdir $MOUNT
 
echo Unmap the image
kpartx -d /tmp/fos-usb.img
