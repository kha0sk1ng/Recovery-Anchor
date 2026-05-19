# RecoveryAnchor v1.3.1 — Release Notes

## Verification, Configurability, and Release Workflow Cleanup

### What changed

**Safer flash verification**
- Added `VERIFY_AFTER_FLASH=true` by default.
- After writing recovery, `service.sh` now re-reads the first hashed region of the partition and compares it with the source image.
- If the hashes differ, the flash is reported as failed.

**More configurable behavior**
- Added `BOOT_DELAY` to replace the hardcoded post-boot wait.
- Added `MAX_BACKUPS` to control how many backups are kept per slot.
- Added `HASH_CHECK_BLOCKS` to control how much of the image/partition is hashed for compare and verify.

**Better traceability**
- `service.sh` now logs the SHA-256 of the configured recovery image on every run.
- This makes it easier to confirm exactly which recovery build is installed on-device.

**Cleaner backup path**
- Backup creation now uses a single-read flow with `dd | tee | sha256sum`.
- This avoids reading the recovery partition twice before flashing.

**Installer/runtime polish**
- Installer A/B confirmation now uses `getprop ro.boot.slot_suffix`.
- Duplicate fallback logic in `customize.sh` was removed.
- Exit logging was simplified with a central `trap` handler.

**Release workflow fixed**
- GitHub release notes artifact SHA-256 and displayed file size were fixed.
- Draft release creation now uses `gh release create` instead of the previous action, which behaved poorly on re-runs for the same tag.

---

**Upgrade**: Flash the new ZIP in KernelSU/Magisk Manager. Existing config stays compatible; new keys are added only for fresh installs unless you add them manually.

**Full Changelog**: see [CHANGELOG.md](CHANGELOG.md)
