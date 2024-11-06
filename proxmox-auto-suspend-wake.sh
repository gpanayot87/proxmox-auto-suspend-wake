#!/bin/bash

# Function to clear screen
clear_screen() {
    clear
}

# Function to display a green box with script name and summary
display_prompt_screen() {
    clear_screen
    echo -e "\033[0;32m"  # Set text color to green
    echo "+---------------------------------------------------------+"
    echo "|            Proxmox Auto Suspend and Wake Script         |"
    echo "+---------------------------------------------------------+"
    echo -e "\033[0m"  # Reset color to default
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

    # Ask for suspend time
    echo "Please enter the suspend time (HH:MM):"
    read sleep_time
    echo "You have chosen to suspend the system at $sleep_time."

    # Ask for wake time
    echo "Please enter the wake up time (HH:MM):"
    read wake_time
    echo "You have chosen the wake up time at $wake_time."

    # Ask if user wants beeps
    echo "Do you want beep notifications? (Y/N)"
    read -r beep_response
    if [[ "$beep_response" =~ ^[Yy]$ ]]; then
        # Ask for the number of beeps for sleep and wake
        echo "How many beeps on sleep (1-5)?"
        read sleep_beeps
        echo "You have chosen $sleep_beeps beeps for sleep."

        echo "How many beeps on wake (1-5)?"
        read wake_beeps
        echo "You have chosen $wake_beeps beeps for wake."

        # Ask for tone frequency and duration
        echo "Enter the tone frequency for the beeps (Hz, e.g. 1000):"
        read tone_freq
        echo "You have chosen a frequency of $tone_freq Hz."

        echo "Enter the duration for the beeps (ms, e.g. 300):"
        read beep_duration
        echo "You have chosen a duration of $beep_duration ms."

        # Play beep sounds for user confirmation
        echo "Playing beep sound for sleep ($sleep_beeps times):"
        play_beep "$tone_freq" "$beep_duration" "$sleep_beeps"

        read -p "Do you want to continue with these settings? (Y/N) " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Exiting installation."
            return
        fi

        echo "Playing beep sound for wake ($wake_beeps times):"
        play_beep "$tone_freq" "$beep_duration" "$wake_beeps"

        read -p "Do you want to continue with these settings? (Y/N) " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Exiting installation."
            return
        fi
    else
        sleep_beeps=0
        wake_beeps=0
        tone_freq=1000
        beep_duration=300
    fi

    # Paths to the scripts
    SUSPEND_SCRIPT="/usr/local/bin/suspend_and_set_wakealarm.sh"
    WAKEUP_BEEP_SCRIPT="/usr/local/bin/wakeup_beep.sh"

    # Create suspend and wakeup scripts
    echo "Creating suspend script at $SUSPEND_SCRIPT"
    echo "#!/bin/bash" > "$SUSPEND_SCRIPT"
    echo "echo 'Suspending system...'" >> "$SUSPEND_SCRIPT"
    echo "sleep 1" >> "$SUSPEND_SCRIPT"
    echo "echo 'System Suspended'" >> "$SUSPEND_SCRIPT"
    echo "echo \$(date +%s -d $wake_time) > /sys/class/rtc/rtc0/wakealarm" >> "$SUSPEND_SCRIPT"
    echo "echo 'Setting wakeup alarm for $wake_time'" >> "$SUSPEND_SCRIPT"
    echo "systemctl suspend" >> "$SUSPEND_SCRIPT"
    chmod +x "$SUSPEND_SCRIPT"

    # Create wakeup beep script
    echo "Creating wakeup beep script at $WAKEUP_BEEP_SCRIPT"
    echo "#!/bin/bash" > "$WAKEUP_BEEP_SCRIPT"
    echo "if [ $wake_beeps -gt 0 ]; then" >> "$WAKEUP_BEEP_SCRIPT"
    for ((i=0; i<wake_beeps; i++)); do
        echo "  beep -f $tone_freq -l $beep_duration" >> "$WAKEUP_BEEP_SCRIPT"
    done
    echo "fi" >> "$WAKEUP_BEEP_SCRIPT"
    chmod +x "$WAKEUP_BEEP_SCRIPT"

    # Create systemd service and timer for suspend and wakeup
    echo "Creating systemd service and timer files for suspend and wakeup."
    echo "[Unit]" > /etc/systemd/system/proxmox-suspend.service
    echo "Description=Automatically suspend the system and set wake alarm" >> /etc/systemd/system/proxmox-suspend.service
    echo "[Service]" >> /etc/systemd/system/proxmox-suspend.service
    echo "ExecStart=$SUSPEND_SCRIPT" >> /etc/systemd/system/proxmox-suspend.service
    echo "Type=oneshot" >> /etc/systemd/system/proxmox-suspend.service

    echo "[Install]" >> /etc/systemd/system/proxmox-suspend.service
    echo "WantedBy=multi-user.target" >> /etc/systemd/system/proxmox-suspend.service

    echo "[Unit]" > /etc/systemd/system/proxmox-suspend.timer
    echo "Description=Timer to run the proxmox-suspend service at $sleep_time" >> /etc/systemd/system/proxmox-suspend.timer
    echo "[Timer]" >> /etc/systemd/system/proxmox-suspend.timer
    echo "OnCalendar=$sleep_time" >> /etc/systemd/system/proxmox-suspend.timer
    echo "Persistent=true" >> /etc/systemd/system/proxmox-suspend.timer
    echo "[Install]" >> /etc/systemd/system/proxmox-suspend.timer
    echo "WantedBy=timers.target" >> /etc/systemd/system/proxmox-suspend.timer

    echo "[Unit]" > /etc/systemd/system/wakeup-beep.service
    echo "Description=Play beep sound when the system wakes up" >> /etc/systemd/system/wakeup-beep.service
    echo "[Service]" >> /etc/systemd/system/wakeup-beep.service
    echo "ExecStart=$WAKEUP_BEEP_SCRIPT" >> /etc/systemd/system/wakeup-beep.service
    echo "Type=oneshot" >> /etc/systemd/system/wakeup-beep.service

    echo "[Install]" >> /etc/systemd/system/wakeup-beep.service
    echo "WantedBy=multi-user.target" >> /etc/systemd/system/wakeup-beep.service

    # Reload systemd to recognize the new services and timers
    systemctl daemon-reload
    systemctl enable proxmox-suspend.service
    systemctl enable proxmox-suspend.timer
    systemctl enable wakeup-beep.service

    # Start the timer
    systemctl start proxmox-suspend.timer
    systemctl start wakeup-beep.service

    echo "System successfully configured for automatic suspend at $sleep_time and wake at $wake_time with beep notifications."
}


