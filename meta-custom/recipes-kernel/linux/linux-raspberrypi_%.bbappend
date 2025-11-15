# Enable FIT image generation with signature
KERNEL_IMAGETYPE = "fitImage"
KERNEL_CLASSES += "kernel-fitimage"

# FIT image signing configuration
UBOOT_SIGN_ENABLE = "1"
UBOOT_SIGN_KEYDIR = "${TOPDIR}/../meta-custom/recipes-bsp/u-boot/files/keys"
UBOOT_SIGN_KEYNAME = "dev"
UBOOT_MKIMAGE_DTCOPTS = "-I dts -O dtb -p 2000"

# Kernel load addresses for Raspberry Pi 4 (ARM64)
UBOOT_ENTRYPOINT = "0x00080000"
UBOOT_LOADADDRESS = "0x00080000"

# Ensure kernel device tree is included in FIT image
KERNEL_DEVICETREE:append = " broadcom/bcm2711-rpi-4-b.dtb"

# Dependencies for signing
DEPENDS += "u-boot-tools-native dtc-native openssl-native"
