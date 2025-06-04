#!/bin/bash

# pFlip.sh - GStreamer pipeline for fast horizontal flipping
# Usage: ./pFlip.sh [device]
# Defaults to /dev/video0

DEVICE=${1:-/dev/video0}

# Ensure gstreamer is installed
if ! command -v gst-launch-1.0 >/dev/null; then
    echo "Error: gstreamer is not installed." >&2
    exit 1
fi

# Ensure user has access to the video device
if ! id -nG "$USER" | grep -qw video; then
    echo "Add your user to the video group and re-login: sudo usermod -aG video $USER" >&2
    exit 1
fi

GST_CMD=(
    gst-launch-1.0 -v
    v4l2src device="$DEVICE"
    ! "video/x-raw,width=1920,height=1080,framerate=60/1"
    ! videoflip method=horizontal-flip
)

# Choose appropriate sink (drm for CLI, autovideosink for desktop)
if [ -n "$DISPLAY" ]; then
    GST_CMD+=( autovideosink sync=false )
else
    GST_CMD+=( kmssink sync=false )
fi

"${GST_CMD[@]}"

