#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "$PROJECT_DIR/linux/common.sh"

rerun_as_root "$@"

enabled=0
for file in /etc/pam.d/kde /etc/pam.d/kscreensaver /etc/pam.d/kcheckpass; do
  if [[ -f "$file" ]]; then
    install_pam_hook_before_auth "$file"
    enabled=1
  else
    echo "Skipping missing PAM file: $file"
  fi
done

if [[ "$enabled" -eq 0 ]]; then
  echo "No KDE lock PAM files found" >&2
  exit 1
fi
