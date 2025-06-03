#!/bin/bash

# Script to ensure video display on Raspberry Pi LCD screen

# Default configuration
PLAYER="mpv"
CAPTURE_DEVICE="${1:-/dev/video0}"  # Default to /dev/video0, or use first argument
VO_METHOD="${2:-x11}"               # Default to x11, or use second argument
PID_FILE="/tmp/capture_display.pid"

# Function to check if mpv is already running
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if [ -d "/proc/$PID" ]; then
            return 0
        fi
    fi
    return 1
}

# Check if capture device exists
if [ ! -e "$CAPTURE_DEVICE" ]; then
    echo "Capture device $CAPTURE_DEVICE not found."
    exit 1
fi

# Check if user is in the video group
if ! groups | grep -q video; then
    echo "User is not in the video group. Please run 'sudo usermod -aG video $USER' and log out/in."
    exit 1
fi

# Install mpv if not installed
if ! dpkg -s $PLAYER &> /dev/null; then
    echo "$PLAYER is not installed. Installing..."
    sudo apt update
    sudo apt install -y $PLAYER
fi

# Check if hdmi_force_hotplug is set in /boot/config.txt
if ! grep -q "hdmi_force_hotplug=1" /boot/config.txt; then
    echo "Warning: hdmi_force_hotplug is not set in /boot/config.txt."
    echo "You may need to add 'hdmi_force_hotplug=1' to /boot/config.txt and reboot for the display to work."
fi

# If using x11, check if DISPLAY is set
if [ "$VO_METHOD" = "x11" ] && [ -z "$DISPLAY" ]; then
    echo "DISPLAY variable is not set. Please run this script in a graphical environment or set DISPLAY."
    exit 1
fi

# Check if mpv is already running
if is_running; then
    echo "$PLAYER is already running with PID $(cat "$PID_FILE")."
    exit 0
fi

# Launch mpv
echo "Launching $PLAYER with --vo=$VO_METHOD..."
$PLAYER --vo=$VO_METHOD --vf=hflip "$CAPTURE_DEVICE" --fullscreen &
PID=$!
echo $PID > "$PID_FILE"
echo "$PLAYER started with PID $PID."