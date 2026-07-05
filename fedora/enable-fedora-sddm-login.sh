#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

FILE=/etc/pam.d/sddm

if [[ ! -f "$FILE" ]]; then
  echo "Missing PAM file: $FILE" >&2
  exit 1
fi

if grep -q "fedora-touchid-pam: begin" "$FILE"; then
  echo "Already enabled: $FILE"
  exit 0
fi

cp -a "$FILE" "$FILE.fedora-touchid-pam.bak"
tmp="$(mktemp)"
awk '
  /pam_selinux_permit\.so/ && !inserted {
    print
    print "# fedora-touchid-pam: begin"
    print "auth       sufficient   pam_exec.so quiet seteuid /usr/local/libexec/fedora-touchid-pam"
    print "# fedora-touchid-pam: end"
    inserted = 1
    next
  }
  { print }
  END {
    if (!inserted) {
      exit 42
    }
  }
' "$FILE" > "$tmp" || {
  status=$?
  rm -f "$tmp"
  if [[ "$status" -eq 42 ]]; then
    echo "Unable to find pam_selinux_permit.so insertion point in $FILE" >&2
  fi
  exit "$status"
}
install -m 0644 -o root -g root "$tmp" "$FILE"
rm -f "$tmp"

echo "Enabled SDDM login Touch ID hook at $FILE"
echo "Note: logging in with Touch ID does not supply your Fedora password, so KWallet may still ask to unlock."
