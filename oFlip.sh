#!/bin/bash

# oFlip.sh - Display horizontally flipped video using mpv with minimal latency
# Usage: ./oFlip.sh [device]
# If no device is provided, /dev/video0 is used.

DEVICE=${1:-/dev/video0}
FPS=60

# Ensure mpv is installed
if ! command -v mpv >/dev/null; then
    echo "Error: mpv is not installed." >&2
    exit 1
fi

# Ensure user has access to the video device
if ! id -nG "$USER" | grep -qw video; then
    echo "Add your user to the video group and re-login: sudo usermod -aG video $USER" >&2
    exit 1
fi

# Choose video output depending on environment
if [ -n "$DISPLAY" ]; then
    VO="x11"
else
    VO="drm"
fi

exec mpv --profile=low-latency --vo=$VO \
    --hwdec=v4l2m2m-copy --vf=hflip --fs \
    --video-timing-offset=0 --display-fps=$FPS \
    --cache=no --demuxer-readahead-secs=0 \
    av://v4l2:$DEVICE

