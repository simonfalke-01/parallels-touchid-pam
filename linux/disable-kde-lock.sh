#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "$PROJECT_DIR/linux/common.sh"

rerun_as_root "$@"

for file in /etc/pam.d/kde /etc/pam.d/kscreensaver /etc/pam.d/kcheckpass; do
  remove_pam_hook "$file"
done
