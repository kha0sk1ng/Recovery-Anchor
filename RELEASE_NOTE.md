# RecoveryAnchor v1.3.0 — Release Notes

## A/B-Only Scope + OTA Usage Guide

### What changed

**A/B devices only (breaking for non-A/B users)**
RecoveryAnchor now explicitly declares A/B (slot) devices as its only supported target.
Non-A/B devices have a fundamentally different OTA mechanism — this module was never
designed for them. Previously the script would silently attempt to flash a `recovery`
partition that may not exist. Now it exits immediately with a clear error log entry.

**Installer warning**
`customize.sh` probes for `recovery_a`/`recovery_b` block nodes at install time.
If neither is found, a visible `[!] WARNING` is printed so the user knows immediately.

**README rewritten**
- Table of Contents added.
- Quick Start section added (3 steps to get running).
- New dedicated section: **"Usage After OTA Update"** — explains the mandatory
  "Install to Inactive Slot (After OTA)" step in Magisk/KernelSU that must be
  done before rebooting after an OTA. Without this step:
    - Root is lost on the new slot.
    - Modules don't load.
    - RecoveryAnchor cannot run — recovery stays stock permanently.
- Sections reordered: About → Quick Start → Features → Compatibility → Install →
  OTA Guide → Config → Logs → How It Works → Build → Disclaimer.
- Version badge corrected (was stuck at v1.1.0).

---

**Upgrade**: Flash the new ZIP in KernelSU/Magisk Manager. Existing config is compatible.

**Full Changelog**: see [CHANGELOG.md](CHANGELOG.md)
