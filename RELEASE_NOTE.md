# RecoveryAnchor v1.2.4 — Release Notes

**Critical Security & Stability Update**

## Security Fixes

### Config Execution Vulnerability (Critical)
Removed `source` / `.` of the config file, which allowed arbitrary bash code injection via `service.sh`. Replaced with a safe `grep`/`cut`-based parser that extracts only `RECOVERY_IMG`, `FLASH_BOTH_SLOTS`, and `ENABLED` values by key name. Defaults are preserved when keys are missing or empty from the config.

### Partition Backup Permissions (High)
Backup partition dumps (`recovery_backup_*.img`) now have permissions **immediately locked to `600`** after creation, preventing raw block device data from being exposed to non-root processes via default file creation mode.

### Log File Permissions after Rotation (Medium)
When the log exceeds `MAX_LOG_BYTES` and is rotated to `.old`, the new log file is now explicitly recreated (`touch`) and secured (`chmod 600`), closing a window where the log could inherit world-readable permissions.

## Stability Improvements

### I/O Write Safety
The `dd` flash command now uses `conv=fsync` instead of a standalone `sync` call, guaranteeing that recovery image data is physically committed to the block device before `dd` returns. This eliminates the race condition between `dd` exit and the standalone `sync`.

---

**Full Changelog**: `a13b762...106ab73`

**Upgrade**: Flash the new module ZIP in KernelSU/Magisk Manager. Existing config files are compatible and do not need modification.
