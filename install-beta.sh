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

# Get latest beta release and resolve the actual DMG asset name from the API
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases" \
  | python3 -c "
import sys, json
releases = json.load(sys.stdin)
for r in releases:
    if '-beta' in r.get('tag_name', ''):
        print(json.dumps(r))
        break
")

if [ -z "$RELEASE_JSON" ]; then
  echo "Fehler: Konnte Beta-Release nicht ermitteln." >&2
  exit 1
fi

VERSION=$(echo "$RELEASE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")

# Find the DMG asset for the correct architecture
URL=$(echo "$RELEASE_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
arch = '$TAURI_ARCH'
for asset in data.get('assets', []):
    name = asset['name']
    if name.endswith('.dmg') and arch in name:
        print(asset['browser_download_url'])
        break
")

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
