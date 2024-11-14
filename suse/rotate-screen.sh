#!/bin/bash

SCREEN="eDP-1"
TOUCHSCREEN="Wacom HID 5276 Finger touch"

export DISPLAY=:0
export XAUTHORITY=/home/db/.Xauthority

if ! command -v monitor-sensor &> /dev/null; then
    echo "Monitor-sensor not found. First install iio-sensor-proxy."
    exit 1
fi

monitor-sensor | while read -r line; do
    if [[ $line == *"Accelerometer orientation changed:"* ]]; then
        ORIENTATION=$(echo $line | awk '{print $NF}')
        case "$ORIENTATION" in
            normal)
                xrandr --output "$SCREEN" --rotate normal
                xinput set-prop "$TOUCHSCREEN" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
                ;;
            left-up)
                xrandr --output "$SCREEN" --rotate left
                xinput set-prop "$TOUCHSCREEN" "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1
                ;;
            right-up)
                xrandr --output "$SCREEN" --rotate right
                xinput set-prop "$TOUCHSCREEN" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
                ;;
            bottom-up)
                xrandr --output "$SCREEN" --rotate inverted
                xinput set-prop "$TOUCHSCREEN" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
                ;;
        esac
    fi
done