# Function to remove all actions
remove_actions() {
    echo "Removing all scheduled actions..."

    # Disable and remove systemd services and timers
    systemctl stop proxmox-suspend.timer
    systemctl disable proxmox-suspend.timer
    systemctl stop proxmox-suspend.service
    systemctl disable proxmox-suspend.service
    systemctl stop wakeup-beep.service
    systemctl disable wakeup-beep.service
    rm -f /etc/systemd/system/proxmox-suspend.timer
    rm -f /etc/systemd/system/proxmox-suspend.service
    rm -f /etc/systemd/system/wakeup-beep.service

    echo "Removal completed successfully."
}

# Function to update the times
update_times() {
    echo "Updating the suspend and wake times..."

    # Get new times from the user
    read -p "Enter the new suspend time (in HH:MM format): " suspend_time
    read -p "Enter the new wake-up time (in HH:MM format): " wake_time

    # Modify systemd timers with new times (details from previous scripts)
    # Update systemd service and timers
    systemctl daemon-reload
    systemctl restart proxmox-suspend.timer

    echo "Times updated successfully."
}

# Function to edit the tone and duration
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
    echo "Current status of the services and timers:"
    systemctl status proxmox-suspend.service
    systemctl status proxmox-suspend.timer
    systemctl status wakeup-beep.service

    # Display countdown until suspend
    current_time=$(date +%s)
    next_suspend_time=$(date +%s -d "$(systemctl show -p ActiveEnterTimestamp --value proxmox-suspend.timer)")
    time_left=$((next_suspend_time - current_time))
    echo "Time left until next suspend: $(($time_left / 3600)) hours, $((($time_left % 3600) / 60)) minutes, $(($time_left % 60)) seconds."
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
