FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://wpa_supplicant.conf"

do_install:append() {
    install -d ${D}/etc
    install -m 600 ${WORKDIR}/wpa_supplicant.conf ${D}/etc/wpa_supplicant.conf
}
