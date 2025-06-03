#!/bin/bash

# iFlip.sh: Ultra-optimized script for low-latency, high-FPS video flipping on Raspberry Pi 4

# Default to /dev/video0 if no device is specified
DEVICE=${1:-/dev/video0}

# Assume dependencies are installed; if not, install them with one update
if ! { command -v ffmpeg && command -v v4l2-ctl && command -v fbset; } &> /dev/null; then
    echo "Installing required packages..."
    sudo apt update && sudo apt install -y ffmpeg v4l2-utils fbset
fi

# Ensure user is in video group
if ! id -nG | grep -qw video; then
    echo "Add yourself to video group: sudo usermod -aG video $USER, then log out/in."
    exit 1
fi

# Set framebuffer permissions
[ -e /dev/fb0 ] && sudo chmod 666 /dev/fb0 || { echo "No /dev/fb0. Ensure CLI mode."; exit 1; }

# Ensure /boot/config.txt has 1920x1080 16-bit framebuffer settings
if ! grep -q "hdmi_group=1" /boot/config.txt || ! grep -q "hdmi_mode=82" /boot/config.txt || ! grep -q "framebuffer_depth=16" /boot/config.txt; then
    sudo sed -i '/hdmi_group/d;/hdmi_mode/d;/framebuffer_depth/d' /boot/config.txt
    sudo bash -c 'echo -e "hdmi_group=1\nhdmi_mode=82\nframebuffer_depth=16" >> /boot/config.txt'
    echo "Reboot required: sudo reboot"
    exit 1
fi

# Stop fbcp if running
[ "$(pgrep -x fbcp)" ] && { sudo pkill -x fbcp; sleep 1; }

while true; do
    if [ -e "$DEVICE" ]; then
        # Prefer MJPEG for hardware acceleration, fall back to YUYV or YU12
        v4l2-ctl --set-fmt-video=width=1920,height=1080,pixelformat=MJPG -d "$DEVICE" || \
        v4l2-ctl --set-fmt-video=width=1920,height=1080,pixelformat=YUYV -d "$DEVICE" || \
        v4l2-ctl --set-fmt-video=width=1920,height=1080,pixelformat=YU12 -d "$DEVICE"

        # Run ffmpeg with maximum optimization
        ffmpeg -hwaccel v4l2m2m -re -threads 1 -probesize 32 -analyzeduration 0 -fflags nobuffer -i "$DEVICE" -vf "hflip,format=rgb565le" -tune zerolatency -vsync 0 -f fbdev /dev/fb0

        echo "ffmpeg exited. Retrying in 5 seconds..."
        sleep 5
    else
        echo "Device $DEVICE not found. Retrying in 5 seconds..."
        sleep 5
    fi
done