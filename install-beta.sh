#!/bin/bash
set -e

REPO="aiprotools/ai-coach-updates"
INSTALL_DIR="/Applications"
APP_NAME="AI Coach"
MOUNT_POINT="${HOME}/.ai_coach_install_mount"

echo "AI Coach Beta — Installer"
echo "Lade aktuelle Beta-Version..."

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  TAURI_ARCH="aarch64"
else
  TAURI_ARCH="x86_64"
fi

# Find latest beta release tag
VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases" \
  | grep '"tag_name"' | grep '\-beta' | head -1 \
  | sed 's/.*"tag_name": "\(.*\)".*/\1/')

if [ -z "$VERSION" ]; then
  echo "Fehler: Konnte Beta-Version nicht ermitteln." >&2
  exit 1
fi

# Fetch the specific release and extract the DMG download URL via grep/sed
URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/tags/${VERSION}" \
  | grep '"browser_download_url"' \
  | grep "${TAURI_ARCH}" \
  | grep '\.dmg"' \
  | head -1 \
  | sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

if [ -z "$URL" ]; then
  echo "Fehler: Kein passendes DMG-Asset für ${TAURI_ARCH} gefunden." >&2
  exit 1
fi

DMG_NAME=$(basename "$URL")

echo "Version: ${VERSION} (${TAURI_ARCH})"
echo "Download: ${URL}"

TMP_DMG="${HOME}/${DMG_NAME}"
curl -L --progress-bar "$URL" -o "$TMP_DMG"

echo "Mounte DMG..."
hdiutil detach "$MOUNT_POINT" 2>/dev/null || true
rm -rf "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT"
hdiutil attach "$TMP_DMG" -nobrowse -noautoopen -mountpoint "$MOUNT_POINT" > /dev/null

echo "Installiere nach ${INSTALL_DIR}..."
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi
cp -r "${MOUNT_POINT}/${APP_NAME}.app" "${INSTALL_DIR}/"

echo "Entferne Gatekeeper-Quarantäne..."
xattr -cr "${INSTALL_DIR}/${APP_NAME}.app"

hdiutil detach "$MOUNT_POINT" -quiet
rm -rf "$MOUNT_POINT" "$TMP_DMG"

echo ""
echo "✓ AI Coach Beta ${VERSION} wurde erfolgreich installiert."
echo "  Starte die App aus dem Launchpad oder aus /Applications."
open "${INSTALL_DIR}/${APP_NAME}.app"
