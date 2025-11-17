# boot.cmd - Mender-aware U-Boot boot script for Raspberry Pi 4
# This script handles A/B partition booting for Mender OTA updates
# with FIT image (secure boot) support

echo "=== Mender Boot Script for Raspberry Pi 4 ==="

# Memory addresses for Raspberry Pi 4 (ARM64)
setenv kernel_addr_r 0x00080000
setenv fdt_addr_r 0x02600000
setenv ramdisk_addr_r 0x02700000

# Mender boot partition (always boot partition 1)
setenv mender_boot_part 1
setenv bootpart 0:${mender_boot_part}

# Storage device
setenv mender_boot_part_hex 1

# Initialize mender_boot_part from U-Boot environment if it exists
if test "${mender_boot_part}" != ""; then
    echo "Using mender_boot_part from environment: ${mender_boot_part}"
else
    # Default to partition 2 (rootfs A) on first boot
    setenv mender_boot_part 2
    echo "First boot detected, defaulting to partition 2"
fi

# Set root partition based on mender_boot_part
if test "${mender_boot_part}" = "2"; then
    setenv mender_kernel_root /dev/mmcblk0p2
    echo "Booting from Root Partition A (mmcblk0p2)"
elif test "${mender_boot_part}" = "3"; then
    setenv mender_kernel_root /dev/mmcblk0p3
    echo "Booting from Root Partition B (mmcblk0p3)"
else
    # Fallback to partition 2 if something goes wrong
    setenv mender_kernel_root /dev/mmcblk0p2
    setenv mender_boot_part 2
    echo "Invalid partition detected, falling back to partition 2"
fi

# Kernel command line arguments
setenv bootargs "8250.nr_uarts=1 console=ttyS0,115200 console=tty1 root=${mender_kernel_root} rootfstype=ext4 rootwait rw"

# Try to load and boot FIT image (secure boot enabled)
echo "Loading FIT image from mmc 0:1..."
if load mmc 0:1 ${kernel_addr_r} fitImage; then
    echo "FIT image loaded successfully"
    echo "Verifying and booting kernel..."
    # bootm will verify signatures if UBOOT_SIGN_ENABLE=1
    bootm ${kernel_addr_r}
else
    echo "ERROR: Failed to load fitImage from boot partition"
fi

# If we reach here, boot failed - try fallback
echo "=== PRIMARY BOOT FAILED ==="

# Toggle partition for fallback
if test "${mender_boot_part}" = "2"; then
    setenv mender_kernel_root /dev/mmcblk0p3
    setenv mender_boot_part 3
    echo "Attempting fallback to Root Partition B (mmcblk0p3)"
else
    setenv mender_kernel_root /dev/mmcblk0p2
    setenv mender_boot_part 2
    echo "Attempting fallback to Root Partition A (mmcblk0p2)"
fi

# Update bootargs for fallback
setenv bootargs "8250.nr_uarts=1 console=ttyS0,115200 console=tty1 root=${mender_kernel_root} rootfstype=ext4 rootwait rw"

# Retry boot with fallback partition
echo "Retrying boot with fallback partition..."
if load mmc 0:1 ${kernel_addr_r} fitImage; then
    bootm ${kernel_addr_r}
else
    echo "=== CRITICAL: FALLBACK BOOT ALSO FAILED ==="
    echo "System cannot boot. Please check:"
    echo "  1. FIT image exists in boot partition"
    echo "  2. Root partitions are valid"
    echo "  3. Secure boot keys are correct"
fi

# If everything fails, drop to U-Boot prompt
echo "Dropping to U-Boot prompt for manual recovery..."