#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VM_NAME="${VM_NAME:-kali}"
exec "$PROJECT_DIR/linux/install-linux-sudo.sh" "$@"
