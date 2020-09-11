download-src:
	./build.sh download_src ${KVER}

dkms-build:
	./build.sh dkms_build ${KVER}

dkms-install: dkms-build
	./build.sh dkms_install ${KVER}

dkms-remove:
	./build.sh dkms_remove ${KVER}

help:
	@./build.sh || true

.PHONY: help