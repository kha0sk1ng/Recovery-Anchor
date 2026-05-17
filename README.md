<div align="center">

# ⚓ RecoveryAnchor

**Automatically reflashes your custom recovery after every OTA update.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![KernelSU](https://img.shields.io/badge/KernelSU-supported-green?logo=linux)](https://kernelsu.org)
[![KernelSU Next](https://img.shields.io/badge/KernelSU_Next-supported-brightgreen?logo=linux)](https://github.com/rifsxd/KernelSU-Next)
[![Magisk](https://img.shields.io/badge/Magisk-supported-orange)](https://github.com/topjohnwu/Magisk)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](service.sh)
[![Version](https://img.shields.io/badge/version-v1.1.0-blueviolet)](module.prop)

</div>

---

## 🚀 About

Every Android OTA update rewrites the boot chain — and with it, your custom recovery partition. After a system update, **TWRP**, **OrangeFox**, or any other third-party recovery gets silently replaced by the stock image, locking you out of root tools until you manually reflash.

**RecoveryAnchor** solves this permanently. It runs as a root service on every boot, compares the recovery partition against your stored image, and reflashes only when a mismatch is detected — all before you unlock the screen.

> **No manual intervention required.** Once installed and configured, the module is fully autonomous.

---

## ⚙️ How It Works (Under the Hood)

The core logic lives in **`service.sh`**, which is executed as root on every boot by the KernelSU / Magisk service framework.

### 1. Boot gate

The script polls `sys.boot_completed` before doing anything, then waits an additional 15 seconds to ensure block devices are fully initialised:

```sh
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done
sleep 15
```

### 2. A/B slot detection

The script auto-detects the device topology by probing block device nodes directly — no reliance on build props that can be spoofed or absent:

```sh
# Check for slot-suffixed partitions to determine A/B layout
if [ -b "/dev/block/by-name/recovery_a" ] || [ -b "/dev/block/by-name/recovery_b" ]; then
    AB_DEVICE=true
fi
```

- **A/B devices** — flashes `recovery_a` and/or `recovery_b` depending on `FLASH_BOTH_SLOTS`.
- **Non-A/B (legacy) devices** — automatically ignores `FLASH_BOTH_SLOTS` and targets the single `recovery` partition.

### 3. Hash-based change detection

Rather than flashing unconditionally, the script computes a **SHA-256** digest over the first **4 MB** (1024 × 4096-byte blocks) of both the stored image and the live partition, then compares them:

```sh
CHECK_BLOCKS=1024  # 1024 × 4096 B = 4 MB

# Read first 4 MB from the image file
img_hash=$(dd if="$RECOVERY_IMG" bs=4096 count=$CHECK_BLOCKS 2>/dev/null | sha256sum | cut -d' ' -f1)

# Read first 4 MB from the block device
part_hash=$(dd if="$part" bs=4096 count=$CHECK_BLOCKS 2>/dev/null | sha256sum | cut -d' ' -f1)
```

Checking 4 MB is both fast and reliable — the Android boot image header, kernel, and ramdisk header all reside in the first pages, so any meaningful difference between stock and custom recovery is detected immediately.

If the hashes match, the slot is skipped entirely: **zero writes, zero wear on the partition**.

### 4. Pre-flash backup with integrity verification

If a mismatch is found, the existing partition is backed up **before** any write occurs. The backup is then verified with a second SHA-256 pass. If the hashes disagree (I/O error, unstable block device), the corrupted backup is deleted and the flash is **aborted** to prevent data loss:

```sh
# Dump the current recovery partition to a timestamped file
dd if="$part" of="$backup_file" bs=4096 2>/dev/null
sync

# Cross-verify: re-read partition and compare against the written backup
src_sha=$(dd if="$part" bs=4096 2>/dev/null | sha256sum | cut -d' ' -f1)
bak_sha=$(sha256sum "$backup_file" 2>/dev/null | cut -d' ' -f1)

if [ "$src_sha" != "$bak_sha" ]; then
    rm -f "$backup_file"
    return 1  # Abort — do not flash over an unverified backup
fi
```

Only the **1 most recent backup per slot** is retained; older files are removed automatically.

### 5. Flash

With a verified backup in place, the image is written to the partition using `dd` with a 4096-byte block size. Flash duration is measured and logged:

```sh
t_start=$(date +%s)
dd if="$RECOVERY_IMG" of="$part" bs=4096 2>/dev/null
sync
elapsed=$(( $(date +%s) - t_start ))
```

### 6. Log rotation

The log file is capped at **100 KB**. On each run, if **`anchor.log`** exceeds that threshold, it is rotated to **`anchor.log.old`** before new entries are appended — keeping storage impact negligible.

---

## 📦 Features

| Feature | Details |
|---|---|
| **Hash-based change detection** | SHA-256 over first 4 MB; skips flash when partition already matches |
| **Pre-flash backup** | Full `dd` dump of the current partition before any write |
| **Backup integrity check** | Cross-verifies backup with SHA-256; aborts if check fails |
| **Dry-run mode** | `ENABLED=check` — logs intent without writing a single byte |
| **A/B slot support** | Independently flashes `recovery_a` and `recovery_b` |
| **Non-A/B support** | Auto-detects legacy single-slot devices; no config needed |
| **Backup rotation** | Keeps only the 1 most recent backup per slot |
| **Log rotation** | Rotates `anchor.log` at 100 KB; preserves one `.old` copy |
| **Zero-config defaults** | Sane defaults written on first install; no editing required |
| **Timing metrics** | Flash duration (seconds) logged per slot |

---

## 🛠️ Compatibility & Prerequisites

- Android device with **KernelSU**, **KernelSU Next**, or **Magisk** installed and active
- Root access granted to the module service (granted automatically by the framework)
- A `recovery.img` built for your exact device and Android version (e.g. TWRP, OrangeFox, LineageOS Recovery)
- `zip` utility on your build host (only required for local builds)

> **A/B devices:** It is strongly recommended to keep `FLASH_BOTH_SLOTS=true`. Android may boot from either slot after an OTA, and leaving one slot with stock recovery will cause it to reappear after the next slot switch.

> **Non-A/B devices:** The `FLASH_BOTH_SLOTS` option is silently ignored. The module always targets the single `recovery` partition.

---

## 📦 Installation

### Via KernelSU / Magisk Manager

1. Download **`RecoveryAnchor.zip`** from the [Releases](https://github.com/kha0sk1ng/Recovery-Anchor/releases) page.
2. Open **KernelSU Manager** or **Magisk**.
3. Navigate to **Modules → Install from storage**.
4. Select `RecoveryAnchor.zip` and complete the installation.
5. Push your recovery image to the device:

```bash
adb push recovery.img /data/adb/recovery-anchor/recovery.img
```

6. Reboot. The module activates on the first boot.

### Via Custom Recovery (TWRP / OrangeFox)

1. Download **`RecoveryAnchor.zip`**.
2. Boot into your custom recovery.
3. Go to **Install → select the zip → Swipe to install**.
4. Push your recovery image as shown above, then reboot normally.

---

## ⚙️ Configuration

The config file is created automatically on first install at:

```
/data/adb/recovery-anchor/config
```

Edit it with any root-capable text editor or via `adb shell`. The file uses plain `key=value` syntax sourced directly by the shell — no special parser, no JSON.

### Parameters

| Key | Default | Description |
|---|---|---|
| `RECOVERY_IMG` | `/data/adb/recovery-anchor/recovery.img` | Absolute path to the recovery image |
| `FLASH_BOTH_SLOTS` | `true` | Flash both A/B slots (`true`) or active slot only (`false`) |
| `ENABLED` | `true` | Master switch: `true`, `false`, or `check` (dry-run) |

#### `ENABLED` modes

| Value | Behaviour |
|---|---|
| `true` | Normal operation — flash when hashes differ |
| `false` | Module is installed but completely inactive; exits immediately |
| `check` | **Dry-run** — compares hashes and logs intent, but performs no `dd` writes |

#### Example config

```sh
# Absolute path to the recovery image to flash
RECOVERY_IMG=/data/adb/recovery-anchor/recovery.img

# true  = flash both recovery_a and recovery_b (recommended for A/B devices)
# false = flash only the currently active slot
FLASH_BOTH_SLOTS=true

# true  = normal flash mode
# check = dry-run: log what would happen, skip actual writes
# false = disabled, exit immediately
ENABLED=true
```

To apply changes, simply **reboot** — the config is sourced fresh on every run.

---

## 🛠️ Logs & Troubleshooting

Runtime logs are written to:

```
/data/adb/recovery-anchor/anchor.log
```

Previous log (after rotation) is kept at:

```
/data/adb/recovery-anchor/anchor.log.old
```

### Reading logs via ADB

```bash
adb shell su -c "cat /data/adb/recovery-anchor/anchor.log"
```

### Log format

Each line follows the pattern:

```
[YYYY-MM-DD HH:MM:SS] [LEVEL] message
```

**Log levels used:**

| Level | Meaning |
|---|---|
| `INFO` | General status (device info, mode, image size) |
| `OK` | Slot already matches — no flash performed |
| `FLASH` | Hash mismatch detected; flash initiated |
| `BACKUP` | Backup operation status |
| `DRYRUN` | Would-flash message in `check` mode |
| `SKIP` | Partition block device not found |
| `ERROR` | Fatal condition; flash aborted |

### Common issues

**Recovery image not found**
```
[ERROR] Recovery image not found: /data/adb/recovery-anchor/recovery.img
```
→ Push the image: `adb push recovery.img /data/adb/recovery-anchor/recovery.img`

**Backup integrity check failed**
```
[ERROR] recovery_a — backup integrity check FAILED
```
→ Indicates an I/O error reading the partition. The flash was aborted safely. Check the block device health and retry after reboot.

**Partition not found**
```
[SKIP] recovery_a — partition not found
```
→ The block device `/dev/block/by-name/recovery_a` does not exist. Verify the partition layout matches your device.

---

## 🔨 Building from Source

Requires `bash` and `zip`.

```bash
git clone https://github.com/kha0sk1ng/Recovery-Anchor.git
cd Recovery-Anchor
bash build.sh
```

This produces **`RecoveryAnchor.zip`** in the project root — ready to flash immediately.

The build script excludes `.git` metadata, itself, and any `.zip`, `.img`, or `.log` files from the archive:

```bash
zip -r RecoveryAnchor.zip \
    module.prop service.sh customize.sh META-INF LICENSE \
    --exclude "*.git*" --exclude "build.sh" \
    --exclude "*.zip" --exclude "*.img" --exclude "*.log"
```

---

## ⚠️ Disclaimer

This module writes directly to raw block devices using `dd`. While every precaution is taken (hash verification, pre-flash backup, integrity checks), **incorrect use can result in a soft-brick or bootloop.**

- Always use a `recovery.img` built specifically for your device model and Android version.
- Never flash an image from a different device.
- Verify your setup safely first using **dry-run mode** (`ENABLED=check`).

> **The author and contributors are not responsible for any damage to your device, data loss, or voided warranty resulting from the use of this module. Use at your own risk.**

---

## License

[MIT](LICENSE) © [kha0sk1ng](https://github.com/kha0sk1ng)
