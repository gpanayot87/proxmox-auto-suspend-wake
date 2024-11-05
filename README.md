# proxmox-auto-suspend-wake
Automated Suspend and Wake Script for Proxmox with Beep Notifications.

Auto Suspend & Wake Script for Proxmox

This script, setup_auto_suspend_wake.sh, is designed to automate the setup of a scheduled suspend (sleep) and wake on a Proxmox server. It provides flexibility for administrators to set preferred suspend and wake times, customize beeping alerts, and automate the Proxmox host's sleep/wake cycle. This setup is ideal for environments where you want to save energy or ensure the server is only online during specific hours.
Key Features

*Automated Scheduling: Easily set a sleep time and wake-up time. The script will create systemd timers and services to manage these cycles.
*Customizable Beeps: Users can enable or disable beeps and specify the number, tone, and duration of beeps for both suspend and wake events. This provides audio feedback to confirm actions.
*Persistence: Automatically reloads systemd and enables the timer and services to ensure the schedule persists across reboots.

How It Works

The script performs the following:

User Prompts: It asks for:
        Sleep Time (HH:MM) format.
        Wake-up Time (HH:MM) format.
        Whether you want beeps on suspend and wake-up.
        The beep tone frequency (in Hz) and duration (in milliseconds).
Creates Scripts and Systemd Units:
        Suspend Script: Sets the wake alarm time, produces beeps (if enabled), and suspends the system.
        Wake-Up Beep Script: Produces a beep when the system wakes (if enabled).
Systemd Setup:
        Suspend Service: Manages the suspend sequence.
        Suspend Timer: Triggers the suspend service at the specified time.
        Wake-Up Beep Service: Triggers the wake-up beep upon resuming.
Activation: Reloads systemd, enables the services and timers, and starts the suspend timer.

Installation & Usage

  Download and Prepare the Script:

    bash

wget https://github.com/gpanayot87/proxmox-auto-suspend-wake/blob/main/proxmox-auto-suspend-wake.sh
chmod +x setup_auto_suspend_wake.sh

Run the Script:

bash

sudo ./setup_auto_suspend_wake.sh

Follow the Prompts:

* Enter the desired suspend time and wake-up time in HH
    format.
 *   Specify if you want a beep before suspend and on wake-up.
*    Customize beep tone and duration as needed.

Check Status: After setup, confirm the services and timers are active:

bash

    systemctl status proxmox-suspend.service
    systemctl status proxmox-suspend.timer
    systemctl status wakeup-beep.service

Example Usage

To set the server to suspend at 23:00 and wake at 07:00 with a beep alert:

    Sleep Time: 23:00
    Wake-Up Time: 07:00
    Beep on Suspend: Yes, 2 beeps at 1000 Hz for 500 ms each
    Beep on Wake: Yes, 1 beep at 1000 Hz for 500 ms

Notes

    Beep Requirements: Ensure the beep utility is installed and functioning on your system. This script will attempt to install it if missing.
    RTC Wake Alarm: This relies on the system’s Real-Time Clock (RTC) to wake up; not all hardware supports wake alarms, so please confirm compatibility.
    Proxmox Permissions: Run as root or a user with sufficient permissions to modify system services.

Feel free to open an issue if you encounter any problems or have suggestions for improvements!
