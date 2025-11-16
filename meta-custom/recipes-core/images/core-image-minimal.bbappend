# Add custom packages and boot script to the image

IMAGE_INSTALL:append = " \
    wpa-supplicant-config \
    u-boot-default-script \
"

# Ensure boot script is deployed to boot partition
do_image_sdimg[depends] += "u-boot-default-script:do_deploy"
do_image_mender[depends] += "u-boot-default-script:do_deploy"

# Copy boot script to boot partition during image creation
IMAGE_CMD:sdimg:append() {
    # The boot.scr should already be in DEPLOY_DIR_IMAGE
    if [ -f ${DEPLOY_DIR_IMAGE}/boot.scr ]; then
        bbnote "Boot script will be included in boot partition"
    else
        bbwarn "boot.scr not found in ${DEPLOY_DIR_IMAGE}"
    fi
}