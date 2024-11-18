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
    echo "7. Reload services"
    echo
    echo -n "Select an option: "
}
# Function to install the actions
install_actions() {
    clear_screen
    echo "Starting the installation process..."

    # Prompt for suspend and wake times
    read -p "Please enter the suspend time (HH:MM): " sleep_time
    echo "Suspend time set to $sleep_time."
    
    read -p "Please enter the wake up time (HH:MM): " wake_time
    echo "Wake up time set to $wake_time."

    # Beep settings
    if read -p "Do you want beep notifications? (Y/N) " -r && [[ $REPLY =~ ^[Yy]$ ]]; then
        # Check if beep package is installed, if not proceeds to install and continues configuration
        echo "Checking for Beep package..."
        if ! dpkg -s beep &> /dev/null; then
        echo "Beep package is not installed. Installing..."
        apt-get update && apt-get install -y beep
        echo "Beep package has been installed. Continuing configuration."
        fi
        
        echo "=== Beep Configuration ===" 
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
# Save user settings to file
    SETTINGS_FILE="/usr/local/bin/proxmox-auto-suspend-wake.settings"
    echo "Saving settings to $SETTINGS_FILE..."
    echo "suspend_time=$sleep_time" > "$SETTINGS_FILE"
    echo "wake_time=$wake_time" >> "$SETTINGS_FILE"
    echo "sleep_beeps=$sleep_beeps" >> "$SETTINGS_FILE"
    echo "wake_beeps=$wake_beeps" >> "$SETTINGS_FILE"
    echo "tone_freq=$tone_freq" >> "$SETTINGS_FILE"
    echo "beep_duration=$beep_duration" >> "$SETTINGS_FILE"

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
# Function to remove actions
remove_actions() {
    echo "Removing Proxmox Suspend & Wake automation..."

    # Remove services
    systemctl stop proxmox-suspend.service
    systemctl disable proxmox-suspend.service
    rm /etc/systemd/system/proxmox-suspend.service
    systemctl daemon-reload

    systemctl stop proxmox-suspend.timer
    systemctl disable proxmox-suspend.timer
    rm /etc/systemd/system/proxmox-suspend.timer
    systemctl daemon-reload

    systemctl stop wakeup-beep.service
    systemctl disable wakeup-beep.service
    rm /etc/systemd/system/wakeup-beep.service
    systemctl daemon-reload

    # Remove settings file
    rm /usr/local/bin/proxmox-auto-suspend-wake.settings

    # Prompt user to uninstall beep package
    read -p "Do you want to uninstall the beep package? (Y/N) " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apt-get remove -y beep
    fi

    echo "Proxmox Suspend & Wake automation removed successfully."
}

# Function to update the times
update_times() {
    clear_screen
    echo "Updating suspend and wake times..."

    # Display current suspend and wake times
    echo
    echo "------------------------------------"
    echo "|          Current Times          |"
    echo "------------------------------------"
    echo "|  Suspend Time: $(grep -Po "suspend_time=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2)  |"
    echo "|  Wake Time: $(grep -Po "wake_time=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2)  |"
    echo "------------------------------------"
    echo

    
    # Get and validate new times from the user
    echo "Please provide new times for suspend and wake-up:"
    read -p "Enter new suspend time (HH:MM): " suspend_time
    read -p "Enter new wake-up time (HH:MM): " wake_time

    # Validate time format
    if [[ "$suspend_time" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]] && [[ "$wake_time" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        # Update systemd timers
        sed -i "s/OnCalendar=.*/OnCalendar=$suspend_time/" /etc/systemd/system/proxmox-suspend.timer
        echo "$(date +%s -d "$wake_time")" > /sys/class/rtc/rtc0/wakealarm
        systemctl daemon-reload
        systemctl restart proxmox-suspend.timer

        # Update settings file
        SETTINGS_FILE="/usr/local/bin/proxmox-auto-suspend-wake.settings"
        sed -i "s/suspend_time=.*/suspend_time=$suspend_time/" "$SETTINGS_FILE"
        sed -i "s/wake_time=.*/wake_time=$wake_time/" "$SETTINGS_FILE"

        echo "Times updated successfully."
    else
        echo "Invalid time format. Please use HH:MM."
    fi
}

# Function to edit the tone and duration
edit_tone_time() {
clear_screen
    echo "Editing tone and beep settings..."

    # Display current tone and beep settings
    echo
    echo "------------------------------------"
    echo "|          Current Settings         |"
    echo "------------------------------------"
    echo "|  Tone Frequency: $(grep -Po "tone_freq=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2) Hz  |"
    echo "|  Beep Duration: $(grep -Po "beep_duration=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2) ms  |"
    echo "|  Sleep Beeps: $(grep -Po "sleep_beeps=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2)  |"
    echo "|  Wake Beeps: $(grep -Po "wake_beeps=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2)  |"
    echo "|  Beep Delay: $(grep -Po "beep_delay=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2) ms  |"
    echo "------------------------------------"
    echo

    # Ask user which setting to adjust
    echo "Which setting would you like to adjust?"
    echo "1. Adjust how many beeps"
    echo "2. Adjust the tone"
    echo "3. Add a preferred delay between each beep"
    read -p "Enter your choice: " choice

    case $choice in
        1)
            # Get and validate new number of beeps from the user
            read -p "Enter new number of beeps on suspend (1-5): " sleep_beeps
            read -p "Enter new number of beeps on wake (1-5): " wake_beeps

            # Validate number of beeps
            if [[ "$sleep_beeps" =~ ^[1-5]$ ]] && [[ "$wake_beeps" =~ ^[1-5]$ ]]; then
                # Update number of beeps
                sed -i "s/sleep_beeps=.*/sleep_beeps=$sleep_beeps/" /usr/local/bin/proxmox-auto-suspend-wake.settings
                sed -i "s/wake_beeps=.*/wake_beeps=$wake_beeps/" /usr/local/bin/proxmox-auto-suspend-wake.settings
            else
                echo "Invalid number of beeps. Please use a number between 1 and 5."
                return
            fi
            ;;
        2)
            # Get and validate new tone frequency and duration from the user
            read -p "Enter new tone frequency (Hz, e.g. 1000): " tone_freq
            read -p "Enter new tone duration (ms, e.g. 300): " beep_duration

            # Validate tone frequency and duration
            if [[ "$tone_freq" =~ ^[0-9]+$ ]] && [[ "$beep_duration" =~ ^[0-9]+$ ]]; then
                # Update tone frequency and duration
                sed -i "s/tone_freq=.*/tone_freq=$tone_freq/" /usr/local/bin/proxmox-auto-suspend-wake.settings
                sed -i "s/beep_duration=.*/beep_duration=$beep_duration/" /usr/local/bin/proxmox-auto-suspend-wake.settings
            else
                echo "Invalid tone frequency or duration. Please use a positive integer."
                return
            fi
            ;;
        3)
            # Get and validate new beep delay from the user
            read -p "Enter new beep delay (ms, e.g. 500): " beep_delay

            # Validate beep delay
            if [[ "$beep_delay" =~ ^[0-9]+$ ]]; then
                # Update beep delay
                sed -i "s/beep_delay=.*/beep_delay=$beep_delay/" /usr/local/bin/proxmox-auto-suspend-wake.settings
            else
                echo "Invalid beep delay. Please use a positive integer."
                return
            fi
            ;;
        *)
            echo "Invalid choice. Please try again."
            return
            ;;
    esac

    # Update systemd service
    SYSTEMD_SERVICE="/etc/systemd/system/proxmox-suspend.service"
    sed -i "s/ToneFrequency=.*/ToneFrequency=$(grep -Po "tone_freq=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2)/" "$SYSTEMD_SERVICE"
    sed -i "s/BeepDuration=.*/BeepDuration=$(grep -Po "beep_duration=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2)/" "$SYSTEMD_SERVICE"
    sed -i "s/SleepBeeps=.*/SleepBeeps=$(grep -Po "sleep_beeps=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2)/" "$SYSTEMD_SERVICE"
    sed -i "s/WakeBeeps=.*/WakeBeeps=$(grep -Po "wake_beeps=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2)/" "$SYSTEMD_SERVICE"
    sed -i "s/BeepDelay=.*/BeepDelay=$(grep -Po "beep_delay=.*" /usr/local/bin/proxmox-auto-suspend-wake.settings | cut -d= -f2)/" "$SYSTEMD_SERVICE"

    # Reload systemd daemon and restart timer
    systemctl daemon-reload
    systemctl restart proxmox-suspend.timer
}

