#!/bin/bash

# Function to check if user is in the video group
check_video_group() {
    if ! id -nG "$USER" | grep -qw "video"; then
        echo "You are not in the video group. Please add yourself to the video group:"
        echo "sudo usermod -a -G video $USER"
        echo "Then log out and log back in."
        exit 1
    fi
}

# Function to install a package if not installed
install_if_missing() {
    local package=$1
    if ! command -v $package &> /dev/null; then
        echo "$package is not installed. Installing..."
        sudo apt-get update
        sudo apt-get install -y $package
    fi
}

# Function to test if a video device is working
test_device() {
    local device=$1
    if [ -r "$device" ]; then
        if ffmpeg -f v4l2 -i "$device" -vframes 1 -f null - &> /dev/null; then
            echo "$device"
        fi
    fi
}

# Main script
check_video_group

install_if_missing mpv
install_if_missing ffmpeg

echo "Detecting available video devices..."
video_devices=$(ls /dev/video* 2>/dev/null)

if [ -z "$video_devices" ]; then
    echo "No video devices found."
    exit 1
fi

working_devices=()
for device in $video_devices; do
    if working_device=$(test_device "$device"); then
        working_devices+=("$working_device")
    fi
done

if [ ${#working_devices[@]} -eq 0 ]; then
    echo "No working video devices found."
    exit 1
fi

# Select the first working device
selected_device=${working_devices[0]}
echo "Using video device: $selected_device"

# Launch mpv to display the video feed with horizontal flip
mpv --vo=drm --vf=hflip v4l2:"$selected_device"