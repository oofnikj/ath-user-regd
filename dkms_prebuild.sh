#!/bin/sh
set -ex

cp /lib/modules/$kernelver/build/.config .
cp /lib/modules/$kernelver/build/Module.symvers .
make olddefconfig
# make -C /lib/modules/$kernelver/build olddefconfig