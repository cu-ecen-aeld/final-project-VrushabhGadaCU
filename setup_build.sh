#!/bin/bash
# set your base paths
POKY_DIR="$HOME/Documents/CuBoulder/AESD/Final/poky"
BUILD_DIR="$HOME/Documents/CuBoulder/AESD/Final/build"

# source environment
source $POKY_DIR/oe-init-build-env $BUILD_DIR

# auto-generate bblayers.conf
cat > $BUILD_DIR/conf/bblayers.conf <<EOL
BBLAYERS ?= " \\
$POKY_DIR/meta \\
$POKY_DIR/meta-poky \\
$POKY_DIR/meta-yocto-bsp \\
$HOME/Documents/CuBoulder/AESD/Final/meta-openembedded/meta-oe \\
$HOME/Documents/CuBoulder/AESD/Final/meta-openembedded/meta-python \\
$HOME/Documents/CuBoulder/AESD/Final/meta-openembedded/meta-networking \\
$HOME/Documents/CuBoulder/AESD/Final/meta-raspberrypi \\
$HOME/Documents/CuBoulder/AESD/Final/meta-wifi \\
  "
EOL

# auto-generate local.conf with corrected WiFi configuration
cat > $BUILD_DIR/conf/local.conf <<'EOL'
MACHINE ?= "raspberrypi4-64"
DISTRO ?= "poky"
PACKAGE_CLASSES ?= "package_rpm"
EXTRA_IMAGE_FEATURES ?= "debug-tweaks"
BB_NUMBER_THREADS ?= "8"
PARALLEL_MAKE ?= "-j 8"

# Image format
IMAGE_FSTYPES = "rpi-sdimg"
SDIMG_ROOTFS_TYPE = "ext4"

# Boot configuration
RPI_USE_U_BOOT = "0"
CMDLINE:append = " rootwait"

# GPU Memory
GPU_MEM = "16"

# WiFi support
DISTRO_FEATURES:append = " wifi"
MACHINE_FEATURES:append = " wifi"

# Systemd configuration
DISTRO_FEATURES:append = " systemd usrmerge bluez5 bluetooth"
VIRTUAL-RUNTIME_init_manager = "systemd"
DISTRO_FEATURES_BACKFILL_CONSIDERED = "sysvinit"

# License for commercial firmware
LICENSE_FLAGS_ACCEPTED = "commercial commercial_broadcom_bcm43xx"

# WiFi firmware for RPi4
MACHINE_FEATURES:append = " broadcom-bt-bcm43xx broadcom-wl-bcm43xx"

# REMOVED PROBLEMATIC LINE:
# RPI_KERNEL_DEVICETREE_OVERLAYS:append = " overlays/miniuart-bt.dtbo"

# Additional packages
IMAGE_INSTALL:append = " \
    openssh \
    linux-firmware-bcm43430 \
    wireless-regdb-static \
    crda \
    wpa-supplicant \
    iw \
    kernel-modules \
    bluez5 \
    i2c-tools \
    bridge-utils \
    hostapd \
    iptables \
    dhcpcd \
    networkmanager \
    python3 \
    v4l-utils \
    ntp \
"

# Enable SSH
IMAGE_FEATURES += "ssh-server-openssh"

# Network configuration
PREFERRED_PROVIDER_virtual/kernel = "linux-raspberrypi"

# Ensure kernel modules are included
KERNEL_MODULE_AUTOLOAD:append = " brcmfmac cfg80211"
EOL

echo "Configuration updated. Building image..."
bitbake core-image-base