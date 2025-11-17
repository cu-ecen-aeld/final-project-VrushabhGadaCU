SUMMARY = "Secure Boot setup for Raspberry Pi with U-Boot"
LICENSE = "MIT"

inherit deploy

S = "${WORKDIR}"

# Key files
KEY_DIR = "${THISDIR}/keys"
PUBLIC_KEY = "rsa_public.ub"

do_configure() {
}

do_compile() {
}

do_install() {
    # Install public key
    install -d ${D}/boot
    install -m 0644 ${KEY_DIR}/${PUBLIC_KEY} ${D}/boot/kernel_key.pub
}

do_deploy() {
    # Deploy key for U-Boot
    install -d ${DEPLOYDIR}
    install -m 0644 ${KEY_DIR}/${PUBLIC_KEY} ${DEPLOYDIR}/kernel_key.pub
}

addtask deploy after do_install

FILES:${PN} = "/boot"