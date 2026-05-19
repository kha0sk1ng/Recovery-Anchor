#!/system/bin/sh
# RecoveryAnchor v1.3.1
# https://github.com/kha0sk1ng/Recovery-Anchor/
# Runs as root on every boot via KernelSU.

ANCHOR_DIR="/data/adb/recovery-anchor"
CONFIG="$ANCHOR_DIR/config"
LOG="$ANCHOR_DIR/anchor.log"
MAX_LOG_BYTES=102400  # 100 KB

VERSION="v1.3.1"
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
    if [ "${log_size:-0}" -gt "$MAX_LOG_BYTES" ]; then
        mv "$LOG" "${LOG}.old"
        touch "$LOG"
        chmod 600 "$LOG"
    fi
fi

# ── Load config ───────────────────────────────────────────────────────────────
RECOVERY_IMG="$ANCHOR_DIR/recovery.img"
FLASH_BOTH_SLOTS="true"
ENABLED="true"
VERIFY_AFTER_FLASH="true"
BOOT_DELAY="15"
MAX_BACKUPS="1"
HASH_CHECK_BLOCKS="1024"

if [ -f "$CONFIG" ]; then
    cfg_val=$(grep -E '^[[:space:]]*RECOVERY_IMG=' "$CONFIG" | tail -1 | cut -d= -f2-)
    [ -n "$cfg_val" ] && RECOVERY_IMG="$cfg_val"

    cfg_val=$(grep -E '^[[:space:]]*FLASH_BOTH_SLOTS=' "$CONFIG" | tail -1 | cut -d= -f2-)
    [ -n "$cfg_val" ] && FLASH_BOTH_SLOTS="$cfg_val"

    cfg_val=$(grep -E '^[[:space:]]*ENABLED=' "$CONFIG" | tail -1 | cut -d= -f2-)
    [ -n "$cfg_val" ] && ENABLED="$cfg_val"

    cfg_val=$(grep -E '^[[:space:]]*VERIFY_AFTER_FLASH=' "$CONFIG" | tail -1 | cut -d= -f2-)
    [ -n "$cfg_val" ] && VERIFY_AFTER_FLASH="$cfg_val"

    cfg_val=$(grep -E '^[[:space:]]*BOOT_DELAY=' "$CONFIG" | tail -1 | cut -d= -f2-)
    [ -n "$cfg_val" ] && BOOT_DELAY="$cfg_val"

    cfg_val=$(grep -E '^[[:space:]]*MAX_BACKUPS=' "$CONFIG" | tail -1 | cut -d= -f2-)
    [ -n "$cfg_val" ] && MAX_BACKUPS="$cfg_val"

    cfg_val=$(grep -E '^[[:space:]]*HASH_CHECK_BLOCKS=' "$CONFIG" | tail -1 | cut -d= -f2-)
    [ -n "$cfg_val" ] && HASH_CHECK_BLOCKS="$cfg_val"
fi

# ── Cleanup trap ─────────────────────────────────────────────────────────────
_on_exit() { log_raw ""; }
trap _on_exit EXIT

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
sleep "$BOOT_DELAY"

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
    exit 1
fi

# Log image size and sha256
img_bytes=$(wc -c < "$RECOVERY_IMG" 2>/dev/null | tr -d ' ')
img_mb=$(( ${img_bytes:-0} / 1048576 ))
img_sha=$(sha256sum "$RECOVERY_IMG" 2>/dev/null | cut -d' ' -f1)
log INFO "Image   : $RECOVERY_IMG (${img_mb} MB)"
log INFO "SHA256  : ${img_sha}"

# ── Flash mode ────────────────────────────────────────────────────────────────

if [ "$FLASH_BOTH_SLOTS" = "true" ]; then
    log INFO "Mode    : both slots"
else
    log INFO "Mode    : active slot only (${active_slot})"
fi

# ── Flash function ────────────────────────────────────────────────────────────
# Compares first 4 MB of image vs partition (fast + reliable).
# Stock and custom recovery always differ in the first pages (header, ramdisk).

# CHECK_BLOCKS is set from config (HASH_CHECK_BLOCKS, default 1024 = 4 MB)
CHECK_BLOCKS="$HASH_CHECK_BLOCKS"

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
    # Read partition once: pipe through tee to write backup and compute sha256 simultaneously
    local src_sha bak_sha
    src_sha=$(dd if="$part" bs=4096 2>/dev/null | tee "$backup_file" | sha256sum | cut -d' ' -f1)
    sync
    chmod 600 "$backup_file"

    if [ ! -s "$backup_file" ]; then
        log ERROR "recovery${slot} — backup dd failed (empty file); aborting flash"
        rm -f "$backup_file"
        return 1
    fi

    # Verify backup matches what was read from partition
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
    old_backups=$(ls -t "$ANCHOR_DIR/recovery_backup_${slot_label}_"*.img 2>/dev/null | tail -n +$(( MAX_BACKUPS + 1 )))
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

    if dd if="$RECOVERY_IMG" of="$part" bs=4096 conv=fsync 2>/dev/null; then
        t_end=$(date +%s)
        elapsed=$(( t_end - t_start ))
        log OK   "recovery${slot} — done in ${elapsed}s"
    else
        log ERROR "recovery${slot} — dd failed"
        return 1
    fi

    # ── Post-flash verification ────────────────────────────────────────────────
    if [ "$VERIFY_AFTER_FLASH" = "true" ]; then
        log INFO "recovery${slot} — verifying flash..."
        local verify_img verify_part
        verify_img=$(dd if="$RECOVERY_IMG" bs=4096 count=$CHECK_BLOCKS 2>/dev/null | sha256sum | cut -d' ' -f1)
        verify_part=$(dd if="$part"        bs=4096 count=$CHECK_BLOCKS 2>/dev/null | sha256sum | cut -d' ' -f1)
        if [ "$verify_img" = "$verify_part" ]; then
            log OK   "recovery${slot} — post-flash verify OK (${verify_part:0:16}…)"
        else
            log ERROR "recovery${slot} — post-flash verify FAILED (img: ${verify_img:0:16}… / part: ${verify_part:0:16}…)"
            return 1
        fi
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
    log ERROR "Non-A/B device detected — RecoveryAnchor supports A/B (slot) devices only."
    log ERROR "No recovery partitions found at /dev/block/by-name/recovery_a or recovery_b."
    log ERROR "Exiting without any changes."
    exit 1
fi

log INFO "Done."
