FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Copy the verification key during configure phase
do_configure:prepend() {
    KEY_SOURCE="${TOPDIR}/../meta-custom/recipes-bsp/u-boot/files/keys/dev.crt"
    KEY_DEST="${WORKDIR}/artifact-verify-key.pem"
    
    if [ -f "$KEY_SOURCE" ]; then
        bbnote "Copying verification key from $KEY_SOURCE"
        cp "$KEY_SOURCE" "$KEY_DEST"
    else
        bbfatal "Verification key not found at $KEY_SOURCE - run build script to generate keys first"
    fi
}

# Install verification key
do_install:append() {
    install -d ${D}${sysconfdir}/mender
    
    # Install the public key for artifact verification
    if [ -f ${WORKDIR}/artifact-verify-key.pem ]; then
        install -m 0644 ${WORKDIR}/artifact-verify-key.pem ${D}${sysconfdir}/mender/
        bbnote "Installed artifact verification key"
    else
        bbfatal "artifact-verify-key.pem not found"
    fi
}

# Update mender.conf to enable signature verification
do_install:append() {
    # Backup existing mender.conf if it exists
    if [ -f ${D}${sysconfdir}/mender/mender.conf ]; then
        cp ${D}${sysconfdir}/mender/mender.conf ${D}${sysconfdir}/mender/mender.conf.bak
    fi
    
    # Create mender.conf with signature verification enabled
    cat > ${D}${sysconfdir}/mender/mender.conf << 'MENDEREOF'
{
  "ArtifactVerifyKey": "/etc/mender/artifact-verify-key.pem",
  "ServerURL": "https://hosted.mender.io",
  "TenantToken": "IEeJCwBlnKUMwWenQTZvV7W12yKs3yee8rTz_VVpeCY",
  "UpdatePollIntervalSeconds": 1800,
  "InventoryPollIntervalSeconds": 28800,
  "RetryPollIntervalSeconds": 300
}
MENDEREOF
    
    bbnote "✓ Mender configuration updated with signature verification"
}

FILES:${PN} += "${sysconfdir}/mender/artifact-verify-key.pem"
FILES:${PN} += "${sysconfdir}/mender/mender.conf"

# Ensure the key is readable
CONFFILES:${PN} += "${sysconfdir}/mender/mender.conf"