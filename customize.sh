#!/sbin/sh
# RecoveryAnchor v1.3.0 — customize.sh
# https://github.com/kha0sk1ng/Recovery-Anchor/
# Runs during installation via KernelSU Manager.

# KernelSU Next may not export MODDIR in all versions — explicit fallback.
# MODID is set by the KSU installer from module.prop.
MODDIR="${MODDIR:-/data/adb/modules_update/${MODID}}"
MODDIR="${MODDIR:-/data/adb/modules_update/recovery-anchor}"

ANCHOR_DIR="/data/adb/recovery-anchor"
CONFIG="$ANCHOR_DIR/config"
DEFAULT_IMG="$ANCHOR_DIR/recovery.img"

ui_print ""
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  RecoveryAnchor v1.3.0"
ui_print "  by kha0sk1ng"
ui_print "  github.com/kha0sk1ng/Recovery-Anchor"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""

mkdir -p "$ANCHOR_DIR"

# ── Config ────────────────────────────────────────────────────────────────────

if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" << 'CONF'
# RecoveryAnchor config
# https://github.com/kha0sk1ng/Recovery-Anchor/

# Absolute path to your recovery image
RECOVERY_IMG=/data/adb/recovery-anchor/recovery.img

# true  = flash both recovery_a and recovery_b (recommended for A/B devices)
# false = flash only the currently active slot
FLASH_BOTH_SLOTS=true

# Set to false to pause flashing without uninstalling the module
ENABLED=true
CONF
    ui_print "  [+] Config created."
else
    ui_print "  [*] Existing config kept."
fi

# ── A/B device check ─────────────────────────────────────────────────────────

if [ -b "/dev/block/by-name/recovery_a" ] || [ -b "/dev/block/by-name/recovery_b" ]; then
    ui_print "  [+] A/B device confirmed."
else
    ui_print ""
    ui_print "  [!] WARNING: This does not appear to be an A/B device."
    ui_print "      RecoveryAnchor is designed for A/B (slot) devices only."
    ui_print "      The module will exit without doing anything on boot."
    ui_print ""
fi

# ── Recovery image check ──────────────────────────────────────────────────────

if [ -f "$DEFAULT_IMG" ]; then
    size_bytes=$(wc -c < "$DEFAULT_IMG" 2>/dev/null | tr -d ' ')
    size_mb=$(( ${size_bytes:-0} / 1048576 ))
    ui_print "  [+] Recovery image found — ${size_mb} MB."
else
    ui_print ""
    ui_print "  [!] No recovery image found."
    ui_print "      Copy your .img to:"
    ui_print "        $DEFAULT_IMG"
    ui_print "      Then reboot to activate."
    ui_print ""
fi

# ── Permissions ───────────────────────────────────────────────────────────────

if [ -n "$MODDIR" ] && [ -f "$MODDIR/service.sh" ]; then
    chmod 755 "$MODDIR/service.sh"
    ui_print "  [+] service.sh — permissions set."
else
    ui_print "  [!] service.sh not found at: $MODDIR/service.sh"
    ui_print "      KSU will set permissions automatically."
fi

ui_print ""
ui_print "  Logs: /data/adb/recovery-anchor/anchor.log"
ui_print ""
ui_print "  [+] Installation complete."
ui_print ""
