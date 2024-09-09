#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Run script as root"
  exit 1
fi

LENS_URL="https://api.k8slens.dev/binaries/Lens-2024.8.291605-latest.x86_64.AppImage"

echo "Lens download URL: $LENS_URL"
wget -O /tmp/lens.AppImage "$LENS_URL"

chmod +x /tmp/lens.AppImage

sudo mv /tmp/lens.AppImage /usr/sbin/lens

echo "Lens has been updated!"

