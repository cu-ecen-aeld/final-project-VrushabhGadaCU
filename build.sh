#!/bin/bash
# Script to build Yocto image for Raspberry Pi 4 with Wi-Fi enabled
# Author: Siddhant Jajoo, updated for WiFi + boot fixes

set -e

echo "=== Initializing submodules ==="
git submodule init
git submodule sync
git submodule update

# Source environment
echo "=== Setting up build environment ==="
source poky/oe-init-build-env

# --- Configuration Lines ---
CONFLINE='MACHINE = "raspberrypi4-64"'
IMAGE='IMAGE_FSTYPES = "wic.bz2"'
MEMORY='GPU_MEM = "16"'
DISTRO_F='DISTRO_FEATURES:append = " wifi systemd"'
SYSTEMD_INIT='VIRTUAL-RUNTIME_init_manager = "systemd"'
SYSTEMD_BACKFILL='DISTRO_FEATURES_BACKFILL_CONSIDERED = "sysvinit"'
IMAGE_F='IMAGE_FEATURES += "ssh-server-openssh"'
IMAGE_ADD='IMAGE_INSTALL:append = " linux-firmware-rpidistro-bcm43455 wpa-supplicant kernel-modules dhcpcd iw iproute2 wpa-supplicant-config"'
CONF_FILE="conf/local.conf"

# --- Ensure local.conf exists ---
if [ ! -f "$CONF_FILE" ]; then
    echo "Error: local.conf not found. Make sure build environment is set correctly."
    exit 1
fi

# --- Clean up any duplicate or malformed configuration lines ---
echo "=== Cleaning up existing configuration lines ==="
sed -i '/^MACHINE = "raspberrypi4-64"/d' "$CONF_FILE"
sed -i '/^IMAGE_FSTYPES = "wic.bz2"/d' "$CONF_FILE"
sed -i '/^GPU_MEM = "16"/d' "$CONF_FILE"
sed -i '/DISTRO_FEATURES:append.*wifi/d' "$CONF_FILE"
sed -i '/VIRTUAL-RUNTIME_init_manager/d' "$CONF_FILE"
sed -i '/DISTRO_FEATURES_BACKFILL_CONSIDERED/d' "$CONF_FILE"
sed -i '/IMAGE_FEATURES.*ssh-server-openssh/d' "$CONF_FILE"
sed -i '/IMAGE_INSTALL:append/d' "$CONF_FILE"

# --- Append configuration lines ---
echo "=== Configuring local.conf ==="
append_config() {
    local line="$1"
    local file="$2"
    echo "Adding: $line"
    echo "$line" >> "$file"
}

append_config "$CONFLINE" "$CONF_FILE"
append_config "$IMAGE" "$CONF_FILE"
append_config "$MEMORY" "$CONF_FILE"
append_config "$DISTRO_F" "$CONF_FILE"
append_config "$SYSTEMD_INIT" "$CONF_FILE"
append_config "$SYSTEMD_BACKFILL" "$CONF_FILE"
append_config "$IMAGE_F" "$CONF_FILE"
append_config "$IMAGE_ADD" "$CONF_FILE"

echo ""
echo "=== Final local.conf WiFi configuration ==="
grep -E "(MACHINE|IMAGE_FSTYPES|GPU_MEM|DISTRO_FEATURES|IMAGE_FEATURES|IMAGE_INSTALL)" "$CONF_FILE"
echo ""

# --- Add Layers if Missing ---
add_layer_if_missing() {
    local layer_path="$1"
    local layer_name
    layer_name=$(basename "$layer_path")
    if ! bitbake-layers show-layers | grep -q "$layer_name"; then
        echo "Adding layer: $layer_path"
        bitbake-layers add-layer "$layer_path"
    else
        echo "Layer $layer_name already exists"
    fi
}

echo "=== Checking and adding layers ==="
add_layer_if_missing "../meta-openembedded/meta-oe"
add_layer_if_missing "../meta-openembedded/meta-python"
add_layer_if_missing "../meta-openembedded/meta-networking"
add_layer_if_missing "../meta-raspberrypi"
add_layer_if_missing "../meta-custom"

# --- Final Build ---
echo ""
echo "=== Starting Yocto build for Raspberry Pi 4 ==="
echo "This will take a while (1-3 hours depending on your system)..."
echo ""
bitbake core-image-minimal

echo ""
echo "=== Build Complete ==="
echo "Image location: tmp/deploy/images/raspberrypi4-64/"
echo ""
echo "To flash the image to SD card:"
echo "  cd build/tmp/deploy/images/raspberrypi4-64/"
echo "  bunzip2 -dkf core-image-minimal-raspberrypi4-64.wic.bz2"
echo "  sudo dd if=core-image-minimal-raspberrypi4-64.wic of=/dev/sdX bs=4M status=progress conv=fsync"
echo "  sync"
echo "  sudo eject /dev/sdb"
