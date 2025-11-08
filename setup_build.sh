#!/bin/bash

# set your base paths
POKY_DIR="$HOME/Documents/CuBoulder/AESD/Final/poky"
BUILD_DIR="$HOME/Documents/CuBoulder/AESD/Final/build"

# source environment
source $POKY_DIR/oe-init-build-env $BUILD_DIR

# auto-generate bblayers.conf
cat > $BUILD_DIR/conf/bblayers.conf <<EOL
BBLAYERS ?= " \
  $POKY_DIR/meta \
  $POKY_DIR/meta-poky \
  $POKY_DIR/meta-yocto-bsp \
  $HOME/Documents/CuBoulder/AESD/Final/meta-raspberrypi \
  "
EOL

# auto-generate local.conf
cat > $BUILD_DIR/conf/local.conf <<EOL
MACHINE ?= "raspberrypi4-64"
DISTRO ?= "poky"
PACKAGE_CLASSES ?= "package_rpm"
EXTRA_IMAGE_FEATURES ?= "debug-tweaks"
BB_NUMBER_THREADS ?= "7"
PARALLEL_MAKE ?= "-j 7"
IMAGE_INSTALL:append = " openssh"
DISTRO_FEATURES:append = " systemd usrmerge"
VIRTUAL-RUNTIME_init_manager = "systemd"
DISTRO_FEATURES_append = " bluez5 bluetooth wifi"
IMAGE_INSTALL_append = " linux-firmware-bcm43430 bluez5 i2c-tools python-smbus bridge-utils hostapd dhcp-server iptables wpa-supplicant"

EOL

bitbake core-image-minimal
