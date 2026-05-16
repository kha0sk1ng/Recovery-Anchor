# Changelog

All notable changes to RecoveryAnchor are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [v1.1.0] - 2026-05-16

### Added

- **SHA-256 hashing** — Replaced `md5sum` with `sha256sum` for all partition/image comparisons. More secure and standard on modern Android toybox.
- **Partition backup with integrity check** — Before overwriting a recovery partition, the current contents are backed up to `$ANCHOR_DIR/recovery_backup_<slot>_<timestamp>.img`. A SHA-256 checksum is computed for both the source partition and the new backup file. If they do not match the corrupted backup is deleted and the flash is aborted to prevent bricking. Only the 1 most recent valid backup per slot is kept; older backups are pruned automatically.
- **Dry-run mode (`ENABLED=check`)** — Setting `ENABLED=check` in the config causes the script to compare hashes and log what *would* be flashed without writing anything to the partition. Useful for verifying the module is working correctly before enabling live flashing.
- **Non-A/B device support** — The script now detects whether `recovery_a`/`recovery_b` exist in `/dev/block/by-name/`. If they do not, it falls back to the legacy `recovery` partition. `FLASH_BOTH_SLOTS` is ignored gracefully on single-slot devices.
- **`build.sh`** — Local packaging script that zips all module files into `RecoveryAnchor.zip`, ready to flash via custom recovery or root manager.
- **GitHub Actions release workflow** — Pushing a `v*` tag automatically builds the zip and creates a GitHub Release with the artifact attached.
- **`CHANGELOG.md`** — This file.
- **`.gitignore`** — Ignores build artifacts (`.zip`, `.img`), log files, and IDE folders.

### Fixed

- Version string in `META-INF/com/google/android/update-binary` was `v1.0.0`; updated to `v1.1.0` to match `module.prop`.

---

## [v1.0.0] - Initial release

- Basic KernelSU/Magisk module structure.
- Reflashes a custom recovery image to A/B slots on every boot to survive OTA updates.
- Configurable via `/data/adb/recovery-anchor/config`.
- `FLASH_BOTH_SLOTS` and `ENABLED` flags.
- Boot-completion wait before flashing.
- Log rotation at 100 KB.
