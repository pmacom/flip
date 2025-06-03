#!/bin/bash

# Configuration
DEVICE=${1:-/dev/video0}
RESOLUTION=${2:-1280x720}
FPS=${3:-30}
FORMAT=${4:-mjpg}
PLAYER=mpv
LOG_FILE=/var/log/flip_video.log

# Check if device exists
if [ ! -e "$DEVICE" ]; then
    echo "Device $DEVICE not found" >> "$LOG_FILE"
    exit 1
fi

# Check if mpv is installed; install if not
if ! command -v $PLAYER &> /dev/null; then
    echo "Installing $PLAYER..." >> "$LOG_FILE"
    sudo apt update
    sudo apt install -y $PLAYER
fi

# Check and fix permissions
if [ ! -r "$DEVICE" ]; then
    echo "Fixing permissions for $DEVICE" >> "$LOG_FILE"
    sudo chmod 666 "$DEVICE"
fi

# Check if user is in video group
if ! id -nG | grep -qw video; then
    echo "Warning: Not in video group. Run: sudo usermod -aG video $USER and log out/in" >> "$LOG_FILE"
fi

# Detect environment and set video output
if [ -n "$DISPLAY" ]; then
    VO_METHOD=x11
else
    VO_METHOD=drm
fi

# Run mpv with optimized settings
echo "Starting $PLAYER on $DEVICE ($RESOLUTION@$FPS, $FORMAT)" >> "$LOG_FILE"
$PLAYER --vo=$VO_METHOD --hwdec=auto --vf=hflip --fs v4l2:$DEVICE:width=${RESOLUTION%%x*}:height=${RESOLUTION##*x}:fps=$FPS:format=$FORMAT >> "$LOG_FILE" 2>&1