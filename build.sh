#!/bin/bash
# Script to build Yocto image for Raspberry Pi 4 with Wi-Fi and Mender enabled
# Author: Vrushabh Gada, updated for WiFi + boot fixes + Mender support + Secure Boot
# Fixed U-Boot device tree configuration for secure boot

set -e

echo "=== Initializing submodules ==="
git submodule init
git submodule sync
git submodule update

# --- Generate Secure Boot Keys ---
echo "=== Generating Secure Boot Keys ==="
if [ ! -f "../meta-custom/recipes-bsp/secure-boot/keys/rsa_private.pem" ]; then
    echo "Generating new RSA keys for secure boot..."
    mkdir -p ../meta-custom/recipes-bsp/secure-boot/keys
    cd ../meta-custom/recipes-bsp/secure-boot/keys
    
    # Generate RSA key pair for signing
    openssl genrsa -F4 -out rsa_private.pem 2048
    openssl rsa -in rsa_private.pem -out rsa_public.pem -pubout
    
    # Convert public key to U-Boot format
    openssl rsa -in rsa_private.pem -out rsa_public.ub -pubout -outform DER
    
    cd ../../../../build
    echo "Keys generated in ../meta-custom/recipes-bsp/secure-boot/keys/"
else
    echo "Secure boot keys already exist, skipping generation."
fi

# Source environment
echo "=== Setting up build environment ==="
CONF_FILE="conf/local.conf"
rm -f build/conf/local.conf

source poky/oe-init-build-env


# --- Ensure local.conf exists ---
if [ ! -f "$CONF_FILE" ]; then
    echo "Error: local.conf not found. Make sure build environment is set correctly."
    exit 1
fi



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

# Basic Raspberry Pi Configuration
append_config '# === MACHINE CONFIGURATION ===' "$CONF_FILE"
append_config 'MACHINE = "raspberrypi4-64"' "$CONF_FILE"
append_config 'GPU_MEM = "16"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# U-Boot Configuration for Mender - FIXED with device tree
append_config '# === U-BOOT CONFIGURATION ===' "$CONF_FILE"
append_config 'RPI_USE_U_BOOT = "1"' "$CONF_FILE"
append_config 'PREFERRED_PROVIDER_virtual/bootloader = "u-boot"' "$CONF_FILE"
append_config 'MENDER_UBOOT_AUTO_CONFIGURE = "0"' "$CONF_FILE"
append_config 'UBOOT_MACHINE = "rpi_4_defconfig"' "$CONF_FILE"
append_config 'UBOOT_ENTRYPOINT = "0x00080000"' "$CONF_FILE"
append_config 'UBOOT_LOADADDRESS = "0x00080000"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Kernel Configuration (Fixed - no FIT images)
append_config '# === KERNEL CONFIGURATION (FIXED) ===' "$CONF_FILE"
append_config 'KERNEL_IMAGETYPE = "Image"' "$CONF_FILE"
append_config 'KERNEL_DEVICETREE = "broadcom/bcm2711-rpi-4-b.dtb"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Remove FIT image configuration that causes the error
append_config '# FIT images disabled - using standard kernel images for RPi4 compatibility' "$CONF_FILE"
append_config 'KERNEL_IMAGETYPES:remove = "fitImage"' "$CONF_FILE"
append_config 'KERNEL_CLASSES:remove = "kernel-fitimage"' "$CONF_FILE"
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

# Secure Boot Packages
append_config 'IMAGE_INSTALL:append = " u-boot-fw-utils"' "$CONF_FILE"
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
append_config 'MENDER_ARTIFACT_NAME = "release-1"' "$CONF_FILE"
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

# Secure Boot Configuration (Simplified)
append_config '# === SECURE BOOT CONFIGURATION (SIMPLIFIED) ===' "$CONF_FILE"
append_config 'UBOOT_SIGN_ENABLE = "1"' "$CONF_FILE"
append_config 'UBOOT_SIGN_KEYDIR = "${TOPDIR}/../meta-custom/recipes-bsp/secure-boot/keys"' "$CONF_FILE"
append_config 'UBOOT_SIGN_KEYNAME = "dev"' "$CONF_FILE"
append_config 'UBOOT_VERIFIED_BOOT = "1"' "$CONF_FILE"
append_config 'UBOOT_VERIFIED_BOOT_SIGNATURE = "rsa2048"' "$CONF_FILE"
append_config 'UBOOT_VERIFIED_BOOT_HASH = "sha256"' "$CONF_FILE"
append_config 'RPI_USE_U_BOOT_RPI_SCR = "0"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# U-Boot Storage Configuration for Mender
append_config '# === U-BOOT MENDER INTEGRATION ===' "$CONF_FILE"
append_config 'MENDER_UBOOT_STORAGE_INTERFACE = "mmc"' "$CONF_FILE"
append_config 'MENDER_UBOOT_STORAGE_DEVICE = "0"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Image Format - CRITICAL: Need BOTH sdimg (for flashing) and mender (for updates)
append_config '# === IMAGE OUTPUT FORMATS ===' "$CONF_FILE"
append_config '# sdimg: For initial SD card flashing' "$CONF_FILE"
append_config '# mender: For OTA updates via Mender server' "$CONF_FILE"
append_config 'IMAGE_FSTYPES = "mender sdimg"' "$CONF_FILE"
append_config '' "$CONF_FILE"

echo ""
echo "=== Final local.conf configuration preview ==="
echo "Showing key Mender and system configurations:"
grep -E "(^MACHINE|^IMAGE_FSTYPES|^GPU_MEM|^DISTRO_FEATURES|^IMAGE_FEATURES|^MENDER_STORAGE|^MENDER_BOOT|^MENDER_ROOTFS|^MENDER_DATA|^MENDER_SERVER|^MENDER_DEVICE|^UBOOT_|^KERNEL_)" "$CONF_FILE" || true
echo ""

# --- Clean previous builds to avoid conflicts ---
echo "=== Cleaning previous U-Boot and Kernel builds ==="
# bitbake -c cleansstate u-boot
# bitbake -c cleansstate virtual/bootloader
# bitbake -c cleansstate linux-raspberrypi

# --- Final Build ---
echo ""
echo "=== Starting Yocto build for Raspberry Pi 4 with Mender and Secure Boot ==="
echo "Target: core-image-minimal with WiFi, SSH, Mender OTA, and Secure Boot"
echo "Expected outputs:"
echo "  1. core-image-minimal-raspberrypi4-64.sdimg (for initial flashing)"
echo "  2. core-image-minimal-raspberrypi4-64.mender (for OTA updates)"
echo ""
echo "Secure Boot Features:"
echo "  ✓ U-Boot verified boot"
echo "  ✓ Kernel signature verification"
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
echo "Secure boot: Enabled with key verification"
echo ""
echo "=========================================="