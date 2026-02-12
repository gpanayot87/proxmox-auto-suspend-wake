# Proxmox Auto Suspend and Wake Script

This script automates suspending your Proxmox node at a scheduled time, sets an RTC wake alarm, and optionally plays beep notifications before suspend and after resume.

## Features

- **Automated suspend and wake** with daily schedule.
- **RTC wake alarm** is recalculated every suspend run so wake always targets the next valid day/time.
- **Optional beep notifications** for both pre-suspend and post-resume.
- **Interactive management menu** to install, remove, and update timings/settings.
- Installer performs a compatibility purge of older unit/script layouts before recreating the current ones, preventing conflicts after upgrades.
- Beep/tone prompts support sensible defaults; press Enter to accept recommended values during setup.

## Installation

Run as root on your Proxmox node:

```bash
bash proxmox-auto-suspend-wake.sh
```

Then choose **Proceed with the install** and follow prompts.

## What gets created

- `/usr/local/bin/proxmox-auto-suspend-wake.settings`: Persistent settings.
- `/usr/local/bin/suspend_and_set_wakealarm.sh`: Suspend runtime helper.
- `/usr/lib/systemd/system-sleep/proxmox-wakeup-beep`: Resume beep hook.
- `/etc/systemd/system/proxmox-suspend.service`: Suspend service.
- `/etc/systemd/system/proxmox-suspend.timer`: Daily timer.

## Notes

- Wake beep is implemented with a `system-sleep` post hook (runs on resume), which is more reliable than starting a service only at install time.
- The timer is enabled; the suspend service itself is not started immediately during install.

## Requirements

- Proxmox VE host with `systemd`.
- `beep` package only if you enable notifications.
