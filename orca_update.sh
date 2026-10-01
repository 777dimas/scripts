#!/bin/bash
set -e

# Define installation paths
# Files are named orca-ide to avoid clashing with the GNOME Orca screen reader
INSTALL_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
DESKTOP_DIR="$HOME/.local/share/applications"

APPIMAGE_PATH="$INSTALL_DIR/orca-ide.AppImage"
ICON_PATH="$ICON_DIR/orca-ide.png"
DESKTOP_PATH="$DESKTOP_DIR/orca-ide.desktop"

RELEASE_URL="https://github.com/stablyai/orca/releases/latest/download"

case "$(uname -m)" in
    x86_64)        APPIMAGE_NAME="orca-linux.AppImage";       MANIFEST="latest-linux.yml" ;;
    aarch64|arm64) APPIMAGE_NAME="orca-linux-arm64.AppImage"; MANIFEST="latest-linux-arm64.yml" ;;
    *) echo "❌ Error: unsupported architecture $(uname -m)"; exit 1 ;;
esac

# Create target directories
mkdir -p "$INSTALL_DIR" "$ICON_DIR" "$DESKTOP_DIR"

# Create a temporary directory for downloads
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
cd "$TMP_DIR"

echo "🔍 [1/5] Downloading Orca AppImage and release manifest..."
curl -fsSL -o "$MANIFEST" "$RELEASE_URL/$MANIFEST"
VERSION=$(awk '/^version:/ {print $2}' "$MANIFEST")
echo "Latest version: $VERSION"
curl -fL -o "$APPIMAGE_NAME" "$RELEASE_URL/$APPIMAGE_NAME"

echo "🔐 [2/5] Verifying SHA512 checksum..."
# The top-level sha512 in the manifest belongs to the AppImage (base64-encoded)
EXPECTED=$(awk '/^sha512:/ {print $2}' "$MANIFEST")
ACTUAL=$(openssl dgst -sha512 -binary "$APPIMAGE_NAME" | base64 -w0)
if [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ]; then
    echo "✅ Checksum verified successfully!"
else
    echo "❌ Error: SHA512 checksum mismatch! Download aborted."
    exit 1
fi

echo "🚀 [3/5] Installing AppImage..."
chmod +x "$APPIMAGE_NAME"
mv "$APPIMAGE_NAME" "$APPIMAGE_PATH"

echo "🖼️ [4/5] Downloading Orca icon..."
curl -fsSL -o "$ICON_PATH" https://raw.githubusercontent.com/stablyai/orca/main/resources/build/icon.png

echo "📝 [5/5] Creating application desktop shortcut..."
cat <<EOF > "$DESKTOP_PATH"
[Desktop Entry]
Name=Orca
Comment=Orca IDE for coding agents
Exec=$APPIMAGE_PATH %U
Icon=$ICON_PATH
Type=Application
StartupWMClass=orca
Categories=Development;Utility;
Terminal=false
MimeType=x-scheme-handler/orca;text/markdown;
EOF

chmod +x "$DESKTOP_PATH"
update-desktop-database "$DESKTOP_DIR" > /dev/null 2>&1 || true

echo "Orca $VERSION has been updated"
