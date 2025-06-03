#!/bin/bash
PID_FILE="/tmp/capture_display.pid"
CAPTURE_DEVICE="/dev/video0"
PLAYER="mpv"
VO_METHOD="x11"
DISPLAY_VAR=":0"
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if [ -d "/proc/$PID" ]; then
            return 0
        fi
    fi
    return 1
}
fix_packages() {
    echo "Checking and fixing package issues..."
    sudo apt-get install -f -y
    sudo apt-get update
    sudo apt-get upgrade -y
}
check_device_in_use() {
    if sudo fuser "$CAPTURE_DEVICE" &> /dev/null; then
        echo "Warning: Another process is using $CAPTURE_DEVICE."
        echo "Please close any applications using the device or run 'sudo fuser -k $CAPTURE_DEVICE' to terminate the process."
        exit 1
    fi
}
fix_packages
if ! dpkg -s $PLAYER &> /dev/null; then
    echo "$PLAYER is not installed. Installing..."
    sudo apt install -y $PLAYER
fi
if [ ! -e "$CAPTURE_DEVICE" ]; then
    echo "Capture device $CAPTURE_DEVICE not found. Please connect the capture card."
    exit 1
fi
if [ ! -r "$CAPTURE_DEVICE" ]; then
    echo "Cannot read $CAPTURE_DEVICE. Fixing permissions..."
    sudo chmod 666 "$CAPTURE_DEVICE"
fi
check_device_in_use
if is_running; then
    echo "$PLAYER is already running with PID $(cat "$PID_FILE")."
    exit 0
fi
echo "Select video output method:"
echo "1) x11 (for graphical desktop)"
echo "2) drm (for direct rendering, no X11)"
read -p "Enter choice (1 or 2): " choice
case $choice in
    1)
        VO_METHOD="x11"
        ;;
    2)
        VO_METHOD="drm"
        ;;
    *)
        echo "Invalid choice. Using default: $VO_METHOD"
        ;;
esac
if [ "$VO_METHOD" = "x11" ]; then
    export DISPLAY=$DISPLAY_VAR
fi
echo "Starting $PLAYER to display flipped video from $CAPTURE_DEVICE..."
$PLAYER --vo=$VO_METHOD --vf=hflip "$CAPTURE_DEVICE" --fullscreen &
PID=$!
echo $PID > "$PID_FILE"
echo "$PLAYER started with PID $PID."