# Function to see the status
see_status() {
    clear_screen
    echo "Fetching current status of Proxmox Suspend & Wake automation..."

    # Read settings from file
    SETTINGS_FILE="/usr/local/bin/proxmox-auto-suspend-wake.settings"
    suspend_time=$(grep -Po "suspend_time=.*" "$SETTINGS_FILE" | cut -d= -f2)
    wake_time=$(grep -Po "wake_time=.*" "$SETTINGS_FILE" | cut -d= -f2)
    tone_freq=$(grep -Po "tone_freq=.*" "$SETTINGS_FILE" | cut -d= -f2)
    beep_duration=$(grep -Po "beep_duration=.*" "$SETTINGS_FILE" | cut -d= -f2)
    sleep_beeps=$(grep -Po "sleep_beeps=.*" "$SETTINGS_FILE" | cut -d= -f2)
    wake_beeps=$(grep -Po "wake_beeps=.*" "$SETTINGS_FILE" | cut -d= -f2)

    # Check the status of services
    for service in proxmox-suspend.service proxmox-suspend.timer wakeup-beep.service; do
        statuses+=($(systemctl is-active "$service" 2>/dev/null || echo "unknown"))
    done

    # Current time in seconds
    current_time=$(date +%s)

    # Time until next suspend
    next_suspend_time=$(date -d "$suspend_time" +%s)
    if [ $next_suspend_time -lt $current_time ]; then
        next_suspend_time=$((next_suspend_time + 86400)) # add 24 hours if suspend time has already passed
    fi
    time_until_suspend=$((next_suspend_time - current_time))

    # Time until next wake
    next_wake_time=$(date -d "$wake_time" +%s)
    if [ $next_wake_time -lt $current_time ]; then
        next_wake_time=$((next_wake_time + 86400)) # add 24 hours if wake time has already passed
    fi
    time_until_wake=$((next_wake_time - current_time))

    # Format time left for suspend and wake-up
    format_time() {
        (( $1 > 0 )) && echo "$(($1 / 3600)) Hours, $((($1 % 3600) / 60)) Minutes" || echo "Time has passed or not set."
    }

    # Display settings
    echo
    echo "------------------------------------"
    echo "* Services:"
    echo "  - Suspend Service: ${statuses[0]^}"
    echo "  - Suspend Timer: ${statuses[1]^}"
    echo "  - Wakeup Beep Service: ${statuses[2]^}"
    echo "* Current Settings:"
    echo "  - Suspend Time: $suspend_time"
    echo "  - Wake Up Time: $wake_time"
    echo "  - Tone Frequency: $tone_freq Hz"
    echo "  - Beep Duration: $beep_duration ms"
    echo "  - Sleep Beeps: $sleep_beeps"
    echo "  - Wake Beeps: $wake_beeps"
    echo "  - Time until next Suspend: $(format_time "$time_until_suspend")"
    echo "  - Time until next Wake: $(format_time "$time_until_wake")"

    echo "------------------------------------"
    echo "Press 'q' to return to the main menu. If any issue arises, return to the main menu and run the install process again."
    read -p "Press any key to continue... " -n1 -s
    echo
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
# Function to reload all services
reload_services() {
    echo "Reloading all services..."
    systemctl daemon-reload
    systemctl restart proxmox-suspend.timer wakeup-beep.service
    echo "Services reloaded successfully."
    systemctl status proxmox-suspend.timer wakeup-beep.service
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
        7)
            reload_services
            read -p "Press any key to continue..."
            ;;
        *)
            echo "Invalid choice, please try again."
            ;;
    esac
done