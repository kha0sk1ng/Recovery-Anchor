#!/system/bin/sh
# RecoveryAnchor - service.sh
# Runs as root on every boot via KernelSU.

ANCHOR_DIR="/data/adb/recovery-anchor"
CONFIG="$ANCHOR_DIR/config"
LOG="$ANCHOR_DIR/anchor.log"
MAX_LOG_BYTES=102400  # 100 KB

# ── Logging ───────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# Rotate log when oversized
if [ -f "$LOG" ]; then
    log_size=$(wc -c < "$LOG" 2>/dev/null | tr -d ' ')
    [ "${log_size:-0}" -gt "$MAX_LOG_BYTES" ] && mv "$LOG" "${LOG}.old"
fi

# ── Load config ───────────────────────────────────────────────────────────────
# Defaults
RECOVERY_IMG="$ANCHOR_DIR/recovery.img"
FLASH_BOTH_SLOTS="true"
ENABLED="true"

[ -f "$CONFIG" ] && . "$CONFIG"

# ── Guards ────────────────────────────────────────────────────────────────────

if [ "$ENABLED" != "true" ]; then
    log "[SKIP] Disabled via config."
    exit 0
fi

if [ ! -f "$RECOVERY_IMG" ]; then
    log "[ERROR] Recovery image not found: $RECOVERY_IMG"
    exit 1
fi

# ── Wait for boot ─────────────────────────────────────────────────────────────

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done
sleep 15  # Extra margin for storage to fully settle

log "[START] Boot run — mode: $([ "$FLASH_BOTH_SLOTS" = "true" ] && echo 'both slots' || echo 'active slot only')"

# ── Flash ─────────────────────────────────────────────────────────────────────

# Compare first 4 MB (1024 × 4096 B) of image vs partition.
# Fast enough, reliable enough: any stock vs custom recovery will differ here.
CHECK_BLOCKS=1024

flash_slot() {
    local slot="$1"
    local part="/dev/block/by-name/recovery${slot}"

    # Skip gracefully on non-A/B devices or missing partitions
    if [ ! -b "$part" ]; then
        log "  [SKIP] recovery${slot} — partition not found"
        return 1
    fi

    local img_hash part_hash
    img_hash=$(dd if="$RECOVERY_IMG" bs=4096 count=$CHECK_BLOCKS 2>/dev/null | md5sum | cut -d' ' -f1)
    part_hash=$(dd if="$part"         bs=4096 count=$CHECK_BLOCKS 2>/dev/null | md5sum | cut -d' ' -f1)

    if [ "$img_hash" = "$part_hash" ]; then
        log "  [OK] recovery${slot} matches image — skip"
        return 0
    fi

    log "  [FLASH] recovery${slot} mismatch detected, flashing..."
    if dd if="$RECOVERY_IMG" of="$part" bs=4096 2>/dev/null; then
        sync
        log "  [OK] recovery${slot} flashed"
    else
        log "  [ERROR] recovery${slot} flash failed"
        return 1
    fi
}

active_slot="$(getprop ro.boot.slot_suffix)"

if [ "$FLASH_BOTH_SLOTS" = "true" ]; then
    flash_slot "_a"
    flash_slot "_b"
else
    flash_slot "$active_slot"
fi

log "[DONE]"
