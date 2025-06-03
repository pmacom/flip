#!/bin/bash

# Default to /dev/video0 if no device is specified
DEVICE=${1:-/dev/video0}

# Check if the video device exists
if [ ! -e "$DEVICE" ]; then
    echo "Device $DEVICE does not exist."
    exit 1
fi

# Check if mpv is installed; install it if not
if ! command -v mpv &> /dev/null; then
    echo "mpv is not installed. Installing..."
    sudo apt update
    sudo apt install -y mpv
fi

# Check if the user is in the video group
if ! id -nG | grep -qw video; then
    echo "You are not in the video group. Please run: sudo usermod -aG video $USER and log out/in."
    exit 1
fi

# Detect environment and set video output
if [ -n "$DISPLAY" ]; then
    VO="x11"  # Desktop environment
else
    VO="drm"  # CLI environment
fi

# Run mpv to flip and display the video
mpv --vo=$VO --vf=hflip --fs av://v4l2:$DEVICE