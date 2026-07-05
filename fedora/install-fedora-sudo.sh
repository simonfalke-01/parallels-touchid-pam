#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE_DIR="$PROJECT_DIR/bridge"
PROVISIONING_DIR="$PROJECT_DIR/provisioning"
PROVISIONING_FILE="$PROVISIONING_DIR/fedora-touchid-pam.env"
FEDORA_USER="${SUDO_USER:-${USER:-}}"

if [[ -z "$FEDORA_USER" || "$FEDORA_USER" == root ]]; then
  FEDORA_USER="$(id -un 1000 2>/dev/null || true)"
fi
if [[ -z "$FEDORA_USER" ]]; then
  echo "Unable to determine Fedora desktop user" >&2
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  exec pkexec bash "$0" "$@"
fi

install -d -m 0755 /etc/fedora-touchid-pam
install -d -m 0755 /usr/local/libexec
install -m 0755 "$PROJECT_DIR/fedora/fedora-touchid-pam" /usr/local/libexec/fedora-touchid-pam.py
gcc -O2 -Wall -Wextra "$PROJECT_DIR/fedora/fedora-touchid-pam-wrapper.c" -o /usr/local/libexec/fedora-touchid-pam
chown root:root /usr/local/libexec/fedora-touchid-pam /usr/local/libexec/fedora-touchid-pam.py
chmod 4755 /usr/local/libexec/fedora-touchid-pam
chmod 0755 /usr/local/libexec/fedora-touchid-pam.py

if [[ ! -f /etc/fedora-touchid-pam/secret ]]; then
  openssl rand -hex 32 > /etc/fedora-touchid-pam/secret
  chmod 0600 /etc/fedora-touchid-pam/secret
fi
chown root:root /etc/fedora-touchid-pam/secret
chmod 0600 /etc/fedora-touchid-pam/secret

install -d -m 0755 "$BRIDGE_DIR" "$BRIDGE_DIR/requests" "$BRIDGE_DIR/responses" "$BRIDGE_DIR/processed" "$BRIDGE_DIR/state"
install -d -m 0700 "$PROVISIONING_DIR"
chown -R "$FEDORA_USER":"$FEDORA_USER" "$BRIDGE_DIR" "$PROVISIONING_DIR" 2>/dev/null || true

cat > /etc/fedora-touchid-pam/config <<EOF
BRIDGE_DIR=$BRIDGE_DIR
ALLOWED_USERS=$FEDORA_USER
TIMEOUT_SECONDS=45
HEARTBEAT_MAX_AGE_SECONDS=20
PROVISIONING_FILE=$PROVISIONING_FILE
EOF
chmod 0644 /etc/fedora-touchid-pam/config
chown root:root /etc/fedora-touchid-pam/config

cat > "$PROVISIONING_FILE" <<EOF
SECRET_HEX=$(cat /etc/fedora-touchid-pam/secret)
ALLOWED_USERS=$FEDORA_USER
FEDORA_HOST=$(hostname)
EOF
chmod 0600 "$PROVISIONING_FILE"
chown "$FEDORA_USER":"$FEDORA_USER" "$PROVISIONING_FILE" 2>/dev/null || true

SUDO_PAM=/etc/pam.d/sudo
if ! grep -q "fedora-touchid-pam: begin" "$SUDO_PAM"; then
  cp -a "$SUDO_PAM" "$SUDO_PAM.fedora-touchid-pam.bak"
  tmp="$(mktemp)"
  awk '
    NR == 1 {
      print
      print "# fedora-touchid-pam: begin"
      print "auth       sufficient   pam_exec.so quiet seteuid /usr/local/libexec/fedora-touchid-pam"
      print "# fedora-touchid-pam: end"
      next
    }
    { print }
  ' "$SUDO_PAM" > "$tmp"
  install -m 0644 -o root -g root "$tmp" "$SUDO_PAM"
  rm -f "$tmp"
fi

echo "Fedora sudo hook installed."
echo "Touch ID remains disabled until the macOS installer imports and removes:"
echo "  $PROVISIONING_FILE"
echo
echo "Status:"
/usr/local/libexec/fedora-touchid-pam --status || true
