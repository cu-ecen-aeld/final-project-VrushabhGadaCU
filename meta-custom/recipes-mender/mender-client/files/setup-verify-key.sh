#!/bin/bash
# Helper script to convert certificate to PEM format for Mender

KEYS_DIR="../../recipes-bsp/u-boot/files/keys"
OUTPUT_FILE="artifact-verify-key.pem"

if [ ! -f "$KEYS_DIR/dev.crt" ]; then
    echo "Error: dev.crt not found in $KEYS_DIR"
    echo "Please run build-secure.sh first to generate keys"
    exit 1
fi

# Copy the certificate as PEM (it's already in PEM format)
cp "$KEYS_DIR/dev.crt" "$OUTPUT_FILE"

echo "✓ Created $OUTPUT_FILE for Mender artifact verification"
