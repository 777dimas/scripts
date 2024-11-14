#!/bin/bash

DEVICE_MAC="F4:16:13:63:67:46"

ADAPTER="hci0"

bluetoothctl power on

is_connected() {
    bluetoothctl info $DEVICE_MAC | grep -q "Connected: yes"
}

connect_device() {
    echo "Connecting to $DEVICE_MAC..."
    bluetoothctl connect $DEVICE_MAC
}

while true; do
    if ! is_connected; then
        echo "Device not connected. Trying to connect..."
        connect_device
        sleep 5
    else
        echo "Device is already connected."
    fi
    sleep 10
done

