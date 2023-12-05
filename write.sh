#!/bin/bash

echo "WILL ERASE $1 NOW!!!"
echo "Press CTRL+C to cancel..."
echo "(Starting in 3s)"

sleep 3

echo "Writing..."
dd bs=1M if=/tmp/fos-usb.img of=$1 status=progress
