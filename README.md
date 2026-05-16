# RecoveryAnchor

A KernelSU / Magisk module that automatically reflashes a custom recovery image to the recovery partition(s) on every boot — keeping your custom recovery alive after OTA updates.

---

## Table of Contents

- [Description](#description)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Via KernelSU / Magisk Manager](#via-kernelsu--magisk-manager)
  - [Via Custom Recovery (TWRP / OrangeFox)](#via-custom-recovery-twrp--orangefox)
- [Configuration](#configuration)
- [How to Build Locally](#how-to-build-locally)
- [Logs](#logs)
- [License](#license)

---

## Description

After an Android OTA update the system partition is rewritten and your custom recovery is typically replaced with the stock one. **RecoveryAnchor** solves this by running as a root service on every boot and reflashing your saved `recovery.img` back to the partition — before the user even unlocks the screen.

It is designed to be safe: it reads a SHA-256 hash of the first 4 MB of both the current partition and the stored image, and only flashes when they differ. A backup of the existing partition is always created and verified before any write occurs.

---

## Features

| Feature | Details |
|---|---|
| **Hash-based change detection** | Compares SHA-256 of image vs partition; skips flash when already up to date |
| **Partition backup** | Backs up the current recovery partition before every flash |
| **Backup integrity check** | Verifies backup with SHA-256; aborts flash if check fails to prevent bricking |
| **Dry-run mode** | `ENABLED=check` — logs what *would* happen without writing anything |
| **A/B slot support** | Flashes `recovery_a` and `recovery_b` independently |
| **Non-A/B support** | Auto-detects legacy single-slot devices and uses the `recovery` partition |
| **Log rotation** | Rotates `anchor.log` at 100 KB; keeps one `.old` copy |
| **Configurable** | Simple key=value config file; no editing of module files required |

---

## Prerequisites

- Android device with **KernelSU**, **KernelSU Next**, or **Magisk** installed
- Root access granted to the module service
- A `recovery.img` file built for your device (e.g. TWRP, OrangeFox, LineageOS recovery)
- `zip` available on your build machine (only needed for local builds)

---

## Installation

### Via KernelSU / Magisk Manager

1. Download `RecoveryAnchor.zip` from the [Releases](https://github.com/kha0sk1ng/Recovery-Anchor/releases) page.
2. Open **KernelSU Manager** or **Magisk Manager**.
3. Go to **Modules** → **Install from storage**.
4. Select `RecoveryAnchor.zip` and follow the on-screen prompts.
5. Copy your custom recovery image to the device:
   ```
   adb push recovery.img /data/adb/recovery-anchor/recovery.img
   ```
6. Reboot. The module activates on the next boot.

### Via Custom Recovery (TWRP / OrangeFox)

1. Download `RecoveryAnchor.zip`.
2. Boot into your custom recovery.
3. Go to **Install** → select the zip → **Swipe to install**.
4. Copy your `recovery.img` as described above, then reboot.

---

## Configuration

The config file is located at:

```
/data/adb/recovery-anchor/config
```

A default config is written on first install. Edit it with any root-capable text editor or via `adb shell`.

### Options

| Key | Default | Description |
|---|---|---|
| `RECOVERY_IMG` | `/data/adb/recovery-anchor/recovery.img` | Absolute path to the recovery image to flash |
| `FLASH_BOTH_SLOTS` | `true` | Controls slot flashing behaviour on A/B devices (see below) |
| `ENABLED` | `true` | Master switch (see below) |

#### `FLASH_BOTH_SLOTS`

- `true` — Flash both `recovery_a` **and** `recovery_b` on every boot *(recommended for A/B devices)*.
- `false` — Flash only the currently active slot.
- Ignored on non-A/B (legacy) devices; the single `recovery` partition is always used.

#### `ENABLED`

- `true` — Normal operation; flash recovery when hashes differ.
- `false` — Module is installed but completely inactive. No hashing, no flashing.
- `check` — **Dry-run mode.** The script compares hashes and logs what *would* be flashed, but no `dd` write is performed. Useful for testing your setup safely.

#### Example config

```sh
RECOVERY_IMG=/data/adb/recovery-anchor/recovery.img
FLASH_BOTH_SLOTS=true
ENABLED=true
```

---

## How to Build Locally

Requires `bash` and `zip`.

```bash
git clone https://github.com/kha0sk1ng/Recovery-Anchor.git
cd Recovery-Anchor
bash build.sh
```

This produces `RecoveryAnchor.zip` in the project root, ready to flash.

The script automatically excludes `.git` metadata, itself (`build.sh`), and any `.zip`, `.img`, or `.log` files from the archive.

---

## Logs

Runtime logs are written to:

```
/data/adb/recovery-anchor/anchor.log
```

The log rotates automatically when it exceeds 100 KB; the previous log is kept as `anchor.log.old`.

To view logs over ADB:

```bash
adb shell "cat /data/adb/recovery-anchor/anchor.log"
```

---

## License

[MIT](LICENSE) © kha0sk1ng
