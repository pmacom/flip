#!/bin/bash

# Stream and display horizontally flipped video on Raspberry Pi (flip.local)
# A majestic canvas for real-time video art, displaying locally and streaming to laptop
# User: flip, Password: flip, Resolution: 1920x1080

# Configuration variables
INPUT_DEVICE="/dev/video0"          # Primary V4L2 device (e.g., USB webcam or v4l2loopback)
OUTPUT_URL="udp://192.168.1.100:1234"  # Replace with laptop's IP address
RESOLUTION="1920x1080"              # Output resolution
FRAMERATE="30"                      # Frames per second
BITRATE="2000k"                     # Video bitrate (adjust for quality vs. bandwidth)
LOG_FILE="/home/flip/stream.log"    # Log file for debugging

# Ensure input device exists
if [ ! -e "$INPUT_DEVICE" ]; then
  echo "Error: Input device $INPUT_DEVICE not found!" | tee -a "$LOG_FILE"
  exit 1
fi

# Check if ffmpeg supports sdl2
if ! ffmpeg -formats 2>/dev/null | grep -q sdl2; then
  echo "Error: ffmpeg does not support sdl2! Install libsdl2-dev and recompile ffmpeg." | tee -a "$LOG_FILE"
  exit 1
fi

# Set HDMI resolution in /boot/config.txt (uncomment and reboot if needed)
# sudo nano /boot/config.txt
# Add: hdmi_group=1, hdmi_mode=16, disable_overscan=1
# Then: sudo reboot

# Function to log messages with color
log_message() {
  echo -e "\033[1;36m🎥 $(date '+%Y-%m-%d %H:%M:%S'): $1\033[0m" | tee -a "$LOG_FILE"
}

# Startup banner
if command -v figlet >/dev/null; then
  figlet "Video Stream ON"
else
  log_message "Starting the video streaming masterpiece on flip.local 🎥"
fi

# Main streaming and display loop with retry logic
FAIL_COUNT=0
MAX_FAILS=5

while [ $FAIL_COUNT -lt $MAX_FAILS ]; do
  log_message "Launching ffmpeg to display locally and stream to $OUTPUT_URL..."

  # FFmpeg command: capture, flip, display locally with sdl2, and stream
  ffmpeg \
    -loglevel debug \
    -i "$INPUT_DEVICE" \
    -f v4l2 \
    -framerate "$FRAMERATE" \
    -video_size "$RESOLUTION" \
    -vf "hflip" \              # Horizontally flip the video
    -c:v libx264 \
    -preset veryfast \
    -b:v "$BITRATE" \
    -fps_mode cfr \
    -f sdl2 "Raspberry Pi Display" \
    -f mpegts "$OUTPUT_URL" \
    2>> "$LOG_FILE"

  # For libcamera (uncomment if using Raspberry Pi Camera Module)
  # libcamera-vid -t 0 --width 1920 --height 1080 --framerate 30 -o - | ffmpeg \
  #   -loglevel debug \
  #   -i pipe: \
  #   -f rawvideo \
  #   -pix_fmt yuv420p \
  #   -vf "hflip" \
  #   -c:v libx264 \
  #   -preset veryfast \
  #   -b:v "$BITRATE" \
  #   -fps_mode cfr \
  #   -f sdl2 "Raspberry Pi Display" \
  #   -f mpegts "$OUTPUT_URL" \
  #   2>> "$LOG_FILE"

  EXIT_CODE=$?
  ((FAIL_COUNT++))
  log_message "ffmpeg exited with code $EXIT_CODE. Retry $FAIL_COUNT/$MAX_FAILS in 5 seconds..."
  sleep 5
done

log_message "Too many failures ($MAX_FAILS), exiting. Check $LOG_FILE for details."
exit 1