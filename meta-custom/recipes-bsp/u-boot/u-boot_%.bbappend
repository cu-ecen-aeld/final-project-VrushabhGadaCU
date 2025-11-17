# Enable secure boot signing
UBOOT_SIGN_ENABLE = "1"
UBOOT_MKIMAGE_SIGN_ARGS = "-E"

# Keys for signing
UBOOT_SIGN_KEYDIR = "${TOPDIR}/../meta-custom/recipes-bsp/secure-boot/keys"
UBOOT_SIGN_KEYNAME = "dev.key"

# Make sure U-Boot builds its own boot script
# DO NOT install boot.scr manually
