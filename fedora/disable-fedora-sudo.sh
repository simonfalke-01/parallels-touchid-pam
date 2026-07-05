#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec pkexec bash "$0" "$@"
fi

SUDO_PAM=/etc/pam.d/sudo
if grep -q "fedora-touchid-pam: begin" "$SUDO_PAM"; then
  tmp="$(mktemp)"
  awk '
    /fedora-touchid-pam: begin/ { skip = 1; next }
    /fedora-touchid-pam: end/ { skip = 0; next }
    !skip { print }
  ' "$SUDO_PAM" > "$tmp"
  install -m 0644 -o root -g root "$tmp" "$SUDO_PAM"
  rm -f "$tmp"
fi

echo "Fedora sudo hook disabled. Installed helper/config files were left in place."
