#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <vm-id>" >&2
  exit 2
fi

CONFIG="$HOME/Library/Application Support/ParallelsTouchIDPAM/config.d/$1.env"
if [[ -f "$CONFIG" ]]; then
  rm -f "$CONFIG"
  echo "Removed VM config: $CONFIG"
else
  echo "No such VM config: $CONFIG"
fi
