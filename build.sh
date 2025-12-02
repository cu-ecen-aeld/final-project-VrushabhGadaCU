#!/bin/bash
# Script to build Yocto image for Raspberry Pi 4 with Wi-Fi and Mender enabled
# Author: Vrushabh Gada, updated for WiFi + boot fixes + Mender support
# Fixed partition configuration per Mender docs

set -e

echo "=== Initializing submodules ==="
git submodule init
git submodule sync
git submodule update

# Source environment
echo "=== Setting up build environment ==="
source poky/oe-init-build-env

CONF_FILE="conf/local.conf"

# --- Ensure local.conf exists ---
if [ ! -f "$CONF_FILE" ]; then
    echo "Error: local.conf not found. Make sure build environment is set correctly."
    exit 1
fi

# --- IMPORTANT: Clean up ALL previous configuration to start fresh ---
echo "=== Cleaning up existing configuration from local.conf ==="
sed -i '/INHERIT.*mender/d' "$CONF_FILE"
sed -i '/MENDER_/d' "$CONF_FILE"
sed -i '/^MACHINE = "raspberrypi4-64"/d' "$CONF_FILE"
sed -i '/IMAGE_FSTYPES/d' "$CONF_FILE"
sed -i '/SDIMG_ROOTFS_TYPE/d' "$CONF_FILE"
sed -i '/^GPU_MEM/d' "$CONF_FILE"
sed -i '/DISTRO_FEATURES.*wifi/d' "$CONF_FILE"
sed -i '/VIRTUAL-RUNTIME_init_manager/d' "$CONF_FILE"
sed -i '/DISTRO_FEATURES_BACKFILL_CONSIDERED/d' "$CONF_FILE"
sed -i '/IMAGE_FEATURES.*ssh/d' "$CONF_FILE"
sed -i '/IMAGE_INSTALL:append/d' "$CONF_FILE"
sed -i '/ENABLE_UART/d' "$CONF_FILE"
sed -i '/SERIAL_CONSOLES/d' "$CONF_FILE"
sed -i '/RPI_EXTRA_CONFIG/d' "$CONF_FILE"
sed -i '/RPI_USE_U_BOOT/d' "$CONF_FILE"
sed -i '/PREFERRED_PROVIDER_virtual\/bootloader/d' "$CONF_FILE"
sed -i '/IMAGE_OVERHEAD_FACTOR/d' "$CONF_FILE"
sed -i '/IMAGE_ROOTFS_EXTRA_SPACE/d' "$CONF_FILE"

# --- Add Layers FIRST ---
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
add_layer_if_missing "../meta-mender/meta-mender-core"
add_layer_if_missing "../meta-mender/meta-mender-raspberrypi"
add_layer_if_missing "../meta-custom"

# --- Append configuration lines ---
echo "=== Configuring local.conf ==="
append_config() {
    local line="$1"
    local file="$2"
    echo "Adding: $line"
    echo "$line" >> "$file"
}

# Mender Signed Artifacts Configuration
append_config '# === MENDER SIGNED ARTIFACTS ===' "$CONF_FILE"
append_config 'MENDER_ARTIFACT_SIGNING_KEY = "${TOPDIR}/../keys/private.key"' "$CONF_FILE"
append_config 'MENDER_ARTIFACT_VERIFY_KEY = "${TOPDIR}/../keys/public.key"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Ensure the keys directory exists
if [ ! -d "../keys" ]; then
    echo "=== Generating Mender signing keys ==="
    mkdir -p ../keys
    openssl genpkey -algorithm RSA -out ../keys/private.key -pkeyopt rsa_keygen_bits:3072
    openssl rsa -in ../keys/private.key -out ../keys/public.key -pubout
    chmod 600 ../keys/private.key
    chmod 644 ../keys/public.key
    echo "✓ Keys generated in keys/ directory"
    echo "⚠️  IMPORTANT: Keep private.key secure and backed up!"
else
    echo "Keys directory already exists"
fi

