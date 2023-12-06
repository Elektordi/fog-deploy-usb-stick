#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi


echo "WILL ERASE $1 NOW!!!"
echo "Press CTRL+C to cancel..."
echo "(Starting in 3s)"

sleep 3

echo "Writing..."
dd bs=1M if=cache/fos-usb.img of=$1 status=progress

parted --script $1 resizepart 2 100%
#or: growpart $1 2
resize2fs ${1}2
