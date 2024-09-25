#!/bin/bash

# Terraform Update Script
# Description: This script updates Terraform to the latest version for Linux (amd64).
# If necessary add script to cron

TERRAFORM_BIN="/usr/local/bin/terraform"
GITHUB_API_URL="https://api.github.com/repos/hashicorp/terraform/releases/latest"
TMP_DIR="/tmp"

if ! command -v curl &> /dev/null; then
    echo "curl is required but not installed. Please install curl!"
    exit 1
fi

if ! command -v unzip &> /dev/null; then
    echo "unzip is required but not installed. Please install unzip!"
    exit 1
fi

LATEST_VERSION=$(curl -s $GITHUB_API_URL | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to fetch the latest version information. Exiting."
    exit 1
fi

DOWNLOAD_URL="https://releases.hashicorp.com/terraform/$LATEST_VERSION/terraform_${LATEST_VERSION}_linux_amd64.zip"

if [ -f "$TERRAFORM_BIN" ]; then
    CURRENT_VERSION=$($TERRAFORM_BIN -v | head -n 1 | sed 's/Terraform v//')
else
    CURRENT_VERSION="0.0.0"
fi

if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
    echo "Terraform is already up-to-date (v$LATEST_VERSION)."
    exit 0
fi

echo "Downloading Terraform v$LATEST_VERSION to $TMP_DIR..."
curl -Lo "$TMP_DIR/terraform_${LATEST_VERSION}_linux_amd64.zip" "$DOWNLOAD_URL" || { echo "Failed to download Terraform. Exiting."; exit 1; }

if [ ! -f "$TMP_DIR/terraform_${LATEST_VERSION}_linux_amd64.zip" ]; then
    echo "Download failed or file not found. Exiting."
    exit 1
fi

echo "Unzipping the Terraform archive..."
unzip -o "$TMP_DIR/terraform_${LATEST_VERSION}_linux_amd64.zip" -d "$TMP_DIR" || { echo "Failed to unzip the file. Exiting."; exit 1; }

echo "Installing Terraform..."
sudo mv "$TMP_DIR/terraform" "$TERRAFORM_BIN" || { echo "Failed to move the new Terraform binary to $TERRAFORM_BIN. Exiting."; exit 1; }
sudo chmod +x "$TERRAFORM_BIN"

echo "Cleaning up temporary files..."
rm "$TMP_DIR/terraform_${LATEST_VERSION}_linux_amd64.zip"

NEW_VERSION=$($TERRAFORM_BIN -v | head -n 1 | sed 's/Terraform v//')
if [ "$NEW_VERSION" == "$LATEST_VERSION" ]; then
    echo "Terraform successfully updated to v$NEW_VERSION."
else
    echo "Failed to update Terraform."
    exit 1
fi

exit 0

