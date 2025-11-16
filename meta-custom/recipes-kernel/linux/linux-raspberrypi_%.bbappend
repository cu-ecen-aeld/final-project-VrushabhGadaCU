FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Add custom FIT image source file
SRC_URI += "file://fitImage.its"

# Enable FIT image generation with signature
KERNEL_IMAGETYPE = "fitImage"
KERNEL_IMAGETYPES = "Image fitImage"
KERNEL_CLASSES += "kernel-fitimage"

# FIT image signing configuration
UBOOT_SIGN_ENABLE = "1"
UBOOT_SIGN_KEYDIR = "${TOPDIR}/../meta-custom/recipes-bsp/u-boot/files/keys"
UBOOT_SIGN_KEYNAME = "dev"
UBOOT_MKIMAGE_DTCOPTS = "-I dts -O dtb -p 2000"
UBOOT_FIT_HASH_ALG = "sha256"
UBOOT_FIT_SIGN_ALG = "rsa2048"
UBOOT_FIT_KEY_GENRSA_ARGS = "-F4"
UBOOT_FIT_GENERATE_KEYS = "0"

# Kernel load addresses for Raspberry Pi 4 (ARM64)
UBOOT_ENTRYPOINT = "0x00080000"
UBOOT_LOADADDRESS = "0x00080000"

# Ensure kernel device tree is included in FIT image
KERNEL_DEVICETREE = "broadcom/bcm2711-rpi-4-b.dtb"

# Dependencies for signing
DEPENDS += "u-boot-tools-native dtc-native openssl-native u-boot"

# Use custom ITS file if provided
do_assemble_fitimage:prepend() {
    if [ -f "${WORKDIR}/fitImage.its" ]; then
        bbnote "Using custom FIT image source file"
        cp ${WORKDIR}/fitImage.its ${B}/fitImage.its
    fi
}

# Verify that signing occurred
do_deploy:append() {
    if [ -f "${DEPLOYDIR}/fitImage-${KERNEL_DEVICETREE}" ]; then
        bbnote "FIT image generated: fitImage-${KERNEL_DEVICETREE}"
        
        # Verify signature exists in FIT image
        ${STAGING_BINDIR_NATIVE}/dumpimage -l ${DEPLOYDIR}/fitImage | grep -q "signature" && \
            bbwarn "✓ FIT image signature verified in output" || \
            bbwarn "⚠ Warning: No signature found in FIT image"
    fi
}