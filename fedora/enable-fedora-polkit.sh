#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

DEST=/etc/pam.d/polkit-1
VENDOR=/usr/lib/pam.d/polkit-1

if [[ ! -f "$VENDOR" ]]; then
  echo "Missing vendor polkit PAM file: $VENDOR" >&2
  exit 1
fi

if [[ -f "$DEST" ]] && ! grep -q "fedora-touchid-pam: begin" "$DEST"; then
  cp -a "$DEST" "$DEST.fedora-touchid-pam.preexisting.bak"
fi

cat > "$DEST" <<'EOF'
#%PAM-1.0
# fedora-touchid-pam: begin
auth       sufficient   pam_exec.so quiet seteuid /usr/local/libexec/fedora-touchid-pam
# fedora-touchid-pam: end

auth       include      system-auth
account    include      system-auth
password   include      system-auth
session    include      system-auth
EOF

chmod 0644 "$DEST"
chown root:root "$DEST"

echo "Fedora polkit Touch ID hook enabled at $DEST"
