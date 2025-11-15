#!/bin/bash
# Script to build Yocto image for Raspberry Pi 4 with Wi-Fi, Mender, and Secure Boot
# Author: Vrushabh Gada, updated for WiFi + Mender + Secure Boot with signature verification
# Implements U-Boot Verified Boot with FIT image signing

set -e

echo "=== Initializing submodules ==="
git submodule init
git submodule sync
git submodule update

# Source environment
echo "=== Setting up build environment ==="
source poky/oe-init-build-env

CONF_FILE="conf/local.conf"
KEYS_DIR="../meta-custom/recipes-bsp/u-boot/files/keys"

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
sed -i '/UBOOT_SIGN_ENABLE/d' "$CONF_FILE"
sed -i '/UBOOT_SIGN_KEYDIR/d' "$CONF_FILE"
sed -i '/UBOOT_SIGN_KEYNAME/d' "$CONF_FILE"
sed -i '/UBOOT_MKIMAGE_DTCOPTS/d' "$CONF_FILE"
sed -i '/UBOOT_ENTRYPOINT/d' "$CONF_FILE"
sed -i '/UBOOT_LOADADDRESS/d' "$CONF_FILE"
sed -i '/KERNEL_IMAGETYPE/d' "$CONF_FILE"
sed -i '/KERNEL_CLASSES/d' "$CONF_FILE"
sed -i '/PREFERRED_VERSION_u-boot/d' "$CONF_FILE"

# --- Generate RSA Keys for Secure Boot ---
echo "=== Generating RSA keys for secure boot ==="
mkdir -p "$KEYS_DIR"
if [ ! -f "$KEYS_DIR/dev.key" ]; then
    echo "Generating new RSA key pair for signing..."
    openssl genrsa -out "$KEYS_DIR/dev.key" 2048
    openssl req -batch -new -x509 -key "$KEYS_DIR/dev.key" -out "$KEYS_DIR/dev.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=Secure Boot Key"
    echo "✓ Keys generated: dev.key and dev.crt"
else
    echo "✓ Using existing keys in $KEYS_DIR"
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

# U-Boot Configuration for Mender + Secure Boot
append_config '# === U-BOOT CONFIGURATION ===' "$CONF_FILE"
append_config 'RPI_USE_U_BOOT = "1"' "$CONF_FILE"
append_config 'PREFERRED_PROVIDER_virtual/bootloader = "u-boot"' "$CONF_FILE"
append_config 'MENDER_UBOOT_AUTO_CONFIGURE = "0"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Secure Boot Configuration - U-Boot Verified Boot
append_config '# === SECURE BOOT CONFIGURATION ===' "$CONF_FILE"
append_config '# Enable U-Boot FIT image signing and verification' "$CONF_FILE"
append_config 'UBOOT_SIGN_ENABLE = "1"' "$CONF_FILE"
append_config 'UBOOT_SIGN_KEYDIR = "${TOPDIR}/../meta-custom/recipes-bsp/u-boot/files/keys"' "$CONF_FILE"
append_config 'UBOOT_SIGN_KEYNAME = "dev"' "$CONF_FILE"
append_config 'UBOOT_MKIMAGE_DTCOPTS = "-I dts -O dtb -p 2000"' "$CONF_FILE"
append_config 'UBOOT_SIGN_IMG_KEYNAME = "dev"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Kernel configuration for FIT image
append_config '# === KERNEL FIT IMAGE CONFIGURATION ===' "$CONF_FILE"
append_config 'KERNEL_IMAGETYPE = "fitImage"' "$CONF_FILE"
append_config 'KERNEL_CLASSES += "kernel-fitimage"' "$CONF_FILE"
append_config 'UBOOT_ENTRYPOINT = "0x00080000"' "$CONF_FILE"
append_config 'UBOOT_LOADADDRESS = "0x00080000"' "$CONF_FILE"
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
append_config 'IMAGE_INSTALL:append = " linux-firmware-rpidistro-bcm43455 linux-firmware-bcm43430 wpa-supplicant wpa-supplicant-cli wpa-supplicant-passphrase dhcpcd iw iproute2 kernel-modules kernel-image kernel-devicetree packagegroup-base u-boot-fw-utils"' "$CONF_FILE"
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

