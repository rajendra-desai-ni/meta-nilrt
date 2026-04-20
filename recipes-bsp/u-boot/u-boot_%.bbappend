FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:xilinx-zynq = "\
    file://${UBOOT_ENV_BINARY} \
    file://fw_env.config \
"

do_compile:append() {
    install -m 0644 ${UNPACKDIR}/bootscript.txt ${B}/bootscript.txt
}

do_deploy:append() {
    install -d ${DEPLOYDIR}
    install -m 0644 ${B}/bootscript.txt ${DEPLOYDIR}/bootscript.txt
}