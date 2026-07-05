#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE_DIR="$PROJECT_DIR/bridge"
APP_SUPPORT="$HOME/Library/Application Support/ParallelsTouchIDPAM"
BIN="$APP_SUPPORT/parallels-touchid-helper"
CONFIG_DIR="$APP_SUPPORT/config.d"
PLIST="$HOME/Library/LaunchAgents/com.parallels-touchid-pam.helper.plist"

PROVISIONING_FILE=""
for candidate in \
  "$PROJECT_DIR/provisioning/parallels-touchid-pam.env" \
  "$PROJECT_DIR/provisioning/fedora-touchid-pam.env"; do
  if [[ -f "$candidate" ]]; then
    PROVISIONING_FILE="$candidate"
    break
  fi
done

if [[ -z "$PROVISIONING_FILE" ]]; then
  echo "Missing provisioning file under: $PROJECT_DIR/provisioning" >&2
  echo "Run the VM-side install first, for example:" >&2
  echo "  ./linux/install-linux-sudo.sh" >&2
  exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc is missing. Install Xcode Command Line Tools first:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$PROVISIONING_FILE"

VM_NAME="${VM_NAME:-${FEDORA_HOST:-${VM_HOST:-$(basename "$PROJECT_DIR")}}}"
VM_ID="${VM_ID:-$(printf '%s' "$VM_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/^$/vm/')}"
CONFIG="$CONFIG_DIR/$VM_ID.env"

mkdir -p "$APP_SUPPORT" "$CONFIG_DIR" "$HOME/Library/LaunchAgents" "$BRIDGE_DIR/requests" "$BRIDGE_DIR/responses" "$BRIDGE_DIR/processed" "$BRIDGE_DIR/state"
swiftc "$PROJECT_DIR/macos/ParallelsTouchIDHelper.swift" \
  -framework Foundation \
  -framework LocalAuthentication \
  -framework CryptoKit \
  -o "$BIN"
chmod 0700 "$BIN"

cat > "$CONFIG" <<EOF
VM_NAME=$VM_NAME
VM_ID=$VM_ID
BRIDGE_DIR=$BRIDGE_DIR
SECRET_HEX=$SECRET_HEX
ALLOWED_USERS=${ALLOWED_USERS:-}
EOF
chmod 0600 "$CONFIG"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.parallels-touchid-pam.helper</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
    <string>$CONFIG_DIR</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$APP_SUPPORT/helper.log</string>
  <key>StandardErrorPath</key>
  <string>$APP_SUPPORT/helper.err</string>
</dict>
</plist>
EOF
chmod 0644 "$PLIST"

launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/com.parallels-touchid-pam.helper"

rm -f "$PROVISIONING_FILE"

echo "macOS Parallels Touch ID helper installed and started."
echo "Imported VM config: $CONFIG"
echo "Bridge: $BRIDGE_DIR"
echo "Logs:"
echo "  $APP_SUPPORT/helper.log"
echo "  $APP_SUPPORT/helper.err"
echo
echo "This generic helper can monitor multiple VMs. Run this installer once from each VM's shared-folder project copy."
echo "After importing the Fedora VM into this helper, you may remove the old single-VM Fedora LaunchAgent with:"
echo "  launchctl bootout gui/$(id -u) \"\$HOME/Library/LaunchAgents/com.fedora-touchid-pam.helper.plist\" 2>/dev/null || true"
echo "  rm -f \"\$HOME/Library/LaunchAgents/com.fedora-touchid-pam.helper.plist\""
