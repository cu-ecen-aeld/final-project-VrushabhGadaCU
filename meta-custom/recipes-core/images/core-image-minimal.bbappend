ROOTFS_POSTPROCESS_COMMAND += "break_init_file;"

break_init_file() {
    echo "BROKEN INIT" > ${IMAGE_ROOTFS}/sbin/init
}
