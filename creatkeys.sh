# create-keys.sh
#!/bin/bash
mkdir -p ../meta-custom/recipes-bsp/secure-boot/keys
cd ../meta-custom/recipes-bsp/secure-boot/keys

# Generate RSA key pair for signing
openssl genrsa -F4 -out rsa_private.pem 2048
openssl rsa -in rsa_private.pem -out rsa_public.pem -pubout

# Convert public key to U-Boot format
openssl rsa -in rsa_private.pem -out rsa_public.ub -pubout -outform DER

echo "Keys generated in ../meta-custom/recipes-bsp/secure-boot/keys/"