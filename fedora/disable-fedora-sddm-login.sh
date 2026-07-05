#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

FILE=/etc/pam.d/sddm

if [[ -f "$FILE.fedora-touchid-pam.bak" ]]; then
  install -m 0644 -o root -g root "$FILE.fedora-touchid-pam.bak" "$FILE"
  echo "Restored: $FILE"
  exit 0
fi

if [[ -f "$FILE" ]] && grep -q "fedora-touchid-pam: begin" "$FILE"; then
  tmp="$(mktemp)"
  awk '
    /fedora-touchid-pam: begin/ { skip = 1; next }
    /fedora-touchid-pam: end/ { skip = 0; next }
    !skip { print }
  ' "$FILE" > "$tmp"
  install -m 0644 -o root -g root "$tmp" "$FILE"
  rm -f "$tmp"
  echo "Removed hook from: $FILE"
else
  echo "No SDDM login hook found"
fi
