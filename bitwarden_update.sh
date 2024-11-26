#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Run script as root"
  exit 1
fi

BW_URL="https://vault.bitwarden.com/download/?app=desktop&platform=linux"

echo "Lens download URL: $BW_URL"
wget -O /tmp/Bitwarden-2024-x86_64.AppImage "$BW_URL"

chmod +x /tmp/Bitwarden-2024-x86_64.AppImage

sudo mv /tmp/Bitwarden-2024-x86_64.AppImage /usr/sbin/bitwarden

echo "BW has been updated!"
