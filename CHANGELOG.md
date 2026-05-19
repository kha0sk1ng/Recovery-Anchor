# Changelog

All notable changes to RecoveryAnchor are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [v1.3.1] - 2026-05-19

### Changed

- **A/B detection in installer** — `customize.sh` now uses `getprop ro.boot.slot_suffix` instead of probing block devices, which are not guaranteed to be available during installation.
- **Backup: single partition read** — `service.sh` now reads the recovery partition once via `tee` to write the backup and compute SHA-256 simultaneously, eliminating the redundant second `dd` pass.

### Added

- **Post-flash verification (`VERIFY_AFTER_FLASH`)** — New config option (default `true`). After each successful `dd`, the first 4 MB of the partition is re-read and compared against the source image. Flash is reported as failed if hashes differ.
- **Image SHA-256 logged on every run** — `service.sh` now computes and logs the full SHA-256 of the recovery image at startup, making it easy to confirm which build is installed.
- **Configurable boot delay (`BOOT_DELAY`)** — Replaces the hardcoded `sleep 15` after `sys.boot_completed`. Default: `15`.
- **Configurable backup retention (`MAX_BACKUPS`)** — Max backup files to keep per slot. Default: `1`.
- **Configurable hash check size (`HASH_CHECK_BLOCKS`)** — Number of 4 KB blocks compared for change detection. Default: `1024` (= 4 MB).

### Fixed

- **Duplicate MODDIR fallback** — Removed the redundant second `MODDIR` assignment in `customize.sh` that could never trigger.
- **Trailing blank line in log** — Replaced repeated `log_raw ""` calls before every `exit` with a single `trap _on_exit EXIT` handler.

---

## [v1.3.0] - 2026-05-19

### Changed

- **A/B devices only** — RecoveryAnchor now explicitly targets A/B (slot) devices.
  Non-A/B (legacy single-partition) devices have a fundamentally different OTA mechanism and are out of scope for this module. `service.sh` now exits with an `[ERROR]` log entry instead of attempting to flash a non-existent `recovery` partition.

### Added

- **Installer A/B check** — `customize.sh` now probes for `recovery_a`/`recovery_b` block nodes during installation and prints a visible `[!] WARNING` if the device does not appear to be A/B.
- **Usage After OTA section in README** — Documented the mandatory "Install to Inactive Slot (After OTA)" step required in Magisk/KernelSU before rebooting after an OTA update. Without this step, root is lost on the new slot and the module cannot run.

### Fixed

- Version badge in README was showing `v1.1.0`; corrected to `v1.2.4` (now `v1.3.0`).
- README section order restructured: Quick Start and Features now appear before the internal implementation details.
- Duplicate `📦` emoji used for both "Features" and "Installation" sections — corrected.
- Table of Contents added to README for navigation.

### Removed

- Non-A/B (legacy `recovery` partition) fallback path from `service.sh`. The module no longer silently targets a single-slot device.

---

## [v1.2.4] - 2026-05-17

**Critical Security & Stability Update**

### Security

- **Config execution vulnerability (Critical)** — Removed `source` / `.` of the config file, which allowed arbitrary code injection via `service.sh`. Replaced with a safe `grep`/`cut`-based parser.
- **Partition backup permissions (High)** — Backup files now have permissions locked to `600` immediately after creation.
- **Log file permissions after rotation (Medium)** — New log file after rotation is now explicitly recreated and secured with `chmod 600`.

### Fixed

- `dd` flash command now uses `conv=fsync` instead of a standalone `sync` call — guarantees data is physically committed before `dd` returns, eliminating the I/O race condition.

---

## [v1.1.0] - 2026-05-16

### Added

- **SHA-256 hashing** — Replaced `md5sum` with `sha256sum` for all partition/image comparisons.
- **Partition backup with integrity check** — Before overwriting a recovery partition, the current contents are backed up. A SHA-256 checksum is computed for both source and backup; mismatch aborts the flash. Only the 1 most recent backup per slot is kept.
- **Dry-run mode (`ENABLED=check`)** — Compares hashes and logs intent without writing anything to the partition.
- **`build.sh`** — Local packaging script that produces `RecoveryAnchor.zip`.
- **GitHub Actions release workflow** — Pushing a `v*` tag automatically builds the zip and creates a GitHub Release.
- **`CHANGELOG.md`** and **`.gitignore`**.

### Fixed

- Version string in `META-INF/com/google/android/update-binary` corrected to match `module.prop`.

---

## [v1.0.0] - Initial release

- Basic KernelSU/Magisk module structure.
- Reflashes a custom recovery image to A/B slots on every boot to survive OTA updates.
- Configurable via `/data/adb/recovery-anchor/config`.
- `FLASH_BOTH_SLOTS` and `ENABLED` flags.
- Boot-completion wait before flashing.
- Log rotation at 100 KB.
