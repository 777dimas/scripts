#!/bin/bash
set -e

# Define installation paths
INSTALL_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
DESKTOP_DIR="$HOME/.local/share/applications"

APPIMAGE_PATH="$INSTALL_DIR/signal-desktop.AppImage"
ICON_PATH="$ICON_DIR/signal-desktop.png"
DESKTOP_PATH="$DESKTOP_DIR/signal-desktop.desktop"

# Create target directories
mkdir -p "$INSTALL_DIR" "$ICON_DIR" "$DESKTOP_DIR"

# Create a temporary directory for downloads
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

echo "🔍 [1/5] Downloading Signal AppImage, public key, and signature..."
curl -L -O https://updates.signal.org/desktop/signal-desktop.AppImage
curl -s -o signal-appimage.asc https://updates.signal.org/static/desktop/appimage.asc
curl -L -O https://updates.signal.org/desktop/signal-desktop.AppImage.gpg

echo "🔐 [2/5] Verifying GPG signature..."
gpg --import signal-appimage.asc > /dev/null 2>&1
if gpg --verify signal-desktop.AppImage.gpg signal-desktop.AppImage; then
    echo "✅ Signature verified successfully!"
else
    echo "❌ Error: GPG signature verification failed! Download aborted."
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "🚀 [3/5] Installing AppImage..."
chmod +x signal-desktop.AppImage
mv signal-desktop.AppImage "$APPIMAGE_PATH"

echo "🖼️ [4/5] Downloading Signal icon..."
curl -L -s -o "$ICON_PATH" https://raw.githubusercontent.com/signalapp/Signal-Desktop/development/build/icons/png/512x512.png

echo "📝 [5/5] Creating application desktop shortcut..."
cat <<EOF > "$DESKTOP_PATH"
[Desktop Entry]
Name=Signal
Comment=Private Messaging Application
Exec=$APPIMAGE_PATH %U
Icon=$ICON_PATH
Type=Application
StartupWMClass=Signal
Categories=Network;InstantMessaging;Chat;
Terminal=false
MimeType=x-scheme-handler/sgnl;x-scheme-handler/signal;
EOF

chmod +x "$DESKTOP_PATH"

# Clean up temporary files
rm -rf "$TMP_DIR"

echo "Signal has been updated"
