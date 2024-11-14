#!/bin/bash
# Example: ./alarm.sh 07:40

if [ -z "$1" ]; then
    echo "Usage: $0 <time>"
    echo "Example: $0 07:40"
    exit 1
fi

TIME_ARG="$1"

FULL_TIME="$TIME_ARG tomorrow"

sudo rtcwake -m mem -t $(date +%s -d "$FULL_TIME")

sleep 60

bluetoothctl connect F4:16:13:63:67:46;

DISPLAY=:0 mpv https://online.kissfm.ua/KissFM_Digital_HD