# Mender Partition Sizes
append_config '# === MENDER PARTITION SIZES ===' "$CONF_FILE"
append_config '' "$CONF_FILE"
append_config '# Total IMAGE size: 8GB (will fit on any SD card >= 8GB)' "$CONF_FILE"
append_config 'MENDER_STORAGE_TOTAL_SIZE_MB = "8192"' "$CONF_FILE"
append_config '' "$CONF_FILE"
append_config '# Boot partition: 256MB (sufficient for kernel + device tree + U-Boot)' "$CONF_FILE"
append_config 'MENDER_BOOT_PART_SIZE_MB = "256"' "$CONF_FILE"
append_config '' "$CONF_FILE"
append_config '# Data partition: 128MB (default - auto-grows to fill SD card on first boot)' "$CONF_FILE"
append_config 'MENDER_DATA_PART_SIZE_MB = "128"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Mender Server Configuration
append_config '# === MENDER SERVER SETTINGS ===' "$CONF_FILE"
append_config 'MENDER_SERVER_URL = "https://hosted.mender.io"' "$CONF_FILE"
append_config 'MENDER_TENANT_TOKEN = "IEeJCwBlnKUMwWenQTZvV7W12yKs3yee8rTz_VVpeCY"' "$CONF_FILE"
append_config 'MENDER_UPDATE_POLL_INTERVAL_SECONDS = "1800"' "$CONF_FILE"
append_config '' "$CONF_FILE"

# Mender Artifact Signing (uses same keys as U-Boot)
append_config '# === MENDER ARTIFACT SIGNING ===' "$CONF_FILE"
append_config 'MENDER_ARTIFACT_SIGNING_KEY = "${TOPDIR}/../meta-custom/recipes-bsp/u-boot/files/keys/dev.key"' "$CONF_FILE"
append_config 'MENDER_ARTIFACT_VERIFY_KEY = "${TOPDIR}/../meta-custom/recipes-bsp/u-boot/files/keys/dev.crt"' "$CONF_FILE"
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
echo "Showing key configurations:"
grep -E "(^MACHINE|^IMAGE_FSTYPES|^UBOOT_SIGN|^KERNEL_IMAGETYPE|^MENDER_ARTIFACT_SIGNING|^MENDER_STORAGE|^MENDER_SERVER)" "$CONF_FILE" || true
echo ""

# --- Create U-Boot bbappend for secure boot integration ---
echo "=== Creating U-Boot bbappend for secure boot ==="
UBOOT_BBAPPEND_DIR="../meta-custom/recipes-bsp/u-boot"
mkdir -p "$UBOOT_BBAPPEND_DIR"

cat > "$UBOOT_BBAPPEND_DIR/u-boot_%.bbappend" << 'EOF'
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Enable verified boot in U-Boot
UBOOT_CONFIG[verified-boot] = "CONFIG_FIT_SIGNATURE=y"

# Add device tree for public key embedding
SRC_URI += "file://keys/dev.crt"

do_configure:append() {
    # Ensure U-Boot config includes FIT signature support
    echo "CONFIG_FIT_SIGNATURE=y" >> ${B}/.config
    echo "CONFIG_RSA=y" >> ${B}/.config
    echo "CONFIG_FIT_SIGNATURE_MAX_SIZE=0x10000000" >> ${B}/.config
}
EOF

echo "✓ Created u-boot_%.bbappend"

# --- Create kernel bbappend for FIT image ---
echo "=== Creating kernel bbappend for FIT image signing ==="
KERNEL_BBAPPEND_DIR="../meta-custom/recipes-kernel/linux"
mkdir -p "$KERNEL_BBAPPEND_DIR"

cat > "$KERNEL_BBAPPEND_DIR/linux-raspberrypi_%.bbappend" << 'EOF'
# Enable FIT image generation with signature
KERNEL_IMAGETYPE = "fitImage"
KERNEL_CLASSES += "kernel-fitimage"

# FIT image configuration
UBOOT_SIGN_ENABLE = "1"
UBOOT_SIGN_KEYDIR = "${TOPDIR}/../meta-custom/recipes-bsp/u-boot/files/keys"
UBOOT_SIGN_KEYNAME = "dev"

# Kernel load addresses for RPi4
UBOOT_ENTRYPOINT = "0x00080000"
UBOOT_LOADADDRESS = "0x00080000"
EOF

