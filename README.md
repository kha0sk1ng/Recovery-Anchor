<div align="center">

# ⚓ RecoveryAnchor

**Automatically reflashes your custom recovery after every OTA update — on A/B devices.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![KernelSU](https://img.shields.io/badge/KernelSU-supported-green?logo=linux)](https://kernelsu.org)
[![KernelSU Next](https://img.shields.io/badge/KernelSU_Next-supported-brightgreen?logo=linux)](https://github.com/rifsxd/KernelSU-Next)
[![Magisk](https://img.shields.io/badge/Magisk-supported-orange)](https://github.com/topjohnwu/Magisk)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](service.sh)
[![Release](https://img.shields.io/github/v/release/kha0sk1ng/Recovery-Anchor?display_name=tag&color=blueviolet)](https://github.com/kha0sk1ng/Recovery-Anchor/releases)

</div>

---

## 📋 Table of Contents

- [About](#-about)
- [Quick Start](#-quick-start)
- [Features](#-features)
- [Compatibility](#️-compatibility)
- [Installation](#-installation)
- [Usage After OTA Update](#-usage-after-ota-update)
- [Configuration](#️-configuration)
- [Logs & Troubleshooting](#-logs--troubleshooting)
- [How It Works](#️-how-it-works-under-the-hood)
- [Building from Source](#-building-from-source)
- [Disclaimer](#️-disclaimer)
- [License](#license)

---

## 🔍 About

Every Android OTA update rewrites the inactive boot slot — and with it, your custom recovery partition. After a system update, **TWRP**, **OrangeFox**, or any other third-party recovery gets silently replaced by the stock image.

**RecoveryAnchor** solves this automatically. It runs as a root service on every boot, compares the recovery partition against your stored image using SHA-256, and reflashes only when a mismatch is detected — before you even unlock the screen.

> **This module is designed for A/B (slot) devices only.**
> A-only devices have a different partition layout and OTA mechanism — this module is not compatible with them.

---

## ⚡ Quick Start

1. Download the latest `RecoveryAnchor-<version>.zip` from [Releases](https://github.com/kha0sk1ng/Recovery-Anchor/releases).
2. Install via **KernelSU / Magisk → Modules → Install from storage**.
3. Push your recovery image:
   ```bash
   adb push recovery.img /data/adb/recovery-anchor/recovery.img
   ```
4. Reboot. The module is now active.

> **Before rebooting after an OTA update — read the [Usage After OTA Update](#-usage-after-ota-update) section first.**
> Skipping that step will cause you to lose root access on the new slot.

---

## 📦 Features

| Feature | Details |
|---|---|
| **A/B slot support** | Independently flashes `recovery_a` and `recovery_b` |
| **Hash-based change detection** | SHA-256 over first 4 MB — skips flash when partition already matches |
| **Pre-flash backup** | Full `dd` dump of the current partition before any write |
| **Backup integrity check** | Cross-verifies backup with SHA-256; aborts flash if check fails |
| **Dry-run mode** | `ENABLED=check` — logs intent without writing a single byte |
| **Backup rotation** | Keeps only the newest N backups per slot (`MAX_BACKUPS`, default: 1) |
| **Log rotation** | Rotates `anchor.log` at 100 KB; preserves one `.old` copy |
| **Post-flash verification** | Optional `VERIFY_AFTER_FLASH=true` re-check after every write |
| **Configurable timing & hash window** | `BOOT_DELAY` and `HASH_CHECK_BLOCKS` tune boot wait and compare size |
| **Zero-config defaults** | Sane defaults written on first install; no editing required |
| **Timing metrics** | Flash duration logged per slot |

---

## ⚙️ Compatibility

**Required:**
- Android A/B (slot) device
- **KernelSU**, **KernelSU Next**, or **Magisk** installed and active
- A `recovery.img` built specifically for your device model and Android version (TWRP, OrangeFox, etc.)

**Not supported:**
- A-only (legacy single-partition) devices

> Not sure if your device is A/B? Run `getprop ro.boot.slot_suffix` in a root shell. If it returns `_a` or `_b` — you have an A/B device.

---

## 📲 Installation

### Via KernelSU / Magisk Manager

1. Download the latest **`RecoveryAnchor-<version>.zip`** from the [Releases](https://github.com/kha0sk1ng/Recovery-Anchor/releases) page.
2. Open **KernelSU Manager** or **Magisk**.
3. Navigate to **Modules → Install from storage**.
4. Select the downloaded `RecoveryAnchor-<version>.zip` and complete the installation.
5. Push your recovery image to the device:
   ```bash
   adb push recovery.img /data/adb/recovery-anchor/recovery.img
   ```
6. Reboot. The module activates on the first boot.

### Via Custom Recovery (TWRP / OrangeFox)

1. Download the latest **`RecoveryAnchor-<version>.zip`**.
2. Boot into your custom recovery.
3. Go to **Install → select the zip → Swipe to install**.
4. Push your recovery image as shown above, then reboot normally.

---

## 🔄 Usage After OTA Update

This is the most important section for day-to-day use.

On A/B devices, an OTA update installs the new system image onto the **inactive slot** (e.g. if you're on `slot_a`, the OTA writes to `slot_b`). That new slot has a **clean, unpatched boot image** — meaning no root, no modules, and no RecoveryAnchor.

If you reboot immediately after the OTA without patching the new slot, you will boot into an unrooted system. RecoveryAnchor will not run, and the stock recovery will remain permanently on that slot.

### Correct procedure every time an OTA arrives:

> **⚠️ Do NOT reboot when the system prompts you after an OTA. Follow these steps first.**

1. OTA finishes downloading and applying.
2. **Before rebooting** — open **Magisk** or **KernelSU**.
3. Tap **"Install to Inactive Slot (After OTA)"** (Magisk) or the equivalent option in KernelSU.
4. Wait for it to finish patching the boot image on the inactive slot.
5. Now reboot.

**What happens after the reboot:**

- You boot into the updated slot with root preserved.
- All modules are active, including RecoveryAnchor.
- RecoveryAnchor detects that the recovery partition was replaced by the OTA.
- It automatically reflashes your custom recovery image on both slots.
- Done — no manual recovery reflash needed.

### Why both slots?

After an OTA, the recovery is replaced on both `recovery_a` and `recovery_b`. RecoveryAnchor with `FLASH_BOTH_SLOTS=true` (default) fixes both in one boot. This ensures that whichever slot Android switches to next, your custom recovery is already there.

---

## ⚙️ Configuration

The config file is created automatically on first install at:

```
/data/adb/recovery-anchor/config
```

Edit it with any root-capable text editor or via `adb shell`. The file uses plain `key=value` syntax and is parsed safely line-by-line — no shell `source`, no JSON.

### Parameters

| Key | Default | Description |
|---|---|---|
| `RECOVERY_IMG` | `/data/adb/recovery-anchor/recovery.img` | Absolute path to the recovery image |
| `FLASH_BOTH_SLOTS` | `true` | Flash both A/B slots (`true`) or active slot only (`false`) |
| `ENABLED` | `true` | Master switch: `true`, `false`, or `check` (dry-run) |
| `VERIFY_AFTER_FLASH` | `true` | Verify partition hash after each flash |
| `BOOT_DELAY` | `15` | Seconds to wait after `sys.boot_completed` |
| `MAX_BACKUPS` | `1` | Max backup images to keep per slot |
| `HASH_CHECK_BLOCKS` | `1024` | Number of 4 KB blocks hashed for compare/verify (1024 = 4 MB) |

#### `ENABLED` modes

| Value | Behaviour |
|---|---|
| `true` | Normal operation — flash when hashes differ |
| `false` | Module installed but completely inactive; exits immediately |
| `check` | **Dry-run** — compares hashes and logs intent, but performs no writes |

#### Example config

```sh
# Absolute path to the recovery image to flash
RECOVERY_IMG=/data/adb/recovery-anchor/recovery.img

# true  = flash both recovery_a and recovery_b (recommended)
# false = flash only the currently active slot
FLASH_BOTH_SLOTS=true

# true  = normal flash mode
# check = dry-run: log what would happen, skip actual writes
# false = disabled, exit immediately
ENABLED=true

# Verify partition matches image after each flash
VERIFY_AFTER_FLASH=true

# Seconds to wait after boot completion
BOOT_DELAY=15

# Keep only the newest backup per slot
MAX_BACKUPS=1

# Compare first 1024 * 4 KB = 4 MB
HASH_CHECK_BLOCKS=1024
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

```
[YYYY-MM-DD HH:MM:SS] [LEVEL] message
```

| Level | Meaning |
|---|---|
| `INFO` | General status (device info, mode, image size, verify start) |
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
→ I/O error reading the partition. Flash was aborted safely. Check block device health and retry after reboot.

**Partition not found**
```
[SKIP] recovery_a — partition not found
```
→ `/dev/block/by-name/recovery_a` does not exist. Verify the partition layout matches your A/B device.

**Module doesn't run after OTA reboot**
→ You likely rebooted without patching the inactive slot first. Boot into your custom recovery, flash RecoveryAnchor again, then push the recovery image again. Next time follow the [Usage After OTA](#-usage-after-ota-update) steps before rebooting.

---

## 🔩 How It Works (Under the Hood)

The core logic lives in **`service.sh`**, executed as root on every boot by the KernelSU / Magisk service framework.

### 1. Boot gate

Polls `sys.boot_completed`, then waits `BOOT_DELAY` seconds for block devices to fully initialise:

```sh
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done
sleep "$BOOT_DELAY"
```

### 2. A/B slot detection

Probes block device nodes directly — no reliance on build props:

```sh
if [ -b "/dev/block/by-name/recovery_a" ] || [ -b "/dev/block/by-name/recovery_b" ]; then
    AB_DEVICE=true
fi
```

### 3. Hash-based change detection

SHA-256 over the first `HASH_CHECK_BLOCKS` × 4 KB of both the stored image and the live partition:

```sh
CHECK_BLOCKS="$HASH_CHECK_BLOCKS"  # default: 1024 × 4096 B = 4 MB

img_hash=$(dd if="$RECOVERY_IMG" bs=4096 count=$CHECK_BLOCKS 2>/dev/null | sha256sum | cut -d' ' -f1)
part_hash=$(dd if="$part" bs=4096 count=$CHECK_BLOCKS 2>/dev/null | sha256sum | cut -d' ' -f1)
```

If hashes match — slot is skipped entirely. Zero writes, zero partition wear.

### 4. Pre-flash backup with integrity verification

Partition is backed up before any write. The partition is read once, piped through `tee` into the backup file, and hashed on the fly. Then the saved backup file is hashed again to confirm integrity. If hashes disagree, the corrupted backup is deleted and the flash is aborted:

```sh
src_sha=$(dd if="$part" bs=4096 2>/dev/null | tee "$backup_file" | sha256sum | cut -d' ' -f1)
chmod 600 "$backup_file"
bak_sha=$(sha256sum "$backup_file" 2>/dev/null | cut -d' ' -f1)

if [ "$src_sha" != "$bak_sha" ]; then
    rm -f "$backup_file"
    return 1  # Abort
fi
```

Only the 1 most recent backup per slot is retained.

### 5. Flash

```sh
t_start=$(date +%s)
dd if="$RECOVERY_IMG" of="$part" bs=4096 conv=fsync 2>/dev/null
elapsed=$(( $(date +%s) - t_start ))
```

### 6. Log rotation

Log is capped at 100 KB. When exceeded, rotated to `anchor.log.old` before new entries are appended.

---

## 🔨 Building from Source

Requires `bash` and `zip`.

```bash
git clone https://github.com/kha0sk1ng/Recovery-Anchor.git
cd Recovery-Anchor
bash build.sh
```

Produces **`RecoveryAnchor-<version>.zip`** in the project root — ready to flash immediately.

---

## ⚠️ Disclaimer

This module writes directly to raw block devices using `dd`. While every precaution is taken (hash verification, pre-flash backup, integrity checks), **incorrect use can result in a soft-brick or bootloop.**

- Always use a `recovery.img` built specifically for your device model and Android version.
- Never flash an image from a different device.
- Verify your setup safely first using **dry-run mode** (`ENABLED=check`).
- Always follow the [Usage After OTA](#-usage-after-ota-update) procedure to keep root active on the new slot.

> **The author and contributors are not responsible for any damage to your device, data loss, or voided warranty resulting from the use of this module. Use at your own risk.**

---

## License

[MIT](LICENSE) © [kha0sk1ng](https://github.com/kha0sk1ng)
