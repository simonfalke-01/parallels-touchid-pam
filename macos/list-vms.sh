#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/Library/Application Support/ParallelsTouchIDPAM/config.d"

if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "No VM config directory found: $CONFIG_DIR"
  exit 0
fi

for config in "$CONFIG_DIR"/*.env; do
  [[ -e "$config" ]] || { echo "No VM configs found in $CONFIG_DIR"; exit 0; }
  echo "== $config =="
  sed -E 's/^(SECRET_HEX=).+$/\1<redacted>/' "$config"
done
