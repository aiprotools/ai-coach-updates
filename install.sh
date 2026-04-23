#!/bin/bash
set -e

REPO="aiprotools/ai-coach-updates"
INSTALL_DIR="/Applications"
APP_NAME="AI Coach"

echo "AI Coach — Installer"
echo "Lade aktuelle Version..."

VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
if [ -z "$VERSION" ]; then
  echo "Fehler: Konnte Version nicht ermitteln." >&2
  exit 1
fi

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  TAURI_ARCH="aarch64"
else
  TAURI_ARCH="x86_64"
fi

VERSION_NUM="${VERSION#v}"
DMG_NAME="AI.Coach_${VERSION_NUM}_${TAURI_ARCH}.dmg"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${DMG_NAME}"

echo "Version: ${VERSION} (${TAURI_ARCH})"
echo "Download: ${URL}"

TMP_DMG="/tmp/${DMG_NAME}"
curl -L --progress-bar "$URL" -o "$TMP_DMG"

echo "Mounte DMG..."
MOUNT_POINT=$(hdiutil attach "$TMP_DMG" -nobrowse -noautoopen -plist | python3 -c "
import sys, plistlib
d = plistlib.load(sys.stdin.buffer)
for e in d.get('system-entities', []):
    if 'mount-point' in e:
        print(e['mount-point'])
        break
")

if [ -z "$MOUNT_POINT" ]; then
  echo "Fehler: DMG konnte nicht gemountet werden." >&2
  exit 1
fi

echo "Gemountet unter: $MOUNT_POINT"
echo "Installiere nach ${INSTALL_DIR}..."
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi
cp -r "${MOUNT_POINT}/${APP_NAME}.app" "${INSTALL_DIR}/"

echo "Entferne Gatekeeper-Quarantäne..."
xattr -cr "${INSTALL_DIR}/${APP_NAME}.app"

hdiutil detach "$MOUNT_POINT" -quiet
rm "$TMP_DMG"

echo ""
echo "✓ AI Coach ${VERSION} wurde erfolgreich installiert."
echo "  Starte die App aus dem Launchpad oder aus /Applications."
open "${INSTALL_DIR}/${APP_NAME}.app"