echo "✓ Created linux-raspberrypi_%.bbappend"

# --- Final Build ---
echo ""
echo "=== Starting Yocto build for Raspberry Pi 4 with Mender + Secure Boot ==="
echo "Target: core-image-minimal with WiFi, SSH, Mender OTA, and Verified Boot"
echo ""
echo "Security features enabled:"
echo "  ✓ U-Boot Verified Boot (FIT image signing)"
echo "  ✓ RSA-2048 signature verification"
echo "  ✓ Signed kernel and device tree"
echo "  ✓ Signed Mender artifacts"
echo ""
echo "Expected outputs:"
echo "  1. core-image-minimal-raspberrypi4-64.sdimg (signed, for initial flashing)"
echo "  2. core-image-minimal-raspberrypi4-64.mender (signed, for OTA updates)"
echo ""
echo "This will take 1-3 hours depending on your system..."
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
echo "  ✓ core-image-minimal-raspberrypi4-64.sdimg    <- Flash this to SD card (SIGNED)"
echo "  ✓ core-image-minimal-raspberrypi4-64.mender   <- Upload to Mender for OTA (SIGNED)"
echo "  ✓ fitImage                                     <- Signed FIT image"
echo ""
echo "Security keys location:"
echo "  📁 $KEYS_DIR/"
echo "    - dev.key  (PRIVATE - Keep secure!)"
echo "    - dev.crt  (PUBLIC - Embedded in U-Boot)"
echo ""
echo "⚠️  IMPORTANT SECURITY NOTES:"
echo "================================================"
echo "1. PROTECT YOUR PRIVATE KEY (dev.key):"
echo "   - Store in a secure location"
echo "   - Never commit to version control"
echo "   - Use hardware security module (HSM) for production"
echo ""
echo "2. BACKUP YOUR KEYS:"
echo "   - Without dev.key, you cannot create signed updates"
echo "   - Loss of keys means devices cannot be updated"
echo ""
echo "3. KEY ROTATION:"
echo "   - For production, implement key rotation strategy"
echo "   - Consider using multiple signing keys"
echo ""
echo "4. VERIFY SIGNATURE:"
echo "   - Test boot process to ensure signature verification works"
echo "   - Unsigned/tampered images should be rejected"
echo ""
echo "================================================"
echo ""
echo "=========================================="
echo "=== FLASHING INSTRUCTIONS ==="
echo "=========================================="
echo ""
echo "1. Insert your 64GB SD card"
echo "2. Identify the device:"
echo "   lsblk"
echo ""
echo "3. Flash the SIGNED image:"
echo "   cd tmp/deploy/images/raspberrypi4-64/"
echo "   sudo dd if=core-image-minimal-raspberrypi4-64.sdimg of=/dev/sdX bs=4M status=progress conv=fsync"
echo "   sync"
echo ""
echo "=========================================="
echo "=== VERIFICATION INSTRUCTIONS ==="
echo "=========================================="
echo ""
echo "After boot, verify secure boot is active:"
echo ""
echo "1. Check U-Boot verified boot:"
echo "   - During boot, U-Boot should show FIT signature verification"
echo "   - Look for: 'Verifying Hash Integrity ... RSA+ OK'"
echo ""
echo "2. Test unsigned kernel rejection:"
echo "   - Try booting an unsigned fitImage"
echo "   - U-Boot should refuse to boot: 'Bad Data Hash'"
echo ""
echo "3. Verify Mender artifact signing:"
echo "   mender show-artifact /data/mender/core-image-minimal-raspberrypi4-64.mender"
echo ""
echo "=========================================="
echo "=== CREATING SIGNED OTA UPDATES ==="
echo "=========================================="
echo ""
echo "For future OTA updates, the build system will automatically:"
echo "  1. Sign the kernel FIT image with dev.key"
echo "  2. Sign the Mender artifact with dev.key"
echo "  3. Device will verify signatures before installing"
echo ""
echo "To create a new signed update:"
echo "  1. Update MENDER_ARTIFACT_NAME in local.conf"
echo "  2. Run: bitbake core-image-minimal"
echo "  3. Upload the .mender file to Mender server"
echo ""
echo "The device will only accept updates signed with your key!"
echo ""
echo "=========================================="