SUMMARY = "NI gRPC Device Server"
DESCRIPTION = "gRPC server providing remote access to NI device driver APIs."
HOMEPAGE = "https://github.com/ni/grpc-device"
SECTION = "base"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "\
	https://github.com/ni/grpc-device/releases/download/${RELEASE_TAG}/ni-grpc-device-server-ni-linux-rt-x64.tar.gz;name=release-server-tar;downloadfilename=${PN}_${RELEASE_TAG}.tar.gz;subdir=${PN}-server \
	https://github.com/ni/grpc-device/releases/download/${RELEASE_TAG}/ni-grpc-device-client.tar.gz;name=release-client-tar;downloadfilename=${PN}-client_${PN}_${RELEASE_TAG}.tar.gz;subdir=${PN}-client \
"

SRC_URI[release-server-tar.md5sum] = "0385d3b2f42a8be7bdc35d399ff4cdbd"
SRC_URI[release-server-tar.sha256sum] = "a901fc43a3e6dd1bbf97fc538c3cc0964510c6779fe76fbe609219c5e4a9906a"
SRC_URI[release-client-tar.md5sum] = "d0ebf80b0a0dd72e348c718be156c6e6"
SRC_URI[release-client-tar.sha256sum] = "d3039250da01c1b39c58060374e8866f5dc5ef852f97369adfe0d88eea7f6d97"

PV = "1.1.0"
RELEASE_TAG = "v1.1.0-internal"

S = "${WORKDIR}"

do_install_append () {
	install -d ${D}${bindir}
	install --mode=0755 --owner=0 --group=0 ${S}/${PN}-server/ni_grpc_device_server ${D}${bindir}

	install -d ${D}${datadir}/${BPN}
	install --mode=0644 --owner=0 --group=0 ${S}/${PN}-server/server_config.json ${D}${datadir}/${BPN}/server_config.json.example

	# package .proto files from the -client archive for use by developers
	install -d ${D}${includedir}/${PN}
	install --mode 644 --owner=0 --group=0 ${S}/${PN}-client/proto/*.proto ${D}${includedir}/${PN}/
}