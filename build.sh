#!/usr/bin/env bash
set -ex

PWD=$(pwd)
SRC_DIR=${SRC_DIR:-${PWD}/src/linux}
BUILD_DIR=/lib/modules/"$(uname -r)"/build
SUBDIR="drivers/net/wireless/ath"
PATCH_FILES=(
	'402-ath_regd_optional.patch'
	'406-ath_relax_default_regd.patch'
)

_get_kernel_version() {
	KVER=($(uname -r | sed -E 's/([0-9])\.([0-9]+)\.([0-9]+).*/\1 \2 \3/'))
	KMAJ=${KVER[0]}
	KMIN=${KVER[1]}
	KREV=${KVER[2]}
}

download_src() {
	if { env | grep -q SRC_DIR ; } ; then
		printf "SRC_DIR set in environment, skipping download\n"
		return 0
	fi
	_get_kernel_version
	wget -qnc https://cdn.kernel.org/pub/linux/kernel/v${KMAJ}.x/linux-${KMAJ}.${KMIN}.${KREV}.tar.xz || true
	mkdir -p $SRC_DIR
	tar xf linux-${KMAJ}.${KMIN}.${KREV}.tar.xz --strip-components=1 -C $SRC_DIR
}

prepare_patches() {
	mkdir -p patches
	for patch in "${PATCH_FILES[@]}"; do
		wget -q "https://git.openwrt.org/?p=openwrt/openwrt.git;a=blob_plain;f=package/kernel/mac80211/patches/ath/${patch};hb=refs/heads/master" -O patches/${patch}
		sed -i "s/CPTCFG/CONFIG/g" patches/${patch}
	done
}

patch_src() {
	for patch in "${PATCH_FILES[@]}"; do 
		patch -d $SRC_DIR --strip 1 --unified --batch --verbose <"patches/$patch" || true
	done
}

build_modules() {
	cp "${BUILD_DIR}/.config" "${SRC_DIR}/"
	cp "${BUILD_DIR}/Module.symvers" "${SRC_DIR}/"
	yes | make -C ${SRC_DIR} modules_prepare
	# make -j"$(nproc)" -C "$SRC_DIR" $SUBDIR
	make -j"$(nproc)" -C "${BUILD_DIR}" M="${SRC_DIR}/${SUBDIR}"
	make -C $SRC_DIR M="${SRC_DIR}/${SUBDIR}" KERNELRELEASE="$(uname -r)" INSTALL_MOD_PATH=build modules_install
}

strip_debug() {
	find $SRC_DIR -name "*.ko" -exec strip -g {} \;
}

main() {
	# prepare_patches
	download_src
	patch_src
	build_modules
	strip_debug
}

main