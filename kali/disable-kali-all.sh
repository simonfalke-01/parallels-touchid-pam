#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$PROJECT_DIR/linux/disable-sddm-login.sh" || true
"$PROJECT_DIR/linux/disable-kde-lock.sh" || true
"$PROJECT_DIR/linux/disable-polkit.sh" || true
"$PROJECT_DIR/linux/disable-sudo.sh" || true
echo "Kali Touch ID PAM hooks disabled where present."
