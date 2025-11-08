#!/bin/bash

# Simple Yocto Raspberry Pi image flasher

IMG_DIR="/home/vrushabh/Documents/CuBoulder/AESD/Final/build/tmp/deploy/images/raspberrypi4-64"
IMG="$IMG_DIR/core-image-minimal-raspberrypi4-64.wic.bz2"

echo "=== Flashing Yocto Image to SD Card ==="

cd "$IMG_DIR" || { echo "Image directory not found!"; exit 1; }

# Decompress image if needed
if [ -f "$IMG" ]; then
    echo "Decompressing image..."
    bunzip2 -fk "$IMG"
else
    echo "No .bz2 image found, looking for decompressed .wic..."
fi

# Find latest .wic file
WIC_FILE=$(ls -t *.wic 2>/dev/null | head -n 1)

if [ -z "$WIC_FILE" ]; then
    echo "No .wic image found!"
    exit 1
fi

echo "Using image: $WIC_FILE"

# Show devices
lsblk
echo
read -p "Enter your SD card device (e.g., /dev/sdb): " DEV
echo "⚠️  This will erase all data on $DEV"
read -p "Type 'yes' to continue: " CONFIRMroot

[ "$CONFIRM" != "yes" ] && echo "Aborted." && exit 0

echo "Writing image... please wait"
sudo dd if="$WIC_FILE" of="$DEV" bs=4M status=progress conv=fsync
sync
sudo eject "$DEV"

echo "✅ Done! Insert the SD card into your Raspberry Pi."
