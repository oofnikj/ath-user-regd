#!/usr/bin/env bash
set -e
# set -x

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
		
		download_src [KVER]
		  Try to download a Linux source tarball from kernel.org which
		  matches the running kernel version (or KVER if specified).
		
		patch_src
		  Apply the kernel patches.
		
		build
		  Build all the kernel modules under '$SUBDIR'.
		
		install
		  Install the kernel modules and strip debug symbols.

		dkms_{ build | install | remove }
			Perform the indicated function through DKMS.
	EOF
	exit 1
}

_get_kernel_version() {
	KVER=${1:-$(uname -r)}
	KARR=($(sed -E 's/^([0-9])\.([0-9]+)\.?([0-9]+)?.*/\1 \2 \3/' <<< $KVER))
	KMAJ=${KARR[0]}
	KMIN=${KARR[1]}
	KREV=${KARR[2]}
	MODULE_VERSION=${KMAJ}.${KMIN}
}

download_src() {
	if { env | grep -q SRC_DIR ; } ; then
		printf "SRC_DIR set in environment, skipping download\n"
		return 0
	fi
	_get_kernel_version "$1"
	KERNEL_SRC=linux-${KMAJ}.${KMIN}.tar.xz
	mkdir -p $SRC_DIR
	test -f src/$KERNEL_SRC || {
		printf "Download %s from kernel.org\n" $KERNEL_SRC
		wget -q https://cdn.kernel.org/pub/linux/kernel/v${KMAJ}.x/${KERNEL_SRC} -O src/${KERNEL_SRC}

	}
	printf "Extract kernel source to %s\n" $SRC_DIR
	tar xf src/${KERNEL_SRC} --strip-components=1 -C $SRC_DIR
	printf "Kernel source extracted successfully\n"
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

dkms_build() {
	_get_kernel_version "$1"
	rsync -a src/linux/ patches dkms_*.sh /usr/src/ath_user_regd-${MODULE_VERSION}/
	sed -E "s/(PACKAGE_VERSION=)/\1${MODULE_VERSION}/" dkms.conf > /usr/src/ath_user_regd-${MODULE_VERSION}/dkms.conf
	dkms build "ath_user_regd/${MODULE_VERSION}"
}

dkms_install() {
	_get_kernel_version "$1"
	dkms install "ath_user_regd/${MODULE_VERSION}"
}

dkms_remove() {
	_get_kernel_version "$1"
	dkms remove "ath_user_regd/${MODULE_VERSION}" || true
	rm -rf /usr/src/ath_user_regd-${MODULE_VERSION}
	rm -rf /var/lib/dkms/ath_user_regd/${MODULE_VERSION}
}

main() {
	# prepare_patches
	download_src
	patch_src
	build_modules
	install_modules
	strip_debug
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	case $1 in
		prepare_patches)
			prepare_patches
		;;
		download_src)
			shift
			download_src "$1"
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
		dkms_build)
			shift
			dkms_build "$1"
		;;
		dkms_install)
			shift
			dkms_install "$1"
		;;
		dkms_remove)
			shift
			dkms_remove "$1"
		;;
		*)
			usage
		;;
	esac
fi
