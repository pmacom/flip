#!/bin/bash

# Stream video from Raspberry Pi to laptop for horizontal video switching experiment
# Created for the majestic canvas of real-time video art
# Hostname: flip (flip.local), User: flip, Password: flip

# Configuration variables
INPUT_DEVICE="/dev/video0"          # Primary V4L2 device (e.g., USB webcam or v4l2loopback)
# INPUT_DEVICE2="/dev/video1"       # Uncomment for second camera (for hstack)
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

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Banner for the majestic creation
log_message "Starting the video streaming masterpiece on flip.local 🎥"

# Main streaming loop with retry logic
while true; do
  log_message "Launching ffmpeg stream to $OUTPUT_URL..."

  # FFmpeg command for single camera
  ffmpeg \
    -i "$INPUT_DEVICE" \
    -f v4l2 \
    -framerate "$FRAMERATE" \
    -video_size "$RESOLUTION" \
    -c:v libx264 \
    -preset veryfast \
    -b:v "$BITRATE" \
    -fps_mode cfr \
    -f mpegts "$OUTPUT_URL" \
    2>> "$LOG_FILE"

  # For multiple cameras (uncomment to enable horizontal stacking)
  # ffmpeg \
  #   -i "$INPUT_DEVICE" \
  #   -i "$INPUT_DEVICE2" \
  #   -f v4l2 \
  #   -framerate "$FRAMERATE" \
  #   -video_size "$RESOLUTION" \
  #   -filter_complex "[0:v][1:v]hstack=inputs=2[v]" \
  #   -map "[v]" \
  #   -c:v libx264 \
  #   -preset veryfast \
  #   -b:v "$BITRATE" \
  #   -fps_mode cfr \
  #   -f mpegts "$OUTPUT_URL" \
  #   2>> "$LOG_FILE"

  log_message "ffmpeg exited with code $?. Retrying in 5 seconds..."
  sleep 5
done