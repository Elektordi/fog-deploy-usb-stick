#!/bin/bash

if [ -f /tmp/fos-usb.img ]; then
    echo Nuking old FOG Debug image
    rm -f /tmp/fos-usb.img
fi

echo Make a blank 128MB disk image
dd if=/dev/zero of=/tmp/fos-usb.img bs=1M count=128
 
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
grub-install --removable --no-nvram --no-uefi-secure-boot --efi-directory=$MOUNT --boot-directory=$MOUNT/boot --target=i386-efi
grub-install --removable --no-nvram --no-uefi-secure-boot --efi-directory=$MOUNT --boot-directory=$MOUNT/boot --target=x86_64-efi
grub-install --removable --no-floppy --boot-directory=$MOUNT/boot --target=i386-pc /dev/${LOOPDEV}

echo Download the FOG kernels and inits
wget -P $MOUNT/boot/ https://github.com/FOGProject/fos/releases/download/20230331/bzImage
wget -P $MOUNT/boot/ https://github.com/FOGProject/fos/releases/download/20230331/bzImage32
wget -P $MOUNT/boot/ https://github.com/FOGProject/fos/releases/download/20230331/init.xz
wget -P $MOUNT/boot/ https://github.com/FOGProject/fos/releases/download/20230331/init_32.xz
wget -P $MOUNT/boot/ https://github.com/FOGProject/fogproject/blob/dev-branch/packages/web/service/ipxe/memdisk
wget -P $MOUNT/boot/ https://github.com/FOGProject/fogproject/blob/dev-branch/packages/web/service/ipxe/memtest.bin
wget -P $MOUNT/boot/ https://github.com/FOGProject/fogproject/blob/dev-branch/packages/tftp/ipxe.krn
wget -P $MOUNT/boot/ https://github.com/FOGProject/fogproject/blob/dev-branch/packages/tftp/ipxe.efi

echo Create the grub configuration file
cat > $MOUNT/boot/grub/grub.cfg << 'EOF'

set myfogip=http://192.168.1.100
set myimage=/boot/bzImage
set myinits=/boot/init.xz
set myloglevel=4
set timeout=-1
insmod all_video

menuentry "1. FOG Image Deploy/Capture" {
 echo loading the kernel
 linux  $myimage loglevel=$myloglevel initrd=init.xz root=/dev/ram0 rw ramdisk_size=275000 keymap= web=$myfogip/fog/ boottype=usb consoleblank=0 rootfstype=ext4
 echo loading the virtual hard drive
 initrd $myinits
 echo booting kernel...
}

menuentry "2. Perform Full Host Registration and Inventory" {
 echo loading the kernel
 linux  $myimage loglevel=$myloglevel initrd=init.xz root=/dev/ram0 rw ramdisk_size=275000 keymap= web=$myfogip/fog/ boottype=usb consoleblank=0 rootfstype=ext4 mode=manreg
 echo loading the virtual hard drive
 initrd $myinits
 echo booting kernel...
}

menuentry "3. Quick Registration and Inventory" {
 echo loading the kernel
 linux  $myimage loglevel=$myloglevel initrd=init.xz root=/dev/ram0 rw ramdisk_size=275000 keymap= web=$myfogip/fog/ boottype=usb consoleblank=0 rootfstype=ext4 mode=autoreg
 echo loading the virtual hard drive
 initrd $myinits
 echo booting kernel...
}

menuentry "4. Client System Information (Compatibility)" {
 echo loading the kernel
 linux  $myimage loglevel=$myloglevel initrd=init.xz root=/dev/ram0 rw ramdisk_size=275000 keymap= web=$myfogip/fog/ boottype=usb consoleblank=0 rootfstype=ext4 mode=sysinfo
 echo loading the virtual hard drive
 initrd $myinits
 echo booting kernel...
}

menuentry "5. Run Memtest86+" {
 linux /boot/memdisk iso raw
 initrd /boot/memtest.bin
}

menuentry "6. FOG Debug Kernel" {
 echo loading the kernel
 linux  $myimage loglevel=7 init=/sbin/init root=/dev/ram0 rw ramdisk_size=275000 keymap= boottype=usb consoleblank=0 rootfstype=ext4 isdebug=yes
 echo loading the virtual hard drive
 initrd $myinits
 echo booting kernel...
}

menuentry "7. FOG iPXE Jumpstart BIOS" {
 echo loading the kernel
 linux16  /boot/ipxe.krn
 echo booting iPXE...
}

menuentry "8. FOG iPXE Jumpstart EFI" {
 echo chain loading the kernel
 insmod chain 
 chainloader /boot/ipxe.efi
 echo booting iPXE-efi...
}

EOF
 
echo Unmount the loopback
umount $MOUNT
rmdir $MOUNT
 
echo Unmap the image
kpartx -d /tmp/fos-usb.img
 
# Write the file to flash drive
# sudo dd bs=1M if=/tmp/fos-usb.img of=/dev/sdX
