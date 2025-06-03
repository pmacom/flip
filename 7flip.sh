#!/bin/bash

# Check if mpv is installed
if ! command -v mpv &> /dev/null; then
    echo "mpv is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y mpv
fi

# Check if /dev/video1 exists
if [ ! -e /dev/video1 ]; then
    echo "Video device /dev/video1 not found."
    exit 1
fi

# Check if user has permission to read /dev/video0
if [ ! -r /dev/video1 ]; then
    echo "You do not have permission to read /dev/video1."
    echo "Please add your user to the video group with:"
    echo "sudo usermod -a -G video $USER"
    echo "Then log out and log back in."
    exit 1
fi

# Launch mpv to display the video feed with horizontal flip
mpv --vo=drm --vf=hflip v4l2:/dev/video0