#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "$PROJECT_DIR/linux/common.sh"

rerun_as_root "$@"

if [[ -f /etc/pam.d/polkit-1 ]]; then
  install_pam_hook_before_auth /etc/pam.d/polkit-1
elif [[ -f /usr/lib/pam.d/polkit-1 ]]; then
  cat > /etc/pam.d/polkit-1 <<EOF
#%PAM-1.0
$PAM_MARKER_BEGIN
$PAM_HOOK_LINE
$PAM_MARKER_END

auth       include      system-auth
account    include      system-auth
password   include      system-auth
session    include      system-auth
EOF
  chmod 0644 /etc/pam.d/polkit-1
  chown root:root /etc/pam.d/polkit-1
  echo "Created Fedora-style polkit override: /etc/pam.d/polkit-1"
else
  echo "Unable to find polkit PAM service file" >&2
  exit 1
fi
