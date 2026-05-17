#!/system/bin/sh
# RecoveryAnchor v1.1.0
# https://github.com/kha0sk1ng/Recovery-Anchor/
# Runs as root on every boot via KernelSU.

ANCHOR_DIR="/data/adb/recovery-anchor"
CONFIG="$ANCHOR_DIR/config"
LOG="$ANCHOR_DIR/anchor.log"
MAX_LOG_BYTES=102400  # 100 KB

VERSION="v1.1.0"
REPO="https://github.com/kha0sk1ng/Recovery-Anchor/"

# ── Logging ───────────────────────────────────────────────────────────────────

log() {
    local level="$1"
    shift
    printf '[%s] [%-5s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >> "$LOG"
}

log_raw() {
    printf '%s\n' "$*" >> "$LOG"
}

# Rotate when oversized: keep last run in .old
if [ -f "$LOG" ]; then
    log_size=$(wc -c < "$LOG" 2>/dev/null | tr -d ' ')
    [ "${log_size:-0}" -gt "$MAX_LOG_BYTES" ] && mv "$LOG" "${LOG}.old"
fi

# ── Load config ───────────────────────────────────────────────────────────────
RECOVERY_IMG="$ANCHOR_DIR/recovery.img"
FLASH_BOTH_SLOTS="true"
ENABLED="true"

if [ -f "$CONFIG" ]; then
    cfg_val=$(grep -E '^[[:space:]]*RECOVERY_IMG=' "$CONFIG" | tail -1 | cut -d= -f2-)
    [ -n "$cfg_val" ] && RECOVERY_IMG="$cfg_val"

    cfg_val=$(grep -E '^[[:space:]]*FLASH_BOTH_SLOTS=' "$CONFIG" | tail -1 | cut -d= -f2-)
    [ -n "$cfg_val" ] && FLASH_BOTH_SLOTS="$cfg_val"

    cfg_val=$(grep -E '^[[:space:]]*ENABLED=' "$CONFIG" | tail -1 | cut -d= -f2-)
    [ -n "$cfg_val" ] && ENABLED="$cfg_val"
fi

# ── Header ────────────────────────────────────────────────────────────────────

log_raw ""
log_raw "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_raw "  RecoveryAnchor ${VERSION}  |  $(date '+%Y-%m-%d %H:%M:%S')"
log_raw "  ${REPO}"
log_raw "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Guard: disabled / dry-run via config ─────────────────────────────────────
# ENABLED=true  -> normal flash mode
# ENABLED=check -> dry-run: compare hashes and log intent, skip actual dd
# ENABLED=false -> disabled, exit immediately

if [ "$ENABLED" = "false" ]; then
    log INFO "Disabled via config (ENABLED=false) — exiting."
    log_raw ""
    exit 0
fi

if [ "$ENABLED" = "check" ]; then
    log INFO "Mode: DRY-RUN (ENABLED=check) — no partition writes will occur."
fi

# ── Wait for boot ─────────────────────────────────────────────────────────────

log INFO "Waiting for sys.boot_completed..."
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done
sleep 15

# ── Device info ───────────────────────────────────────────────────────────────

device_model="$(getprop ro.product.model 2>/dev/null)"
device_codename="$(getprop ro.product.device 2>/dev/null)"
active_slot="$(getprop ro.boot.slot_suffix)"
android_ver="$(getprop ro.build.version.release 2>/dev/null)"

log INFO "Device  : ${device_model} (${device_codename})"
log INFO "Android : ${android_ver}"
log INFO "Slot    : ${active_slot}"

# ── Guard: image exists ───────────────────────────────────────────────────────

if [ ! -f "$RECOVERY_IMG" ]; then
    log ERROR "Recovery image not found: $RECOVERY_IMG"
    log ERROR "Copy your .img there and reboot."
    log_raw ""
    exit 1
fi

# Log image size
img_bytes=$(wc -c < "$RECOVERY_IMG" 2>/dev/null | tr -d ' ')
img_mb=$(( ${img_bytes:-0} / 1048576 ))
log INFO "Image   : $RECOVERY_IMG (${img_mb} MB)"

# ── Flash mode ────────────────────────────────────────────────────────────────

if [ "$FLASH_BOTH_SLOTS" = "true" ]; then
    log INFO "Mode    : both slots"
else
    log INFO "Mode    : active slot only (${active_slot})"
fi

# ── Flash function ────────────────────────────────────────────────────────────
# Compares first 4 MB of image vs partition (fast + reliable).
# Stock and custom recovery always differ in the first pages (header, ramdisk).

CHECK_BLOCKS=1024  # 1024 × 4096 B = 4 MB

