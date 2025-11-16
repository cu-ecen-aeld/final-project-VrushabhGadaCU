SUMMARY = "U-Boot boot script for Raspberry Pi 4 with Mender and Secure Boot"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

DEPENDS = "u-boot-mkimage-native"

SRC_URI = "file://boot.cmd"

S = "${WORKDIR}"

inherit deploy

do_compile() {
    # Compile boot.cmd to boot.scr
    mkimage -A arm64 -T script -C none -n "Boot script" \
        -d ${WORKDIR}/boot.cmd ${B}/boot.scr
}

do_deploy() {
    install -d ${DEPLOYDIR}
    install -m 0644 ${B}/boot.scr ${DEPLOYDIR}/boot.scr
}

addtask deploy before do_build after do_compile

PACKAGE_ARCH = "${MACHINE_ARCH}"
COMPATIBLE_MACHINE = "raspberrypi4-64"