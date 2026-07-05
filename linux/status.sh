#!/usr/bin/env bash
set -euo pipefail

echo "== Bridge =="
if [[ -x /usr/local/libexec/parallels-touchid-pam ]]; then
  /usr/local/libexec/parallels-touchid-pam --status || true
else
  echo "generic helper wrapper missing: /usr/local/libexec/parallels-touchid-pam"
fi

echo
echo "== Installed files =="
for path in \
  /usr/local/libexec/parallels-touchid-pam \
  /usr/local/libexec/parallels-touchid-pam.py \
  /etc/parallels-touchid-pam/config \
  /etc/parallels-touchid-pam/secret; do
  if [[ -e "$path" ]]; then
    ls -l "$path"
  else
    echo "missing: $path"
  fi
done

echo
echo "== PAM hooks =="
for file in \
  /etc/pam.d/sudo \
  /etc/pam.d/polkit-1 \
  /etc/pam.d/kde \
  /etc/pam.d/kscreensaver \
  /etc/pam.d/kcheckpass \
  /etc/pam.d/sddm; do
  if [[ -f "$file" ]]; then
    if grep -q "parallels-touchid-pam: begin" "$file"; then
      echo "enabled: $file"
    else
      echo "not enabled: $file"
    fi
  else
    echo "missing: $file"
  fi
done

echo
echo "== Recent auth logs =="
journalctl --since "30 minutes ago" -t parallels-touchid-pam --no-pager | tail -n 40 || true
