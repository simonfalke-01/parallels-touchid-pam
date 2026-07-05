#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

FILES=(/etc/pam.d/kde /etc/pam.d/kscreensaver /etc/pam.d/kcheckpass)

for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing PAM file: $file" >&2
    exit 1
  fi

  if grep -q "fedora-touchid-pam: begin" "$file"; then
    echo "Already enabled: $file"
    continue
  fi

  cp -a "$file" "$file.fedora-touchid-pam.bak"
  tmp="$(mktemp)"
  awk '
    NR == 1 && /^#%PAM/ {
      print
      print "# fedora-touchid-pam: begin"
      print "auth       sufficient   pam_exec.so quiet seteuid /usr/local/libexec/fedora-touchid-pam"
      print "# fedora-touchid-pam: end"
      next
    }
    NR == 1 {
      print "# fedora-touchid-pam: begin"
      print "auth       sufficient   pam_exec.so quiet seteuid /usr/local/libexec/fedora-touchid-pam"
      print "# fedora-touchid-pam: end"
      print
      next
    }
    { print }
  ' "$file" > "$tmp"
  install -m 0644 -o root -g root "$tmp" "$file"
  rm -f "$tmp"
  echo "Enabled: $file"
done