# Basic Raspberry Pi Configuration
append_config '# === MACHINE CONFIGURATION ===' "$CONF_FILE"
append_config 'MACHINE = "raspberrypi4-64"' "$CONF_FILE"
append_config 'GPU_MEM = "16"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# U-Boot Configuration for Mender
append_config '# === U-BOOT CONFIGURATION ===' "$CONF_FILE"
append_config 'RPI_USE_U_BOOT = "1"' "$CONF_FILE"
append_config 'PREFERRED_PROVIDER_virtual/bootloader = "u-boot"' "$CONF_FILE"
append_config 'MENDER_UBOOT_AUTO_CONFIGURE = "0"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Serial Console Configuration
append_config '# === SERIAL CONSOLE ===' "$CONF_FILE"
append_config 'ENABLE_UART = "1"' "$CONF_FILE"
append_config 'RPI_EXTRA_CONFIG = "hdmi_force_hotplug=1"' "$CONF_FILE"
append_config 'SERIAL_CONSOLES = "115200;ttyS0"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Systemd Configuration
append_config '# === INIT SYSTEM CONFIGURATION ===' "$CONF_FILE"
append_config 'DISTRO_FEATURES:append = " wifi systemd"' "$CONF_FILE"
append_config 'VIRTUAL-RUNTIME_init_manager = "systemd"' "$CONF_FILE"
append_config 'DISTRO_FEATURES_BACKFILL_CONSIDERED = "sysvinit"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Image Features and Packages
append_config '# === IMAGE CONFIGURATION ===' "$CONF_FILE"
append_config 'IMAGE_FEATURES += "ssh-server-openssh"' "$CONF_FILE"
append_config 'IMAGE_INSTALL:append = " linux-firmware-rpidistro-bcm43455 linux-firmware-bcm43430 wpa-supplicant wpa-supplicant-cli wpa-supplicant-passphrase dhcpcd iw iproute2 kernel-modules kernel-image kernel-devicetree packagegroup-base wpa-supplicant-config network-setup"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Image Sizing (allow for growth during updates)
append_config '# === IMAGE SIZE CONFIGURATION ===' "$CONF_FILE"
append_config 'IMAGE_OVERHEAD_FACTOR = "1.5"' "$CONF_FILE"
append_config 'IMAGE_ROOTFS_EXTRA_SPACE = "524288"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Mender Core Configuration
append_config '# === MENDER CONFIGURATION ===' "$CONF_FILE"
append_config 'INHERIT += "mender-full"' "$CONF_FILE"
append_config 'MENDER_FEATURES_ENABLE:append = " mender-uboot mender-image mender-systemd mender-image-sd"' "$CONF_FILE"
append_config 'MENDER_FEATURES_DISABLE:append = " mender-grub mender-image-uefi"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Mender Device Configuration
append_config '# === MENDER DEVICE SETTINGS ===' "$CONF_FILE"
append_config 'MENDER_DEVICE_TYPE = "raspberrypi4"' "$CONF_FILE"
append_config 'MENDER_ARTIFACT_NAME = "corrupted"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Mender Storage Configuration - CRITICAL FOR SD CARD
append_config '# === MENDER STORAGE CONFIGURATION ===' "$CONF_FILE"
append_config 'MENDER_STORAGE_DEVICE = "/dev/mmcblk0"' "$CONF_FILE"
append_config 'MENDER_BOOT_PART = "/dev/mmcblk0p1"' "$CONF_FILE"
append_config 'MENDER_ROOTFS_PART_A = "/dev/mmcblk0p2"' "$CONF_FILE"
append_config 'MENDER_ROOTFS_PART_B = "/dev/mmcblk0p3"' "$CONF_FILE"
append_config 'MENDER_DATA_PART = "/dev/mmcblk0p4"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Mender Partition Sizes - CORRECTED per Mender documentation
# IMPORTANT: MENDER_STORAGE_TOTAL_SIZE_MB sets the IMAGE size, not the SD card size!
# The image will be much smaller than your 64GB SD card, which is fine.
# Layout: Boot (256MB) + RootFS A (auto) + RootFS B (auto) + Data (128MB->grows on boot)
append_config '# === MENDER PARTITION SIZES ===' "$CONF_FILE"
append_config '' "$CONF_FILE"
append_config '# Total IMAGE size: 8GB (will fit on any SD card >= 8GB)' "$CONF_FILE"
append_config '# Your 64GB SD card will have lots of unused space, which is fine' "$CONF_FILE"
append_config 'MENDER_STORAGE_TOTAL_SIZE_MB = "8192"' "$CONF_FILE"
append_config '' "$CONF_FILE"
append_config '# Boot partition: 256MB (sufficient for kernel + device tree + U-Boot)' "$CONF_FILE"
append_config 'MENDER_BOOT_PART_SIZE_MB = "256"' "$CONF_FILE"
append_config '' "$CONF_FILE"
append_config '# Data partition: 128MB (default - auto-grows to fill SD card on first boot)' "$CONF_FILE"
append_config '# Note: systemd-growfs will expand this to use remaining space on your 64GB card' "$CONF_FILE"
append_config 'MENDER_DATA_PART_SIZE_MB = "128"' "$CONF_FILE"
append_config '' "$CONF_FILE"
append_config '# RootFS partitions calculated automatically:' "$CONF_FILE"
append_config '# Each rootfs = (8192 - 256 - 128) / 2 = ~3904 MB (~3.8GB each)' "$CONF_FILE"
append_config '# This is plenty for core-image-minimal + your applications' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Mender Server Configuration
append_config '# === MENDER SERVER SETTINGS ===' "$CONF_FILE"
append_config 'MENDER_SERVER_URL = "https://hosted.mender.io"' "$CONF_FILE"
append_config 'MENDER_TENANT_TOKEN = "IEeJCwBlnKUMwWenQTZvV7W12yKs3yee8rTz_VVpeCY"' "$CONF_FILE"
append_config 'MENDER_UPDATE_POLL_INTERVAL_SECONDS = "1800"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Image Format - CRITICAL: Need BOTH sdimg (for flashing) and mender (for updates)
append_config '# === IMAGE OUTPUT FORMATS ===' "$CONF_FILE"
append_config '# sdimg: For initial SD card flashing' "$CONF_FILE"
append_config '# mender: For OTA updates via Mender server' "$CONF_FILE"
append_config 'IMAGE_FSTYPES = "mender sdimg"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# U-Boot Storage Configuration for Mender
append_config '# === U-BOOT MENDER INTEGRATION ===' "$CONF_FILE"
append_config 'MENDER_UBOOT_STORAGE_INTERFACE = "mmc"' "$CONF_FILE"
append_config 'MENDER_UBOOT_STORAGE_DEVICE = "0"' "$CONF_FILE"
append_config '' "$CONF_FILE"

