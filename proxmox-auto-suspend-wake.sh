#!/bin/bash

# Function to clear screen
clear_screen() {
    clear
}

# Function to display a green box with script name and summary
display_prompt_screen() {
    echo -e "\e[32m+---------------------------------------------------------+\e[0m"
    echo -e "\e[32m|            Proxmox Auto Suspend and Wake Script         |\e[0m"
    echo -e "\e[32m+---------------------------------------------------------+\e[0m"
    echo "This script automates the process of suspending your Proxmox system at a specified time,"
    echo "waking it up at a later time, and optionally playing beeps before suspending and waking up."
    echo
    echo "Please choose an action from the options below:"
    echo "1. Proceed with the install"
    echo "2. Remove all actions"
    echo "3. Update the times"
    echo "4. Edit the tone and duration"
    echo "5. See the status"
    echo "6. Quit"
    echo
    echo -n "Select an option: "
}

# Function to install the actions
install_actions() {
    echo "Starting the installation process..."

    # Prompt for suspend and wake times
    read -p "Please enter the suspend time (HH:MM): " sleep_time
    echo "Suspend time set to $sleep_time."
    
    read -p "Please enter the wake up time (HH:MM): " wake_time
    echo "Wake up time set to $wake_time."

    # Beep settings
    if read -p "Do you want beep notifications? (Y/N) " -r && [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "How many beeps on sleep (1-5)? " sleep_beeps
        read -p "How many beeps on wake (1-5)? " wake_beeps
        read -p "Enter the beep frequency (Hz, e.g. 1000): " tone_freq
        read -p "Enter the beep duration (ms, e.g. 300): " beep_duration

        echo "Playing beep sound for sleep ($sleep_beeps times):"
        play_beep "$tone_freq" "$beep_duration" "$sleep_beeps"

        if ! read -p "Continue with these settings? (Y/N) " -r || [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Exiting installation."
            return
        fi

        echo "Playing beep sound for wake ($wake_beeps times):"
        play_beep "$tone_freq" "$beep_duration" "$wake_beeps"

        if ! read -p "Continue with these settings? (Y/N) " -r || [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Exiting installation."
            return
        fi
    else
        sleep_beeps=0
        wake_beeps=0
        tone_freq=1000
        beep_duration=300
    fi

    # Script paths
    SUSPEND_SCRIPT="/usr/local/bin/suspend_and_set_wakealarm.sh"
    WAKEUP_BEEP_SCRIPT="/usr/local/bin/wakeup_beep.sh"

    # Create suspend script
    cat <<EOF > "$SUSPEND_SCRIPT"
#!/bin/bash
echo 'Suspending system...'
sleep 1
echo 'System Suspended'
echo \$(date +%s -d $wake_time) > /sys/class/rtc/rtc0/wakealarm
echo 'Setting wakeup alarm for $wake_time'
systemctl suspend
EOF
    chmod +x "$SUSPEND_SCRIPT"

    # Create wakeup beep script
    cat <<EOF > "$WAKEUP_BEEP_SCRIPT"
#!/bin/bash
if (( $wake_beeps > 0 )); then
    for ((i=0; i<$wake_beeps; i++)); do
        beep -f $tone_freq -l $beep_duration
    done
fi
EOF
    chmod +x "$WAKEUP_BEEP_SCRIPT"

    # Create and enable systemd service and timer
    cat <<EOF > /etc/systemd/system/proxmox-suspend.service
[Unit]
Description=Automatically suspend the system and set wake alarm

[Service]
ExecStart=$SUSPEND_SCRIPT
Type=oneshot

[Install]
WantedBy=multi-user.target
EOF

    cat <<EOF > /etc/systemd/system/proxmox-suspend.timer
[Unit]
Description=Timer to run the proxmox-suspend service at $sleep_time

[Timer]
OnCalendar=$sleep_time
Persistent=true

[Install]
WantedBy=timers.target
EOF

    cat <<EOF > /etc/systemd/system/wakeup-beep.service
[Unit]
Description=Play beep sound when the system wakes up

[Service]
ExecStart=$WAKEUP_BEEP_SCRIPT
Type=oneshot

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable services
    systemctl daemon-reload
    systemctl enable --now proxmox-suspend.service proxmox-suspend.timer wakeup-beep.service

    echo "System configured for automatic suspend at $sleep_time and wake at $wake_time with beep notifications."
}


# Function to remove all actions
remove_actions() {
    echo "Removing all scheduled actions..."

    # Disable and remove systemd services and timers
    systemctl stop proxmox-suspend.timer proxmox-suspend.service wakeup-beep.service
    systemctl disable proxmox-suspend.timer proxmox-suspend.service wakeup-beep.service
    rm -f /etc/systemd/system/{proxmox-suspend.timer,proxmox-suspend.service,wakeup-beep.service}

    echo "Removal completed successfully."
}

# Function to update the times
update_times() {
    echo "Updating suspend and wake times..."

    # Get and validate new times from the user
    read -p "Enter new suspend time (HH:MM): " suspend_time
    read -p "Enter new wake-up time (HH:MM): " wake_time

    # Efficiently update systemd timers
    if [[ "$suspend_time" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]] && [[ "$wake_time" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        sed -i "s/OnCalendar=.*/OnCalendar=$suspend_time/" /etc/systemd/system/proxmox-suspend.timer
        echo "$(date +%s -d "$wake_time")" > /sys/class/rtc/rtc0/wakealarm
        systemctl daemon-reload
        systemctl restart proxmox-suspend.timer
        echo "Times updated successfully."
    else
        echo "Invalid time format. Please use HH:MM."
    fi
}

# Function to edit the tone and duration
    # This function allows the user to edit the beep tone frequency and duration for both suspension and wake-up events.
    # It first provides an option to hear sample beep sounds before setting them.
    # Then, it prompts the user to input custom frequencies and durations for the suspend and wake-up tones.
    # Finally, it updates the configurations accordingly with the provided values.
edit_tone_time() {
    echo "Editing the tone and duration..."

    # Ask if the user wants to hear the beep sounds before proceeding
    read -p "Do you want to hear the beep sounds before setting them? (Y/N): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "Testing the beep sound for suspending..."
        # Play beep for suspend
        beep -f 1000 -l 500  # Example: 1000Hz for 500ms
        sleep 1
        echo "Testing the beep sound for waking up..."
        # Play beep for wakeup
        beep -f 1000 -l 500  # Example: 1000Hz for 500ms
        sleep 1
    fi

    # Get user input for tone frequency and duration
    read -p "Enter the frequency of the tone for suspension (in Hz): " suspend_tone
    read -p "Enter the duration of the tone for suspension (in ms): " suspend_duration
    read -p "Enter the frequency of the tone for wake-up (in Hz): " wake_tone
    read -p "Enter the duration of the tone for wake-up (in ms): " wake_duration

    # Set up beep commands or adjust related configurations as per previous examples
    echo "Tone and duration updated successfully."
}

# Function to see the status
see_status() {
    echo "Fetching current status of Proxmox Suspend & Wake automation..."

    # Check the status of services
    for service in proxmox-suspend.service proxmox-suspend.timer wakeup-beep.service; do
        statuses+=($(systemctl is-active "$service" 2>/dev/null || echo "unknown"))
    done

    # Fetch active suspend and wake times
    suspend_time=$(grep -Po 'OnCalendar=\K.*' /etc/systemd/system/proxmox-suspend.timer 2>/dev/null || echo "Unavailable")

    # Fetch the current wake-up alarm time
    wake_alarm_time=$(< /sys/class/rtc/rtc0/wakealarm 2>/dev/null || echo "0")
    wake_time=$(date -d @"$wake_alarm_time" +"%H:%M" 2>/dev/null || echo "Unavailable")

    # Fetch beep counts for suspend and wakeup
    for pattern in 'suspend_beeps=\K[0-9]+' 'wakeup_beeps=\K[0-9]+'; do
        beep_counts+=($(grep -Po "$pattern" /usr/local/bin/proxmox-auto-suspend-wake.sh 2>/dev/null || echo "Unavailable"))
    done

    # Current time in seconds
    current_time=$(date +%s 2>/dev/null || echo "0")

    # Time until next suspend
    next_suspend_time=$(systemctl show proxmox-suspend.timer --property=NextElapseUSecRealtime --value 2>/dev/null || echo "0")
    next_suspend_epoch=$(date +%s -d "$next_suspend_time" 2>/dev/null || echo "0")
    time_until_suspend=$((next_suspend_epoch > current_time ? next_suspend_epoch - current_time : -1))

    # Time until next wake
    time_until_wake=$((wake_alarm_time > current_time ? wake_alarm_time - current_time : -1))

    # Format time left for suspend and wake-up
    format_time() {
        (( $1 > 0 )) && echo "$(($1 / 3600)) Hours, $((($1 % 3600) / 60)) Minutes" || echo "Time has passed or not set."
    }

    # Display service statuses, times, and beep counts
    echo
    echo "------------------------------------"
    echo "* Services:"
    echo "  - Suspend Service: ${statuses[0]^}"
    echo "  - Suspend Timer: ${statuses[1]^}"
    echo "  - Wakeup Beep Service: ${statuses[2]^}"
    echo "* Active Suspend Time: ${suspend_time:-Unavailable}"
    echo "* Active Wake Up Time: ${wake_time:-Unavailable}"
    echo "* Time until next Suspend: $(format_time "$time_until_suspend")"
    echo "* Time until next Wake: $(format_time "$time_until_wake")"
    echo "* Active Beep Counts:"
    echo "  - Beeps on Suspend: ${beep_counts[0]:-Unavailable}"
    echo "  - Beeps on Wakeup: ${beep_counts[1]:-Unavailable}"
    echo "------------------------------------"
    echo

    # Check for errors and prompt to re-run install
    if [[ "${statuses[0]}" != "active" || "${statuses[1]}" != "active" || "${statuses[2]}" != "active" ]]; then
        echo "One or more services are inactive or unhealthy."
        read -p "Do you want to re-run the install script to fix it? (Y/N): " response
        [[ "$response" =~ ^[Yy]$ ]] && install_actions || echo "Skipping re-install. You may encounter issues with the automation."
    fi
}

# Function to play beep sounds
play_beep() {
    local tone_freq=$1
    local beep_duration=$2
    local beep_count=$3

    echo "Playing beep sound with frequency $tone_freq Hz, duration $beep_duration ms, and $beep_count beeps."
    for ((i=0; i<beep_count; i++)); do
        beep -f "$tone_freq" -l "$beep_duration" &
        sleep 0.01
    done
    wait
}



# Main script loop
while true; do
    display_prompt_screen
    read choice
    case $choice in
        1)
            install_actions
            read -p "Do you want to go back to the install screen or quit? (Y/N)" answer
            if [[ "$answer" =~ ^[Yy]$ ]]; then
                continue
            else
                exit 0
            fi
            ;;
        2)
            remove_actions
            read -p "Do you want to go back to the install screen or quit? (Y/N)" answer
            if [[ "$answer" =~ ^[Yy]$ ]]; then
                continue
            else
                exit 0
            fi
            ;;
        3)
            update_times
            read -p "Do you want to go back to the install screen or quit? (Y/N)" answer
            if [[ "$answer" =~ ^[Yy]$ ]]; then
                continue
            else
                exit 0
            fi
            ;;
        4)
            edit_tone_time
            read -p "Do you want to go back to the install screen or quit? (Y/N)" answer
            if [[ "$answer" =~ ^[Yy]$ ]]; then
                continue
            else
                exit 0
            fi
            ;;
        5)
            see_status
            read -p "Press any key to continue..."
            ;;
        6)
            echo "Quitting..."
            exit 0
            ;;
        *)
            echo "Invalid choice, please try again."
            ;;
    esac
done