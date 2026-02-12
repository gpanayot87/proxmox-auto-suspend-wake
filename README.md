# Proxmox Auto Suspend and Wake Script

A menu-driven shell script for Proxmox hosts that automates:

- scheduled **system suspend**
- automatic **RTC wake alarm** programming
- optional **beep notifications** before suspend and after resume
- management of the required `systemd` units and helper scripts

The goal is to provide a simple “set it once, then maintain from menu” workflow for home labs and low-usage servers.

---

## What the script does

When installed, the script:

1. Saves your configuration to a persistent settings file.
2. Creates a suspend helper script that:
   - optionally plays pre-suspend beeps,
   - calculates the correct next wake timestamp,
   - writes that timestamp to `/sys/class/rtc/rtc0/wakealarm`,
   - suspends the host.
3. Creates a wake beep hook in `systemd` sleep hooks (`post` resume path).
4. Creates/updates a `systemd` service and timer for suspend scheduling.
5. Reloads and enables the timer.

It can also remove/purge previous versions’ artifacts to avoid conflicts during upgrades.

---

## Features

- **Weekday + optional weekend scheduling**
  - Configure one schedule for Mon–Fri and optionally a different schedule for Sat/Sun.
- **Default-friendly setup**
  - Most prompts support pressing **Enter** to accept sensible defaults.
- **Wake alarm recalculation**
  - Wake epoch is recalculated at suspend time so it remains accurate for the next cycle.
- **Optional beep notifications**
  - Configure independent sleep/wake beep counts, frequency, duration, and delay.
- **Install/update safety**
  - Purges known legacy files/services before recreating active units and scripts.
- **Status visibility**
  - Shows schedule settings and timer status from within the script menu.

---

## Runtime files created/managed

### Settings

- `/usr/local/bin/proxmox-auto-suspend-wake.settings`

Contains persisted values such as:

- weekday suspend/wake times
- weekend override settings
- beep/tone values

### Helper scripts

- `/usr/local/bin/suspend_and_set_wakealarm.sh`
  - Called by the suspend service.
- `/usr/lib/systemd/system-sleep/proxmox-wakeup-beep`
  - Called by `systemd` on wake (`post`) for wake beep notifications.

### systemd units

- `/etc/systemd/system/proxmox-suspend.service`
- `/etc/systemd/system/proxmox-suspend.timer`

---

## Menu options

1. **Proceed with the install**
   - Initial configuration flow for schedule + optional beep settings.
   - Recreates managed files/units.
2. **Remove all actions**
   - Disables/removes timer/service/scripts/settings.
3. **Update the times**
   - Updates weekday/weekend schedule and recreates timer config.
4. **Edit the tone and duration**
   - Updates beep settings only.
5. **See the status**
   - Displays active settings and timer information.
6. **Quit**
7. **Reload services**
   - Reloads daemon and restarts timer.

---

## Requirements

- Proxmox VE host with `systemd`
- Root privileges
- `beep` package **only if beep notifications are enabled**

---

## Installation

Run on your Proxmox host as root:

```bash
bash proxmox-auto-suspend-wake.sh
```

Then choose **Proceed with the install**.

---

## Upgrade/reinstall behavior

Re-running install/update is intended to be safe:

- known old units/scripts are stopped/disabled/removed,
- active units/scripts are regenerated from current settings,
- timer is re-enabled.

This helps prevent conflicts from older script revisions.

---

## Notes and caveats

- Suspend/wake behavior depends on hardware/BIOS/UEFI support for RTC wake.
- Ensure wake from suspend is enabled on your platform.
- If `beep` is installed but silent, your environment may restrict PC speaker access.
- The script is designed for **host-level** suspend/wake (not per-VM scheduling).

---

## Quick verification commands

After installation, you can verify:

```bash
systemctl status proxmox-suspend.timer --no-pager
systemctl list-timers proxmox-suspend.timer --no-pager
cat /usr/local/bin/proxmox-auto-suspend-wake.settings
```

---

## Troubleshooting tips

- If suspend happens unexpectedly after changes:
  - Re-run install/update from menu to regenerate units.
  - Verify current timer entries with `systemctl cat proxmox-suspend.timer`.
- If wake doesn’t occur:
  - Check BIOS/UEFI wake settings.
  - Confirm `/sys/class/rtc/rtc0/wakealarm` is writable and updates.
- If beeps do not play:
  - Confirm `beep` is installed and functional on your hardware.

