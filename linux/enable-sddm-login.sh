#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "$PROJECT_DIR/linux/common.sh"

rerun_as_root "$@"
install_pam_hook_for_sddm /etc/pam.d/sddm
echo "Note: logging in with Touch ID does not supply your VM password, so KWallet may still ask to unlock."
