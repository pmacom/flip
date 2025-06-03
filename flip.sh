#!/bin/bash

# Script to flip the connected display horizontally on Raspberry Pi
# Usage: ./flip_display.sh [output_name]
# If output_name is provided, it will flip that specific output.
# If not, it will automatically detect the first connected output.

# Check if DISPLAY is set, if not, set to :0
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi

# Check if X server is accessible
xset -q > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Cannot connect to X server. Please run this script from the desktop environment."
    exit 1
fi

# Determine the output to flip
if [ $# -eq 1 ]; then
    CONNECTED_OUTPUT=$1
elif [ $# -eq 0 ]; then
    CONNECTED_OUTPUT=$(xrandr | grep " connected" | awk '{print $1}' | head -n 1)
else
    echo "Usage: $0 [output_name]"
    exit 1
fi

# Check if the output is connected
if ! xrandr | grep -q "^$CONNECTED_OUTPUT connected"; then
    echo "Error: Specified output $CONNECTED_OUTPUT is not connected."
    exit 1
fi

# Apply horizontal flip
echo "Flipping display: $CONNECTED_OUTPUT"
xrandr --output "$CONNECTED_OUTPUT" --reflect x
if [ $? -eq 0 ]; then
    echo "Display flipped horizontally successfully."
else
    echo "Error: Failed to flip the display."
    exit 1
fi
