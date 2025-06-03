#!/bin/bash

# Script to set up Raspberry Pi 4 as a USB Ethernet gadget using configfs

# Load the libcomposite module
sudo modprobe libcomposite

# Mount configfs if not already mounted
if ! mountpoint -q /sys/kernel/config; then
    sudo mount -t configfs none /sys/kernel/config
fi

# Create and configure the USB gadget
cd /sys/kernel/config/usb_gadget
sudo mkdir -p g1
cd g1

# Set USB attributes
echo 0x1d6b | sudo tee idVendor  # Linux Foundation VID
echo 0x0104 | sudo tee idProduct # Multifunction Composite Gadget PID
echo 0x0100 | sudo tee bcdDevice # Version 1.0.0
echo 0x0200 | sudo tee bcdUSB    # USB 2.0

# Create strings
sudo mkdir -p strings/0x409
echo "Raspberry Pi" | sudo tee strings/0x409/manufacturer
echo "USB Ethernet Gadget 360" | sudo tee strings/0x409/product

# Create the Ethernet function (using ecm)
sudo mkdir -p functions/ecm.usb0

# Create a configuration and link the function
sudo mkdir -p configs/c.1
sudo mkdir -p configs/c.1/strings/0x409
echo "Config 1" | sudo tee configs/c.1/strings/0x409/configuration
echo 250 | sudo tee configs/c.1/MaxPower
sudo ln -s functions/ecm.usb0 configs/c.1

# Bind to the UDC
UDC=$(ls /sys/class/udc | head -n 1)
echo $UDC | sudo tee UDC

# Configure network settings
sudo ip addr add 192.168.7.2/24 dev usb0
sudo ip link set usb0 up

echo "USB Ethernet gadget setup complete."
