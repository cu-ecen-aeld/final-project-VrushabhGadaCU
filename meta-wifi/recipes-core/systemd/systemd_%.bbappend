FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://wifi-autoconnect.service"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/wifi-autoconnect.service ${D}${systemd_system_unitdir}/
}

SYSTEMD_AUTO_ENABLE = "enable"
