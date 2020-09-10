#!/usr/bin/env bash
set -e

PWD=$(pwd)
SRC_DIR=${SRC_DIR:-${PWD}/src/linux}
BUILD_DIR=/lib/modules/"$(uname -r)"/build
SUBDIR="drivers/net/wireless/ath"
PATCH_FILES=(
	'402-ath_regd_optional.patch'
	'406-ath_relax_default_regd.patch'
)

usage() {
	cat <<-EOF
		$0 COMMAND

		Available commands:

		prepare_patches
		  Download OpenWrt patches and modify them for building against
		  a normal Linux kernel.
		
		download_src
		  Try to download a Linux source tarball from kernel.org which
		  matches the running kernel version.
		
		patch_src
		  Apply the kernel patches.
		
		build
		  Build all the kernel modules under '$SUBDIR'.
		
		install
		  Install the kernel modules and strip debug symbols.
	EOF
	exit 1
}

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
	KERNEL_SRC=linux-${KMAJ}.${KMIN}.tar.xz
	printf "Download %s from kernel.org\n" $KERNEL_SRC
	test -f src/$KERNEL_SRC || {
		mkdir -p $SRC_DIR
		wget -q https://cdn.kernel.org/pub/linux/kernel/v${KMAJ}.x/${KERNEL_SRC} -O src/${KERNEL_SRC}

	}
	tar xf src/${KERNEL_SRC} --strip-components=1 -C $SRC_DIR
	printf "Kernel source extracted successfully to %s\n" $SRC_DIR
}

prepare_patches() {
	mkdir -p patches
	for patch in "${PATCH_FILES[@]}"; do
		wget -q "https://git.openwrt.org/?p=openwrt/openwrt.git;a=blob_plain;f=package/kernel/mac80211/patches/ath/${patch};hb=refs/heads/master" -O patches/${patch}
	done
	patch --strip 1 <patches/0001-patch-the-patches.patch
}

patch_src() {
	for patch in "${PATCH_FILES[@]}"; do 
		patch --directory $SRC_DIR --strip 1 <"patches/$patch"
	done
}

build_modules() {
	cp "${BUILD_DIR}/.config" "${SRC_DIR}/"
	cp "${BUILD_DIR}/Module.symvers" "${SRC_DIR}/"
	make -C "${SRC_DIR}" olddefconfig
	make -j"$(nproc)" -C "${BUILD_DIR}" M="${SRC_DIR}/${SUBDIR}"
}

install_modules() {
	make -C "$BUILD_DIR" M="${SRC_DIR}/${SUBDIR}" KERNELRELEASE="$(uname -r)" \
		INSTALL_MOD_PATH="${PWD}/build" \
		INSTALL_MOD_DIR=updates \
		modules_install
}

strip_debug() {
	find $SRC_DIR -name "*.ko" -exec strip -g {} \;
}

main() {
	# prepare_patches
	download_src
	patch_src
	build_modules
	install_modules
	strip_debug
}

# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     main "$@"
# fi

case $1 in
	prepare_patches)
		prepare_patches
	;;
	download_src)
		download_src
	;;
	patch_src)
		patch_src
	;;
	build)
		build_modules
	;;
	install)
		strip_debug
		install
	;;
	*)
		usage
	;;
esac