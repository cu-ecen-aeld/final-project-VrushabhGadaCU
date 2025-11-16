# U-Boot boot script for Raspberry Pi 4 with Mender and Secure Boot
# This script loads and verifies the signed FIT image

# Enable detailed boot output
setenv bootdelay 2
setenv verify yes

# Mender boot variables (set by Mender)
# mender_kernel_root will be set to either /dev/mmcblk0p2 or /dev/mmcblk0p3

# Set boot arguments
setenv bootargs "console=serial0,115200 console=tty1 root=${mender_kernel_root} rootfstype=ext4 rootwait"

# Memory addresses for loading
setenv kernel_addr_r 0x00080000
setenv fdt_addr_r 0x02600000
setenv fit_addr_r 0x10000000

echo "=== Raspberry Pi 4 Secure Boot ==="
echo "Booting from: ${mender_kernel_root}"
echo "Loading signed FIT image..."

# Load FIT image from boot partition
if load ${mender_uboot_dev_type} ${mender_uboot_dev}:${mender_boot_part} ${fit_addr_r} /fitImage; then
    echo "FIT image loaded successfully"
    echo "Verifying signature with embedded public key..."
    
    # Boot from FIT image - this will automatically verify the signature
    # If signature verification fails, bootm will refuse to boot
    if bootm ${fit_addr_r}; then
        echo "ERROR: Should not reach here - bootm failed"
    else
        echo "ERROR: FIT image boot failed"
    fi
else
    echo "ERROR: Failed to load FIT image"
    echo "Attempting fallback boot with unsigned kernel..."
    
    # Fallback to unsigned boot (for recovery)
    if load ${mender_uboot_dev_type} ${mender_uboot_dev}:${mender_boot_part} ${kernel_addr_r} /Image; then
        if load ${mender_uboot_dev_type} ${mender_uboot_dev}:${mender_boot_part} ${fdt_addr_r} /bcm2711-rpi-4-b.dtb; then
            echo "WARNING: Booting UNSIGNED kernel (recovery mode)"
            booti ${kernel_addr_r} - ${fdt_addr_r}
        fi
    fi
fi

echo "ERROR: All boot attempts failed"
reset