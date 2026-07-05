#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

FILES=(/etc/pam.d/kde /etc/pam.d/kscreensaver /etc/pam.d/kcheckpass)

for file in "${FILES[@]}"; do
  if [[ -f "$file.fedora-touchid-pam.bak" ]]; then
    install -m 0644 -o root -g root "$file.fedora-touchid-pam.bak" "$file"
    echo "Restored: $file"
    continue
  fi

  if [[ -f "$file" ]] && grep -q "fedora-touchid-pam: begin" "$file"; then
    tmp="$(mktemp)"
    awk '
      /fedora-touchid-pam: begin/ { skip = 1; next }
      /fedora-touchid-pam: end/ { skip = 0; next }
      !skip { print }
    ' "$file" > "$tmp"
    install -m 0644 -o root -g root "$tmp" "$file"
    rm -f "$tmp"
    echo "Removed hook from: $file"
  else
    echo "No hook found: $file"
  fi
done
