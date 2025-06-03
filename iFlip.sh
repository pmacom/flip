#!/bin/bash

# iFlip.sh: Optimized script for low-latency, high-FPS video flipping on Raspberry Pi

# Default to /dev/video0 if no device is specified
DEVICE=${1:-/dev/video0}

# Check if ffmpeg is installed; install it if not
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg is not installed. Installing..."
    sudo apt update
    sudo apt install -y ffmpeg
fi

# Check if v4l2-ctl is installed (for configuring video device)
if ! command -v v4l2-ctl &> /dev/null; then
    echo "v4l2-ctl is not installed. Installing..."
    sudo apt update
    sudo apt install -y v4l2-utils
fi

# Check if fbset is installed (for framebuffer configuration)
if ! command -v fbset &> /dev/null; then
    echo "fbset is not installed. Installing..."
    sudo apt update
    sudo apt install -y fbset
fi

# Check if the user is in the video group
if ! id -nG | grep -qw video; then
    echo "You are not in the video group. Please run: sudo usermod -aG video $USER and log out/in."
    exit 1
fi

# Ensure framebuffer permissions are set
if [ -e /dev/fb0 ]; then
    sudo chmod 666 /dev/fb0
else
    echo "Framebuffer /dev/fb0 not found. Ensure you're in CLI mode and try again."
    exit 1
fi

# Check /boot/config.txt for correct framebuffer settings (1920x1080, 16-bit)
echo "Checking /boot/config.txt for 1920x1080 16-bit framebuffer..."
if ! grep -q "hdmi_group=1" /boot/config.txt || ! grep -q "hdmi_mode=82" /boot/config.txt || ! grep -q "framebuffer_depth=16" /boot/config.txt; then
    echo "Updating /boot/config.txt to ensure 1920x1080 16-bit framebuffer..."
    sudo bash -c 'echo -e "\nhdmi_group=1\nhdmi_mode=82\nframebuffer_depth=16" >> /boot/config.txt'
    echo "Please reboot to apply changes (sudo reboot) and run the script again."
    exit 1
fi

# Stop any running fbcp process to prevent framebuffer conflicts
if pgrep -x "fbcp" > /dev/null; then
    echo "Stopping fbcp process to avoid conflicts..."
    sudo pkill -x fbcp
    sleep 1
fi

# Check framebuffer configuration
echo "Checking framebuffer configuration..."
fbset -i

while true; do
    if [ -e "$DEVICE" ]; then
        # Check supported pixel formats and resolutions for the video device
        echo "Checking supported formats for $DEVICE..."
        v4l2-ctl --list-formats-ext -d "$DEVICE"

        # Set video input to 1920x1080 with YUYV, fall back to YU12 or MJPG
        v4l2-ctl --set-fmt-video=width=1920,height=1080,pixelformat=YUYV -d "$DEVICE" || \
        v4l2-ctl --set-fmt-video=width=1920,height=1080,pixelformat=YU12 -d "$DEVICE" || \
        v4l2-ctl --set-fmt-video=width=1920,height=1080,pixelformat=MJPG -d "$DEVICE"

        # Try setting frame rate to 60 FPS, fall back to 30 FPS or 15 FPS
        v4l2-ctl --set-parm=60 -d "$DEVICE" || \
        v4l2-ctl --set-parm=30 -d "$DEVICE" || \
        v4l2-ctl --set-parm=15 -d "$DEVICE"

        # Verify actual frame rate
        echo "Checking configured frame rate..."
        v4l2-ctl -d "$DEVICE" --get-parm

        # OPTIONAL: Lower resolution to 1280x720 for higher FPS (uncomment to use)
        # v4l2-ctl --set-fmt-video=width=1280,height=720,pixelformat=YUYV -d "$DEVICE"
        # v4l2-ctl --set-parm=60 -d "$DEVICE"

        # Run ffmpeg with optimized settings for low latency and high FPS
        # -hwaccel v4l2m2m for hardware decoding of MJPEG or similar
        # -re for real-time input
        # -threads 1 to reduce overhead
        # -vf "hflip,format=rgb565le" for minimal processing
        # -vsync 0 to disable frame syncing
        ffmpeg -hwaccel v4l2m2m -re -threads 1 -probesize 32 -analyzeduration 0 -fflags nobuffer -i "$DEVICE" -vf "hflip,format=rgb565le" -vsync 0 -f fbdev /dev/fb0

        echo "ffmpeg exited. Retrying in 5 seconds..."
        sleep 5
    else
        echo "Device $DEVICE not found. Retrying in 5 seconds..."
        sleep 5
    fi
done