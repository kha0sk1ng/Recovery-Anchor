#!/usr/bin/env bash
# build.sh — Local build script for RecoveryAnchor
# Packages the module into a ready-to-flash zip.
# Usage: bash build.sh

set -e

OUTPUT="RecoveryAnchor.zip"
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

echo "[+] Done: $OUTPUT ($(du -sh "$OUTPUT" | cut -f1))"
