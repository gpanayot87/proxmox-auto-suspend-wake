#!/bin/bash
set -u

SETTINGS_FILE="/usr/local/bin/proxmox-auto-suspend-wake.settings"
SUSPEND_SCRIPT="/usr/local/bin/suspend_and_set_wakealarm.sh"
WAKEUP_HOOK_SCRIPT="/usr/lib/systemd/system-sleep/proxmox-wakeup-beep"
SUSPEND_SERVICE="/etc/systemd/system/proxmox-suspend.service"
SUSPEND_TIMER="/etc/systemd/system/proxmox-suspend.timer"

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "This script must be run as root."
        exit 1
    fi
}

clear_screen() {
    clear
}

validate_time() {
    [[ "$1" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]
}

load_settings() {
    if [[ -f "$SETTINGS_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$SETTINGS_FILE"
    fi

    suspend_time="${suspend_time:-23:00}"
    wake_time="${wake_time:-07:00}"
    sleep_beeps="${sleep_beeps:-0}"
    wake_beeps="${wake_beeps:-0}"
    tone_freq="${tone_freq:-1000}"
    beep_duration="${beep_duration:-300}"
    beep_delay="${beep_delay:-100}"
}

save_settings() {
    cat > "$SETTINGS_FILE" <<EOF_SETTINGS
suspend_time=$suspend_time
wake_time=$wake_time
sleep_beeps=$sleep_beeps
wake_beeps=$wake_beeps
tone_freq=$tone_freq
beep_duration=$beep_duration
beep_delay=$beep_delay
EOF_SETTINGS
}

play_beep() {
    local freq=$1
    local duration=$2
    local count=$3
    local delay=$4

    if ! command -v beep >/dev/null 2>&1; then
        echo "beep command not found; skipping beep playback."
        return
    fi

    for ((i = 0; i < count; i++)); do
        beep -f "$freq" -l "$duration"
        sleep "0.$delay"
    done
}

display_prompt_screen() {
    echo -e "\e[32m+---------------------------------------------------------+\e[0m"
    echo -e "\e[32m|            Proxmox Auto Suspend and Wake Script         |\e[0m"
    echo -e "\e[32m+---------------------------------------------------------+\e[0m"
    echo "This script automates scheduled suspend and RTC wake with optional beeps."
    echo
    echo "Please choose an action from the options below:"
    echo "1. Proceed with the install"
    echo "2. Remove all actions"
    echo "3. Update the times"
    echo "4. Edit the tone and duration"
    echo "5. See the status"
    echo "6. Quit"
    echo "7. Reload services"
    echo
    echo -n "Select an option: "
}

create_runtime_scripts() {
    cat > "$SUSPEND_SCRIPT" <<'EOF_SUSPEND'
#!/bin/bash
set -u
SETTINGS_FILE="/usr/local/bin/proxmox-auto-suspend-wake.settings"
# shellcheck disable=SC1090
source "$SETTINGS_FILE"

if (( sleep_beeps > 0 )) && command -v beep >/dev/null 2>&1; then
    for ((i = 0; i < sleep_beeps; i++)); do
        beep -f "$tone_freq" -l "$beep_duration"
        sleep "0.${beep_delay:-100}"
    done
fi

now_epoch=$(date +%s)
wake_epoch=$(date -d "today ${wake_time}" +%s)
if (( wake_epoch <= now_epoch )); then
    wake_epoch=$(date -d "tomorrow ${wake_time}" +%s)
fi

echo 0 > /sys/class/rtc/rtc0/wakealarm
echo "$wake_epoch" > /sys/class/rtc/rtc0/wakealarm
systemctl suspend
EOF_SUSPEND

    chmod +x "$SUSPEND_SCRIPT"

    cat > "$WAKEUP_HOOK_SCRIPT" <<'EOF_WAKE'
#!/bin/bash
set -u
SETTINGS_FILE="/usr/local/bin/proxmox-auto-suspend-wake.settings"

if [[ "$1" != "post" ]]; then
    exit 0
fi

if [[ -f "$SETTINGS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SETTINGS_FILE"
fi

wake_beeps="${wake_beeps:-0}"
tone_freq="${tone_freq:-1000}"
beep_duration="${beep_duration:-300}"
beep_delay="${beep_delay:-100}"

if (( wake_beeps > 0 )) && command -v beep >/dev/null 2>&1; then
    for ((i = 0; i < wake_beeps; i++)); do
        beep -f "$tone_freq" -l "$beep_duration"
        sleep "0.${beep_delay}"
    done
fi
EOF_WAKE

    chmod +x "$WAKEUP_HOOK_SCRIPT"
}

create_systemd_units() {
    cat > "$SUSPEND_SERVICE" <<EOF_SERVICE
[Unit]
Description=Automatically suspend system and set wake alarm

[Service]
Type=oneshot
ExecStart=$SUSPEND_SCRIPT
EOF_SERVICE

    cat > "$SUSPEND_TIMER" <<EOF_TIMER
[Unit]
Description=Run proxmox suspend service at $suspend_time daily

[Timer]
OnCalendar=*-*-* $suspend_time:00
Persistent=true
Unit=proxmox-suspend.service

[Install]
WantedBy=timers.target
EOF_TIMER

    systemctl daemon-reload
    systemctl enable --now proxmox-suspend.timer
}

install_actions() {
    clear_screen
    echo "Starting the installation process..."

    while true; do
        read -r -p "Please enter the suspend time (HH:MM): " suspend_time
        validate_time "$suspend_time" && break
        echo "Invalid time format. Please use HH:MM (24-hour)."
    done

    while true; do
        read -r -p "Please enter the wake up time (HH:MM): " wake_time
        validate_time "$wake_time" && break
        echo "Invalid time format. Please use HH:MM (24-hour)."
    done

    sleep_beeps=0
    wake_beeps=0
    tone_freq=1000
    beep_duration=300
    beep_delay=100

    if read -r -p "Do you want beep notifications? (Y/N) " reply && [[ "$reply" =~ ^[Yy]$ ]]; then
        if ! command -v beep >/dev/null 2>&1; then
            echo "Beep package not installed. Installing..."
            apt-get update && apt-get install -y beep
        fi

        read -r -p "How many beeps on sleep (0-5)? " sleep_beeps
        read -r -p "How many beeps on wake (0-5)? " wake_beeps
        read -r -p "Enter the beep frequency (Hz, e.g. 1000): " tone_freq
        read -r -p "Enter the beep duration (ms, e.g. 300): " beep_duration
        read -r -p "Enter delay between beeps (10-999 ms, e.g. 100): " beep_delay

        play_beep "$tone_freq" "$beep_duration" "$sleep_beeps" "$beep_delay"
    fi

    save_settings
    create_runtime_scripts
    create_systemd_units

    echo "System configured for automatic suspend at $suspend_time and wake at $wake_time."
}

remove_actions() {
    echo "Removing Proxmox Suspend & Wake automation..."

    systemctl disable --now proxmox-suspend.timer >/dev/null 2>&1 || true
    rm -f "$SUSPEND_SERVICE" "$SUSPEND_TIMER"
    rm -f "$SUSPEND_SCRIPT" "$WAKEUP_HOOK_SCRIPT" "$SETTINGS_FILE"
    systemctl daemon-reload

    read -r -p "Do you want to uninstall the beep package? (Y/N) " reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        apt-get remove -y beep
    fi

    echo "Proxmox Suspend & Wake automation removed successfully."
}

update_times() {
    clear_screen
    load_settings

    echo "Current suspend time: $suspend_time"
    echo "Current wake time: $wake_time"

    read -r -p "Enter new suspend time (HH:MM): " new_suspend_time
    read -r -p "Enter new wake-up time (HH:MM): " new_wake_time

    if ! validate_time "$new_suspend_time" || ! validate_time "$new_wake_time"; then
        echo "Invalid time format. Please use HH:MM."
        return
    fi

    suspend_time="$new_suspend_time"
    wake_time="$new_wake_time"
    save_settings
    create_runtime_scripts
    create_systemd_units

    echo "Times updated successfully."
}

edit_tone_time() {
    clear_screen
    load_settings

    echo "Current tone frequency: $tone_freq Hz"
    echo "Current beep duration: $beep_duration ms"
    echo "Current sleep beeps: $sleep_beeps"
    echo "Current wake beeps: $wake_beeps"
    echo "Current beep delay: $beep_delay ms"

    read -r -p "Enter new sleep beeps (0-5): " sleep_beeps
    read -r -p "Enter new wake beeps (0-5): " wake_beeps
    read -r -p "Enter new tone frequency (Hz): " tone_freq
    read -r -p "Enter new beep duration (ms): " beep_duration
    read -r -p "Enter new delay between beeps (ms): " beep_delay

    save_settings
    create_runtime_scripts
    echo "Beep settings updated."
}

see_status() {
    clear_screen
    load_settings

    local timer_status
    timer_status=$(systemctl is-active proxmox-suspend.timer 2>/dev/null || true)

    echo "------------------------------------"
    echo "Suspend Timer Status: ${timer_status:-unknown}"
    echo "Suspend Time: $suspend_time"
    echo "Wake Time: $wake_time"
    echo "Tone Frequency: $tone_freq Hz"
    echo "Beep Duration: $beep_duration ms"
    echo "Sleep Beeps: $sleep_beeps"
    echo "Wake Beeps: $wake_beeps"
    echo "Beep Delay: $beep_delay ms"
    echo "------------------------------------"

    echo "systemd next trigger:"
    systemctl list-timers proxmox-suspend.timer --no-pager
    read -r -p "Press any key to continue... " -n 1 -s
    echo
}

reload_services() {
    echo "Reloading timer..."
    systemctl daemon-reload
    systemctl restart proxmox-suspend.timer
    systemctl status proxmox-suspend.timer --no-pager
}

require_root
load_settings

while true; do
    display_prompt_screen
    read -r choice
    case $choice in
        1) install_actions ;;
        2) remove_actions ;;
        3) update_times ;;
        4) edit_tone_time ;;
        5) see_status ;;
        6) echo "Quitting..."; exit 0 ;;
        7) reload_services ;;
        *) echo "Invalid choice, please try again." ;;
    esac

done
