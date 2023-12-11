#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

if [ -z "$1" ]; then
    echo "Missing target device."
    exit
fi

echo "WILL ERASE $1 NOW!!!"
echo "Press CTRL+C to cancel..."
echo "(Starting in 3s)"

sleep 3

mount | grep "/media" | grep $1 | cut -d" " -f 1 | xargs -r -n1 umount

echo "Writing..."
dd bs=1M if=cache/fos-usb.img of=$1 status=progress

parted --script $1 resizepart 2 100%

echo Waiting for ${1}2 to appear...
until [ -f ${1}2 ]; do sleep 1; done
echo OK

ntfsresize -f ${1}2
