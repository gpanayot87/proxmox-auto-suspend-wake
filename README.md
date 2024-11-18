# Proxmox Auto Suspend and Wake Script

This script automates the process of suspending your Proxmox system at a specified time, waking it up at a later time, and optionally playing beep notifications before suspending and waking up.

## Features

- **Automated Suspend and Wake**: Set specific times for your Proxmox system to suspend and wake up.
- **Beep Notifications**: Optionally play beep sounds before the system suspends and wakes up.
- **Easy Configuration**: Simple prompts to configure suspend/wake times and beep settings.
- **Systemd Integration**: Uses systemd services and timers for reliable scheduling.

## Installation

To execute the script, run the following command in your pve terminal, preferably as root:

```bash
bash proxmox-auto-suspend-wake.sh
```

Follow the prompts to set your desired suspend and wake times, as well as beep settings.

## Usage

After installation, the script will create systemd services and timers to manage the suspend and wake actions. You can choose from the following options when you run the script:

1. **Proceed with the install**: Set up the suspend and wake actions by entering your desired times and beep settings.
2. **Remove all actions**: Disable and remove the scheduled actions if you no longer want the automation.
3. **Update the times**: Change the existing suspend and wake times to new values.
4. **Edit the tone and duration**: Customize the beep tone frequency and duration for both suspension and wake-up events.
5. **See the status**: Check the current status of the automation, including service statuses and scheduled times.
6. **Quit**: Exit the script.

## Configuration Files

The script creates the following files:

- `/usr/local/bin/suspend_and_set_wakealarm.sh`: Script to suspend the system and set the wake alarm.
- `/usr/local/bin/wakeup_beep.sh`: Script to play beep sounds upon waking.
- `/etc/systemd/system/proxmox-suspend.service`: Systemd service for suspending the system.
- `/etc/systemd/system/proxmox-suspend.timer`: Systemd timer to trigger the suspend service.
- `/etc/systemd/system/wakeup-beep.service`: Systemd service to play beep sounds when waking up.

## Requirements

- Proxmox VE
- `beep` command installed for beep notifications
- Systemd for managing services and timers

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Feel free to submit issues or pull requests if you have suggestions or improvements!
