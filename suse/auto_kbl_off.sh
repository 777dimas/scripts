#!/bin/bash

export DISPLAY=:0
export XAUTHORITY=/home/db/.Xauthority

TIMEOUT=30

turn_on_backlight() {
    echo 1 | sudo tee /sys/class/leds/tpacpi::kbd_backlight/brightness > /dev/null
}

turn_off_backlight() {
    echo 0 | sudo tee /sys/class/leds/tpacpi::kbd_backlight/brightness > /dev/null
}

while true; do
    idle_time=$(xprintidle)
    idle_seconds=$((idle_time / 1000))

    if [ "$idle_seconds" -ge "$TIMEOUT" ]; then
        turn_off_backlight
    else
        turn_on_backlight
    fi

    sleep 1
done

