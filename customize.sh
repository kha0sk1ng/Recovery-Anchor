#!/sbin/sh
# RecoveryAnchor - customize.sh
# Runs during installation via KernelSU Manager.

ANCHOR_DIR="/data/adb/recovery-anchor"
CONFIG="$ANCHOR_DIR/config"
DEFAULT_IMG="$ANCHOR_DIR/recovery.img"

ui_print ""
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  RecoveryAnchor v1.0.0"
ui_print "  by kha0sk1ng"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""

mkdir -p "$ANCHOR_DIR"

# Write default config only if it doesn't already exist
if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" << 'CONF'
# RecoveryAnchor config

# Absolute path to your recovery image
RECOVERY_IMG=/data/adb/recovery-anchor/recovery.img

# true  = flash both recovery_a and recovery_b (recommended)
# false = flash only the currently active slot
FLASH_BOTH_SLOTS=true

# Set false to pause flashing without uninstalling the module
ENABLED=true
CONF
    ui_print "  [+] Default config written."
else
    ui_print "  [*] Existing config kept."
fi

# Check if recovery image is already in place
if [ -f "$DEFAULT_IMG" ]; then
    size_bytes=$(wc -c < "$DEFAULT_IMG" 2>/dev/null | tr -d ' ')
    size_mb=$(( ${size_bytes:-0} / 1048576 ))
    ui_print "  [+] Recovery image found (${size_mb} MB) — ready."
else
    ui_print ""
    ui_print "  [!] No recovery image found."
    ui_print "      Copy your .img to:"
    ui_print "      $DEFAULT_IMG"
    ui_print "      Then reboot to activate."
    ui_print ""
fi

chmod 755 "$MODDIR/service.sh"

ui_print "  [+] Done."
ui_print ""
