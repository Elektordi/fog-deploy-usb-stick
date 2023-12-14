# fog-deploy-usb-stick
Standalone USB stick to deploy FOG images

Inspired from https://forums.fogproject.org/topic/7727/building-usb-booting-fos-image/21

# Setup

```
sudo ./build.sh
sudo ./write.sh /dev/sdX
```

You can then put images in second partition of usb stick/disk (NTFS).
Default FOG parameters are:

```
export imgType=n
export osid=9
export imgFormat=5
export imgPartitionType=all
```

You can override them in IMAGES disk, with a file `custom.sh` in root, for all images, or in each image directory.

Valid imgType values:
* `n` = Resizable
* `mps` = Multi partition all disk non resizable
* `mpa` = Multi partition single disk non resizable
* `dd` = Raw

Valid osid values:
* `5` = Windows 7
* `6` = Windows 8
* `7` = Windows 8.1
* `8` = Apple Mac OS
* `9` = Windows 10/11
* `50` = Linux
* `99` = Other
* Full list: https://github.com/FOGProject/fos/blob/89c901f8c87cfbe2e7a1f9751753aca403122358/Buildroot/board/FOG/FOS/rootfs_overlay/usr/share/fog/lib/funcs.sh#L1344

Valid imgFormat values:
* `0` = GZIP Compressed partclone
* `1` = Partimage
* `2` = **SPLITTED** GZIP Compressed partclone
* `3` = Uncompressed partclone
* `4` = **SPLITTED** Uncompressed partclone
* `5` = ZSTD Compressed image.
* `6` = **SPLITTED** ZSTD Compressed image.

Valid imgPartitionType values:
* `all`
* `1`, `2`... (partition number)

Source: https://forums.fogproject.org/topic/9073/fog-boot-alternatives/3
