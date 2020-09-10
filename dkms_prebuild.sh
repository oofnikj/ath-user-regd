#!/bin/sh
set -ex

cp /lib/modules/$(uname -r)/build/.config .
cp /lib/modules/$(uname -r)/build/Module.symvers .
make olddefconfig