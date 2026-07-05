#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "$PROJECT_DIR/linux/common.sh"

rerun_as_root "$@"

if [[ -f /etc/pam.d/polkit-1 ]]; then
  install_pam_hook_before_auth /etc/pam.d/polkit-1
elif [[ -f /usr/lib/pam.d/polkit-1 ]]; then
  write_pam_service_with_hook /etc/pam.d/polkit-1
else
  echo "Unable to find polkit PAM service file" >&2
  exit 1
fi
