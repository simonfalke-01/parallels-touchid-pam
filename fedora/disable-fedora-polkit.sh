#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

DEST=/etc/pam.d/polkit-1

if [[ -f "$DEST.fedora-touchid-pam.preexisting.bak" ]]; then
  install -m 0644 -o root -g root "$DEST.fedora-touchid-pam.preexisting.bak" "$DEST"
  echo "Restored preexisting $DEST"
elif [[ -f "$DEST" ]] && grep -q "fedora-touchid-pam: begin" "$DEST"; then
  rm -f "$DEST"
  echo "Removed $DEST override; Fedora will use /usr/lib/pam.d/polkit-1"
else
  echo "No Fedora polkit Touch ID override found"
fi
