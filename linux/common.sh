#!/usr/bin/env bash

PAM_MARKER_BEGIN="# parallels-touchid-pam: begin"
PAM_MARKER_END="# parallels-touchid-pam: end"
PAM_HOOK_LINE="auth       sufficient   pam_exec.so quiet seteuid /usr/local/libexec/parallels-touchid-pam"

rerun_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  fi
  if command -v pkexec >/dev/null 2>&1; then
    exec pkexec env VM_NAME="${VM_NAME:-}" VM_ID="${VM_ID:-}" bash "$0" "$@"
  fi
  exec sudo env VM_NAME="${VM_NAME:-}" VM_ID="${VM_ID:-}" bash "$0" "$@"
}

detect_default_user() {
  local user="${SUDO_USER:-${USER:-}}"
  if [[ -z "$user" || "$user" == root ]]; then
    user="$(id -un 1000 2>/dev/null || true)"
  fi
  if [[ -z "$user" ]]; then
    echo "Unable to determine desktop user" >&2
    return 1
  fi
  printf '%s\n' "$user"
}

sanitize_id() {
  tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//' \
    | sed -E 's/^$/vm/'
}

ensure_linux_deps() {
  local missing=()
  for cmd in python3 gcc openssl; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if ((${#missing[@]})); then
    echo "Missing required commands: ${missing[*]}" >&2
    echo "On Kali/Debian, install them with:" >&2
    echo "  sudo apt update && sudo apt install -y python3 gcc libc6-dev openssl" >&2
    return 1
  fi
}

install_pam_hook_after_first_line() {
  local file="$1"
  [[ -f "$file" ]] || { echo "Missing PAM file: $file" >&2; return 1; }
  if grep -qF "$PAM_MARKER_BEGIN" "$file"; then
    echo "Already enabled: $file"
    return 0
  fi

  cp -a "$file" "$file.parallels-touchid-pam.bak"
  local tmp
  tmp="$(mktemp)"
  awk -v begin="$PAM_MARKER_BEGIN" -v hook="$PAM_HOOK_LINE" -v end="$PAM_MARKER_END" '
    NR == 1 {
      print
      print begin
      print hook
      print end
      next
    }
    { print }
  ' "$file" > "$tmp"
  install -m 0644 -o root -g root "$tmp" "$file"
  rm -f "$tmp"
  echo "Enabled: $file"
}

install_pam_hook_before_auth() {
  local file="$1"
  [[ -f "$file" ]] || { echo "Missing PAM file: $file" >&2; return 1; }
  if grep -qF "$PAM_MARKER_BEGIN" "$file"; then
    echo "Already enabled: $file"
    return 0
  fi

  cp -a "$file" "$file.parallels-touchid-pam.bak"
  local tmp
  tmp="$(mktemp)"
  awk -v begin="$PAM_MARKER_BEGIN" -v hook="$PAM_HOOK_LINE" -v end="$PAM_MARKER_END" '
    /^auth[[:space:]]/ && !inserted {
      print begin
      print hook
      print end
      inserted = 1
    }
    { print }
    END { if (!inserted) exit 42 }
  ' "$file" > "$tmp" || {
    local status=$?
    rm -f "$tmp"
    if [[ "$status" -eq 42 ]]; then
      echo "Unable to find auth insertion point in $file" >&2
    fi
    return "$status"
  }
  install -m 0644 -o root -g root "$tmp" "$file"
  rm -f "$tmp"
  echo "Enabled: $file"
}

install_pam_hook_for_sddm() {
  local file="$1"
  [[ -f "$file" ]] || { echo "Missing PAM file: $file" >&2; return 1; }
  if grep -qF "$PAM_MARKER_BEGIN" "$file"; then
    echo "Already enabled: $file"
    return 0
  fi

  cp -a "$file" "$file.parallels-touchid-pam.bak"
  local tmp
  tmp="$(mktemp)"
  awk -v begin="$PAM_MARKER_BEGIN" -v hook="$PAM_HOOK_LINE" -v end="$PAM_MARKER_END" '
    /pam_selinux_permit\.so/ && !inserted {
      print
      print begin
      print hook
      print end
      inserted = 1
      next
    }
    /^auth[[:space:]]/ && !inserted {
      print begin
      print hook
      print end
      inserted = 1
    }
    { print }
    END { if (!inserted) exit 42 }
  ' "$file" > "$tmp" || {
    local status=$?
    rm -f "$tmp"
    if [[ "$status" -eq 42 ]]; then
      echo "Unable to find SDDM insertion point in $file" >&2
    fi
    return "$status"
  }
  install -m 0644 -o root -g root "$tmp" "$file"
  rm -f "$tmp"
  echo "Enabled: $file"
}

remove_pam_hook() {
  local file="$1"
  local backup="$file.parallels-touchid-pam.bak"
  if [[ -f "$backup" ]]; then
    install -m 0644 -o root -g root "$backup" "$file"
    echo "Restored: $file"
    return 0
  fi
  if [[ -f "$file" ]] && grep -qF "$PAM_MARKER_BEGIN" "$file"; then
    local tmp
    tmp="$(mktemp)"
    awk -v begin="$PAM_MARKER_BEGIN" -v end="$PAM_MARKER_END" '
      $0 == begin { skip = 1; next }
      $0 == end { skip = 0; next }
      !skip { print }
    ' "$file" > "$tmp"
    install -m 0644 -o root -g root "$tmp" "$file"
    rm -f "$tmp"
    echo "Removed hook from: $file"
  else
    echo "No hook found: $file"
  fi
}

write_pam_service_with_hook() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"

  {
    echo "#%PAM-1.0"
    echo "$PAM_MARKER_BEGIN"
    echo "$PAM_HOOK_LINE"
    echo "$PAM_MARKER_END"
    echo
    if [[ -f /etc/pam.d/common-auth ]]; then
      echo "@include common-auth"
      echo "@include common-account"
      echo "@include common-password"
      echo "@include common-session"
    elif [[ -f /etc/pam.d/system-auth || -f /usr/lib/pam.d/system-auth ]]; then
      echo "auth       include      system-auth"
      echo "account    include      system-auth"
      echo "password   include      system-auth"
      echo "session    include      system-auth"
    else
      echo "Unable to identify PAM include stack" >&2
      rm -f "$tmp"
      return 1
    fi
  } > "$tmp"

  install -m 0644 -o root -g root "$tmp" "$file"
  rm -f "$tmp"
  echo "Created PAM service with Touch ID hook: $file"
}
