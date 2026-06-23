#!/bin/bash
# Downloads and extracts the Sparkle framework for linking
set -euo pipefail

SPARKLE_VERSION="2.9.2"
SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
FRAMEWORK_DIR="$(dirname "$0")/../Frameworks"

if [ -d "${FRAMEWORK_DIR}/Sparkle.framework" ]; then
    echo "✓ Sparkle.framework already exists in Frameworks/"
    exit 0
fi

echo "Downloading Sparkle ${SPARKLE_VERSION}..."
TMPDIR=$(mktemp -d)
curl -L -o "${TMPDIR}/Sparkle.tar.xz" "${SPARKLE_URL}"

echo "Extracting..."
tar -xf "${TMPDIR}/Sparkle.tar.xz" -C "${TMPDIR}"

mkdir -p "${FRAMEWORK_DIR}"
cp -R "${TMPDIR}/Sparkle.framework" "${FRAMEWORK_DIR}/"

# Copy Sparkle CLI tools (generate_keys, sign_update)
if [ -f "${TMPDIR}/bin/generate_keys" ]; then
    mkdir -p "${FRAMEWORK_DIR}/bin"
    cp "${TMPDIR}/bin/generate_keys" "${FRAMEWORK_DIR}/bin/"
    cp "${TMPDIR}/bin/sign_update" "${FRAMEWORK_DIR}/bin/"
    chmod +x "${FRAMEWORK_DIR}/bin/generate_keys" "${FRAMEWORK_DIR}/bin/sign_update"
fi

rm -rf "${TMPDIR}"

echo "✓ Sparkle.framework installed to Frameworks/"
echo ""
echo "Next steps:"
echo "  1. Generate an EdDSA key pair:"
echo "     ./Frameworks/bin/generate_keys"
echo "  2. Add the public key to Info.plist (SUPublicEDKey)"
echo "  3. Keep the private key safe for signing releases"
