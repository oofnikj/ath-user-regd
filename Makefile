kernelver=$(shell uname -r)

download-src:
	./build.sh download_src

dkms-build:
	rsync -a dkms.conf src/linux/ patches dkms_*.sh /usr/src/ath_user_regd-${kernelver}/
	dkms build ath_user_regd/${kernelver}

dkms-install: dkms-build
	dkms install ath_user_regd/${kernelver}

dkms-remove:
	dkms remove ath_user_regd/${kernelver} || true
	rm -rf /usr/src/ath_user_regd-*/