#!/bin/bash

cp cache/fos-usb.img cache/fos-usb.test.img
qemu-system-x86_64 $* -m 1G -drive format=raw,file=cache/fos-usb.test.img