flash_slot() {
    local slot="$1"
    local part="/dev/block/by-name/recovery${slot}"

    if [ ! -b "$part" ]; then
        log SKIP "recovery${slot} — partition not found"
        return 1
    fi

    local img_hash part_hash
    img_hash=$(dd if="$RECOVERY_IMG" bs=4096 count=$CHECK_BLOCKS 2>/dev/null | sha256sum | cut -d' ' -f1)
    part_hash=$(dd if="$part"         bs=4096 count=$CHECK_BLOCKS 2>/dev/null | sha256sum | cut -d' ' -f1)

    if [ "$img_hash" = "$part_hash" ]; then
        log OK   "recovery${slot} — matches image, no flash needed"
        return 0
    fi

    log FLASH "recovery${slot} — mismatch (partition: ${part_hash:0:8}… / image: ${img_hash:0:8}…)"

    # Dry-run: log intent and skip the actual write
    if [ "$ENABLED" = "check" ]; then
        log DRYRUN "recovery${slot} — would flash ${img_mb} MB (dry-run, no write performed)"
        return 0
    fi

    # ── Backup current partition before overwriting ────────────────────────────
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    # Slot suffix (_a, _b) or empty string for non-A/B; strip leading underscore for filename
    local slot_label
    slot_label=$(printf '%s' "$slot" | sed 's/^_//')
    [ -z "$slot_label" ] && slot_label="noab"
    local backup_file="$ANCHOR_DIR/recovery_backup_${slot_label}_${ts}.img"

    log BACKUP "recovery${slot} — creating backup: $backup_file"
    if ! dd if="$part" of="$backup_file" bs=4096 2>/dev/null; then
        log ERROR "recovery${slot} — backup dd failed; aborting flash to prevent data loss"
        rm -f "$backup_file"
        return 1
    fi
    sync

    # Integrity check: compare sha256 of partition source vs backup file
    local src_sha bak_sha
    src_sha=$(dd if="$part" bs=4096 2>/dev/null | sha256sum | cut -d' ' -f1)
    bak_sha=$(sha256sum "$backup_file" 2>/dev/null | cut -d' ' -f1)

    if [ "$src_sha" != "$bak_sha" ]; then
        log ERROR "recovery${slot} — backup integrity check FAILED (src: ${src_sha:0:16}… / bak: ${bak_sha:0:16}…)"
        log ERROR "recovery${slot} — corrupted backup deleted; aborting flash"
        rm -f "$backup_file"
        return 1
    fi

    log BACKUP "recovery${slot} — backup verified OK (sha256: ${bak_sha:0:16}…)"

    # Keep only the 1 most recent backup per slot; delete older ones
    local old_backups
    old_backups=$(ls -t "$ANCHOR_DIR/recovery_backup_${slot_label}_"*.img 2>/dev/null | tail -n +2)
    if [ -n "$old_backups" ]; then
        printf '%s\n' "$old_backups" | while IFS= read -r f; do
            log BACKUP "recovery${slot} — removing old backup: $f"
            rm -f "$f"
        done
    fi

    # ── Flash ─────────────────────────────────────────────────────────────────
    log FLASH "recovery${slot} — flashing ${img_mb} MB..."

    local t_start t_end elapsed
    t_start=$(date +%s)

    if dd if="$RECOVERY_IMG" of="$part" bs=4096 2>/dev/null; then
        sync
        t_end=$(date +%s)
        elapsed=$(( t_end - t_start ))
        log OK   "recovery${slot} — done in ${elapsed}s"
    else
        log ERROR "recovery${slot} — dd failed"
        return 1
    fi
}

# ── Run ───────────────────────────────────────────────────────────────────────
# Detect whether this is an A/B device by checking for slot-suffixed partitions.
# Fall back to the legacy "recovery" partition on non-A/B (single-slot) devices.

AB_DEVICE=false
if [ -b "/dev/block/by-name/recovery_a" ] || [ -b "/dev/block/by-name/recovery_b" ]; then
    AB_DEVICE=true
fi

if [ "$AB_DEVICE" = "true" ]; then
    if [ "$FLASH_BOTH_SLOTS" = "true" ]; then
        log INFO "A/B device — flashing both slots"
        flash_slot "_a"
        flash_slot "_b"
    else
        log INFO "A/B device — flashing active slot only (${active_slot})"
        flash_slot "$active_slot"
    fi
else
    # Non-A/B (legacy single-slot) device: ignore FLASH_BOTH_SLOTS, use "recovery"
    log INFO "Non-A/B device — flashing legacy recovery partition"
    flash_slot ""
fi

log INFO "Done."
log_raw ""
