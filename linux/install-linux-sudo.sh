#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "$PROJECT_DIR/linux/common.sh"

rerun_as_root "$@"
ensure_linux_deps

VM_USER="$(detect_default_user)"
VM_NAME="${VM_NAME:-$(hostname)}"
VM_ID="${VM_ID:-$(printf '%s' "$VM_NAME" | sanitize_id)}"
BRIDGE_DIR="${BRIDGE_DIR:-$PROJECT_DIR/bridges/$VM_ID}"
PROVISIONING_DIR="$PROJECT_DIR/provisioning"
PROVISIONING_FILE="$PROVISIONING_DIR/parallels-touchid-pam.env"

install -d -m 0755 /etc/parallels-touchid-pam
install -d -m 0755 /usr/local/libexec
install -m 0755 "$PROJECT_DIR/linux/parallels-touchid-pam" /usr/local/libexec/parallels-touchid-pam.py
gcc -O2 -Wall -Wextra "$PROJECT_DIR/linux/parallels-touchid-pam-wrapper.c" -o /usr/local/libexec/parallels-touchid-pam
chown root:root /usr/local/libexec/parallels-touchid-pam /usr/local/libexec/parallels-touchid-pam.py
chmod 4755 /usr/local/libexec/parallels-touchid-pam
chmod 0755 /usr/local/libexec/parallels-touchid-pam.py

if [[ ! -f /etc/parallels-touchid-pam/secret ]]; then
  openssl rand -hex 32 > /etc/parallels-touchid-pam/secret
fi
chown root:root /etc/parallels-touchid-pam/secret
chmod 0600 /etc/parallels-touchid-pam/secret

install -d -m 0755 "$BRIDGE_DIR" "$BRIDGE_DIR/requests" "$BRIDGE_DIR/responses" "$BRIDGE_DIR/processed" "$BRIDGE_DIR/state"
install -d -m 0700 "$PROVISIONING_DIR"
chown -R "$VM_USER":"$VM_USER" "$BRIDGE_DIR" "$PROVISIONING_DIR" 2>/dev/null || true

cat > /etc/parallels-touchid-pam/config <<EOF
BRIDGE_DIR=$BRIDGE_DIR
ALLOWED_USERS=$VM_USER
TIMEOUT_SECONDS=45
HEARTBEAT_MAX_AGE_SECONDS=20
PROVISIONING_FILE=$PROVISIONING_FILE
VM_NAME=$VM_NAME
VM_ID=$VM_ID
EOF
chmod 0644 /etc/parallels-touchid-pam/config
chown root:root /etc/parallels-touchid-pam/config

cat > "$PROVISIONING_FILE" <<EOF
SECRET_HEX=$(cat /etc/parallels-touchid-pam/secret)
ALLOWED_USERS=$VM_USER
VM_NAME=$VM_NAME
VM_ID=$VM_ID
VM_HOST=$(hostname)
BRIDGE_DIR=$BRIDGE_DIR
EOF
chmod 0600 "$PROVISIONING_FILE"
chown "$VM_USER":"$VM_USER" "$PROVISIONING_FILE" 2>/dev/null || true

install_pam_hook_after_first_line /etc/pam.d/sudo

echo "Linux sudo hook installed for $VM_NAME."
echo "Touch ID remains disabled until the macOS installer imports and removes:"
echo "  $PROVISIONING_FILE"
echo
echo "Status:"
/usr/local/libexec/parallels-touchid-pam --status || true
