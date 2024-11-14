#!/bin/bash

while true; do
    power_source=$(upower -i $(upower -e | grep BAT) | grep "state" | awk '{print $2}')

    if [ "$power_source" = "charging" ] || [ "$power_source" = "fully-charged" ]; then
        cpupower frequency-set -g performance
#	cpupower frequency-set -u 4.7GHz
    else
        cpupower frequency-set -g powersave
        cpupower frequency-set -u 1.4GHz
    fi

    sleep 5
done

