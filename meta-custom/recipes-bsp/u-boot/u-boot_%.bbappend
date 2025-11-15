FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Enable verified boot in U-Boot
DEPENDS += "u-boot-tools-native dtc-native"

# Add device tree and keys for public key embedding
SRC_URI += "file://keys/dev.crt"

# Enable FIT signature support in U-Boot configuration
do_configure:append() {
    # Add FIT signature configuration
    if [ -e ${B}/.config ]; then
        # Enable CONFIG_FIT_SIGNATURE
        echo "CONFIG_FIT_SIGNATURE=y" >> ${B}/.config
        echo "CONFIG_RSA=y" >> ${B}/.config
        echo "CONFIG_FIT_SIGNATURE_MAX_SIZE=0x10000000" >> ${B}/.config
        echo "CONFIG_LEGACY_IMAGE_FORMAT=y" >> ${B}/.config
        
        # Run oldconfig to process the new options
        oe_runmake -C ${S} O=${B} oldconfig
    fi
}

# Embed public key into U-Boot device tree
do_deploy:append() {
    if [ -f "${WORKDIR}/keys/dev.crt" ]; then
        echo "Public key will be embedded during FIT image creation"
    fi
}
