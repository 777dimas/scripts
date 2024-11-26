#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Run script as root"
  exit 1
fi

WB_URL="https://download.mikrotik.com/routeros/winbox/4.0beta12/WinBox_Linux.zip"

echo "Lens download URL: $BW_URL"
wget -O /tmp/wb.zip "$WB_URL"

cd /tmp; unzip wb.zip
 
chmod +x /tmp/WinBox

sudo mv /tmp/WinBox /usr/sbin/winbox

echo "WB has been updated!"
