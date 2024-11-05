#!/bin/bash

# Prompt user for sleep and wake-up times
read -p "Enter desired sleep time (HH:MM): " SLEEP_TIME
read -p "Enter desired wake-up time (HH:MM): " WAKEUP_TIME

# Prompt user if they want beeps on suspend and wake-up
read -p "Do you want a beep on suspend? (y/n): " BEEP_ON_SUSPEND
if [[ $BEEP_ON_SUSPEND =~ ^[Yy]$ ]]; then
    read -p "How many beeps on suspend? (e.g., 2): " SUSPEND_BEEP_COUNT
fi

read -p "Do you want a beep on wake-up? (y/n): " BEEP_ON_WAKEUP
if [[ $BEEP_ON_WAKEUP =~ ^[Yy]$ ]]; then
    read -p "How many beeps on wake-up? (e.g., 1): " WAKEUP_BEEP_COUNT
fi

# Prompt for beep tone and duration if beeping is enabled
if [[ $BEEP_ON_SUSPEND =~ ^[Yy]$ || $BEEP_ON_WAKEUP =~ ^[Yy]$ ]]; then
    echo "Enter desired beep tone frequency (in Hz). Higher values create higher-pitched sounds:"
    read -p "(Recommended range: 500-2000 Hz, e.g., 1000): " BEEP_TONE
    echo "Enter desired beep duration (in milliseconds). Higher values create longer beeps:"
    read -p "(e.g., 500 for half a second): " BEEP_DURATION
fi

# Define paths
SUSPEND_SCRIPT="/usr/local/bin/suspend_and_set_wakealarm.sh"
WAKEUP_SCRIPT="/usr/local/bin/wakeup_beep.sh"
SERVICE_FILE="/etc/systemd/system/proxmox-suspend.service"
TIMER_FILE="/etc/systemd/system/proxmox-suspend.timer"
WAKEUP_BEEP_SERVICE="/etc/systemd/system/wakeup-beep.service"

# Install beep if not available
if ! command -v beep &> /dev/null; then
    apt-get install -y beep
fi

# Create suspend script
echo "Creating suspend script at $SUSPEND_SCRIPT"
cat <<EOL > "$SUSPEND_SCRIPT"
#!/bin/bash
echo \$(date +%s -d '$WAKEUP_TIME') > /sys/class/rtc/rtc0/wakealarm
EOL

# Add beeping logic for suspend if enabled
if [[ $BEEP_ON_SUSPEND =~ ^[Yy]$ ]]; then
    for ((i=0; i<$SUSPEND_BEEP_COUNT; i++)); do
        echo "beep -f $BEEP_TONE -l $BEEP_DURATION" >> "$SUSPEND_SCRIPT"
    done
fi
# Add system suspend command
echo "systemctl suspend" >> "$SUSPEND_SCRIPT"
chmod +x "$SUSPEND_SCRIPT"

# Create wakeup beep script
echo "Creating wakeup beep script at $WAKEUP_SCRIPT"
cat <<EOL > "$WAKEUP_SCRIPT"
#!/bin/bash
EOL

# Add beeping logic for wakeup if enabled
if [[ $BEEP_ON_WAKEUP =~ ^[Yy]$ ]]; then
    for ((i=0; i<$WAKEUP_BEEP_COUNT; i++)); do
        echo "beep -f $BEEP_TONE -l $BEEP_DURATION" >> "$WAKEUP_SCRIPT"
    done
fi
chmod +x "$WAKEUP_SCRIPT"

# Create suspend service
echo "Creating suspend service at $SERVICE_FILE"
cat <<EOL > "$SERVICE_FILE"
[Unit]
Description=Automatically suspend Proxmox Host and set wake alarm

[Service]
Type=oneshot
ExecStartPre=/bin/sh -c 'echo \$(date +%s -d "$WAKEUP_TIME") > /sys/class/rtc/rtc0/wakealarm'
ExecStart=/usr/local/bin/suspend_and_set_wakealarm.sh
EOL

# Create suspend timer
echo "Creating suspend timer at $TIMER_FILE"
cat <<EOL > "$TIMER_FILE"
[Unit]
Description=Automatically suspend at specified time

[Timer]
OnCalendar=$SLEEP_TIME
Persistent=true

[Install]
WantedBy=timers.target
EOL

# Create wakeup beep service
echo "Creating wakeup beep service at $WAKEUP_BEEP_SERVICE"
cat <<EOL > "$WAKEUP_BEEP_SERVICE"
[Unit]
Description=Beep on Wakeup
After=suspend.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wakeup_beep.sh
User=root

[Install]
WantedBy=suspend.target
EOL

# Reload systemd and enable services and timer
echo "Reloading systemd, enabling services and timer..."
systemctl daemon-reload
systemctl enable proxmox-suspend.service
systemctl enable proxmox-suspend.timer
systemctl enable wakeup-beep.service
systemctl start proxmox-suspend.timer

echo "Setup complete. The system will suspend at $SLEEP_TIME and wake up at $WAKEUP_TIME."