echo ""
echo "=== Final local.conf configuration preview ==="
echo "Showing key Mender and system configurations:"
grep -E "(^MACHINE|^IMAGE_FSTYPES|^GPU_MEM|^DISTRO_FEATURES|^IMAGE_FEATURES|^MENDER_STORAGE|^MENDER_BOOT|^MENDER_ROOTFS|^MENDER_DATA|^MENDER_SERVER|^MENDER_DEVICE)" "$CONF_FILE" || true
echo ""

# --- Final Build ---
echo ""
echo "=== Starting Yocto build for Raspberry Pi 4 with Mender ==="
echo "Target: core-image-minimal with WiFi, SSH, and Mender OTA support"
echo "Expected outputs:"
echo "  1. core-image-minimal-raspberrypi4-64.sdimg (for initial flashing)"
echo "  2. core-image-minimal-raspberrypi4-64.mender (for OTA updates)"
echo ""
echo "This will take 1-3 hours depending on your system..."
echo "Progress will be displayed below..."
echo ""

bitbake core-image-minimal

echo ""
echo "=========================================="
echo "=== BUILD COMPLETE ==="
echo "=========================================="
echo ""
echo "Output location: tmp/deploy/images/raspberrypi4-64/"
echo ""
echo "Generated files:"
echo "  ✓ core-image-minimal-raspberrypi4-64.sdimg    <- Flash this to SD card"
echo "  ✓ core-image-minimal-raspberrypi4-64.mender   <- Upload to Mender for OTA"
echo ""
echo "Image size: ~8GB (will fit on your 64GB SD card with room to spare)"
echo "Data partition will auto-grow to fill your SD card on first boot!"
echo ""
echo "=========================================="
echo "=== FLASHING INSTRUCTIONS ==="
echo "=========================================="
echo ""
echo "1. Insert your 64GB SD card"
echo "2. Identify the device (usually /dev/sdb or /dev/mmcblk0):"
echo "   lsblk"
echo ""
echo "3. Flash the image (replace /dev/sdX with your SD card device):"
echo "   cd build/tmp/deploy/images/raspberrypi4-64/"
echo "   sudo dd if=core-image-minimal-raspberrypi4.sdimg of=/dev/sdb bs=1M status=progress conv=fsync oflag=direct"
echo "   sync"
echo ""
echo "4. Safely eject:"
echo "   sudo eject /dev/sdX"
echo ""
echo "NOTE: The .sdimg is only ~8GB, but it will work perfectly on your 64GB SD card."
echo "      The data partition will automatically expand to use available space."
echo ""
echo "=========================================="
echo "=== WIFI CONFIGURATION ==="
echo "=========================================="
echo ""
echo "After first boot, configure WiFi:"
echo ""
echo "1. Edit /etc/wpa_supplicant/wpa_supplicant-wlan0.conf"
echo "   network={"
echo "       ssid=\"YourNetworkName\""
echo "       psk=\"YourPassword\""
echo "   }"
echo ""
echo "2. Restart network:"
echo "   systemctl restart wpa_supplicant@wlan0"
echo "   dhcpcd wlan0"
echo ""
echo "=========================================="
echo "=== MENDER SERVER CONNECTION ==="
echo "=========================================="
echo ""
echo "The device will automatically connect to:"
echo "  Server: https://hosted.mender.io"
echo "  Tenant Token: IEeJCwBlnKUMwWenQTZvV7W12yKs3yee8rTz_VVpeCY"
echo ""
echo "Check device status:"
echo "  systemctl status mender-client"
echo ""
echo "Accept the device in your Mender dashboard at:"
echo "  https://hosted.mender.io"
echo ""
echo "=========================================="
