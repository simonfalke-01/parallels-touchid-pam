#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "$PROJECT_DIR/linux/common.sh"

rerun_as_root "$@"

if [[ -f /etc/pam.d/polkit-1.parallels-touchid-pam.bak ]]; then
  remove_pam_hook /etc/pam.d/polkit-1
elif [[ -f /etc/pam.d/polkit-1 ]] && grep -qF "$PAM_MARKER_BEGIN" /etc/pam.d/polkit-1; then
  if [[ -f /usr/lib/pam.d/polkit-1 ]]; then
    rm -f /etc/pam.d/polkit-1
    echo "Removed Fedora-style polkit override; vendor file remains /usr/lib/pam.d/polkit-1"
  else
    remove_pam_hook /etc/pam.d/polkit-1
  fi
else
  echo "No polkit hook found"
fi
