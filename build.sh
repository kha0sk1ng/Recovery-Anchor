#!/usr/bin/env bash
# build.sh — Local build script for RecoveryAnchor
# Packages the module into a ready-to-flash zip.
# Usage: bash build.sh

set -e

VERSION=$(grep '^version=' module.prop | cut -d= -f2)
OUTPUT="RecoveryAnchor-${VERSION}.zip"
SCRIPT_NAME="$(basename "$0")"

# Remove any previous build artifact
rm -f "$OUTPUT"

echo "[*] Building $OUTPUT ..."

# Zip only the module files; exclude git metadata, this script, and any zips/imgs/logs
zip -r "$OUTPUT" \
    module.prop \
    service.sh \
    customize.sh \
    META-INF \
    LICENSE \
    --exclude "*.git*" \
    --exclude "$SCRIPT_NAME" \
    --exclude "*.zip" \
    --exclude "*.img" \
    --exclude "*.log"

echo "[+] Done: $OUTPUT ($(ls -lh "$OUTPUT" | awk '{print $5}'))"
