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

[ -f "$CONFIG" ] && . "$CONFIG"

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
    img_hash=$(dd if="$RECOVERY_IMG" bs=4096 count=$CHECK_BLOCKS 2>/dev/null | md5sum | cut -d' ' -f1)
    part_hash=$(dd if="$part"         bs=4096 count=$CHECK_BLOCKS 2>/dev/null | md5sum | cut -d' ' -f1)

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

if [ "$FLASH_BOTH_SLOTS" = "true" ]; then
    flash_slot "_a"
    flash_slot "_b"
else
    flash_slot "$active_slot"
fi

log INFO "Done."
log_raw ""
