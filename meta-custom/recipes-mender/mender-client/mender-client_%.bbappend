FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Add public key for artifact verification
SRC_URI += "file://artifact-verify-key.pem"

# Install verification key
do_install:append() {
    install -d ${D}${sysconfdir}/mender
    
    # Install the public key for artifact verification
    if [ -f ${WORKDIR}/artifact-verify-key.pem ]; then
        install -m 0644 ${WORKDIR}/artifact-verify-key.pem ${D}${sysconfdir}/mender/
    fi
}

# Update mender.conf to enable signature verification
do_install:append() {
    # Backup existing mender.conf if it exists
    if [ -f ${D}${sysconfdir}/mender/mender.conf ]; then
        cp ${D}${sysconfdir}/mender/mender.conf ${D}${sysconfdir}/mender/mender.conf.bak
    fi
    
    # Create mender.conf with signature verification enabled
    cat > ${D}${sysconfdir}/mender/mender.conf << MENDEREOF
{
  "ArtifactVerifyKey": "/etc/mender/artifact-verify-key.pem",
  "ServerURL": "https://hosted.mender.io",
  "TenantToken": "IEeJCwBlnKUMwWenQTZvV7W12yKs3yee8rTz_VVpeCY",
  "UpdatePollIntervalSeconds": 1800,
  "InventoryPollIntervalSeconds": 28800,
  "RetryPollIntervalSeconds": 300
}
MENDEREOF
}

FILES:${PN} += "${sysconfdir}/mender/artifact-verify-key.pem"
FILES:${PN} += "${sysconfdir}/mender/mender.conf"
