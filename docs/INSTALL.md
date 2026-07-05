# Install Guide

This guide reproduces the Fedora Touch ID PAM bridge on a fresh Parallels Fedora VM.

## Requirements

On macOS:

- A Mac with Touch ID configured.
- Parallels Desktop with a shared folder visible to the Fedora VM.
- Xcode Command Line Tools, for `swiftc`:

  ```bash
  xcode-select --install
  ```

On Fedora:

- Fedora Workstation/KDE or a PAM-based desktop.
- Parallels shared folders mounted under `/media/psf/...`.
- `python3`, `openssl`, `gcc`, `pam_exec`, `sudo`, and `pkexec`.

Fedora 44 already had these packages in the tested VM. If needed:

```bash
sudo dnf install gcc glibc-devel openssl python3
```

## 1. Put the Project in a Shared Folder

The bridge uses files under the project directory for request/response exchange. That directory must be visible to both Fedora and macOS.

If this repo lives in Fedora home as `~/fedora-touchid-pam`, copy it to a Parallels shared folder first:

```bash
rsync -a --delete ~/fedora-touchid-pam/ /media/psf/iCloud/fedora-touchid-pam/
cd /media/psf/iCloud/fedora-touchid-pam
```

Use whatever shared folder exists on the target machine. The exact macOS path must point to the same files.

## 2. Install Fedora Side and `sudo`

From Fedora, in the shared-folder copy:

```bash
./fedora/install-fedora-sudo.sh
```

This script:

- Installs `/usr/local/libexec/fedora-touchid-pam.py`.
- Builds and installs `/usr/local/libexec/fedora-touchid-pam` as a setuid-root wrapper.
- Creates `/etc/fedora-touchid-pam/secret` as a root-only HMAC secret.
- Creates `/etc/fedora-touchid-pam/config`.
- Creates runtime directories under `./bridge/`.
- Creates `./provisioning/fedora-touchid-pam.env` for one-time macOS helper setup.
- Adds a `sudo` PAM hook before `system-auth`.

Touch ID remains disabled until the macOS helper imports and removes the provisioning file.

## 3. Install macOS Helper

Open macOS Terminal in the matching shared-folder path.

For iCloud, the path may be:

```bash
cd "$HOME/Library/Mobile Documents/com~apple~CloudDocs/fedora-touchid-pam"
```

Then run:

```bash
./macos/install-macos-helper.sh
```

This script:

- Compiles `macos/FedoraTouchIDHelper.swift`.
- Installs the binary under `~/Library/Application Support/FedoraTouchIDPAM/`.
- Writes `config.env` with the bridge path, allowed Fedora users, and HMAC secret.
- Installs and starts `~/Library/LaunchAgents/com.fedora-touchid-pam.helper.plist`.
- Removes the one-time provisioning file from the shared folder.

## 4. Test `sudo`

Back in Fedora:

```bash
sudo -k
sudo true
```

Expected result:

- macOS shows a Touch ID prompt.
- Fedora `sudo true` exits successfully.
- Logs show:

  ```text
  accepted touchid user='YOUR_USER' service='sudo'
  ```

Check logs:

```bash
journalctl -t fedora-touchid-pam --since "5 minutes ago" --no-pager
```

## 5. Enable Graphical System Prompts

Enable polkit:

```bash
./fedora/enable-fedora-polkit.sh
```

Test with:

```bash
pkexec true
```

Expected log:

```text
accepted touchid user='YOUR_USER' service='polkit-1'
```

## 6. Enable KDE Lock/Unlock

```bash
./fedora/enable-fedora-kde-lock.sh
```

This covers:

- `/etc/pam.d/kde`
- `/etc/pam.d/kscreensaver`
- `/etc/pam.d/kcheckpass`

On the tested Fedora KDE VM, the real lock-screen auth service was `kde`.

Test:

```bash
loginctl lock-session
```

Unlock the session. Expected log:

```text
accepted touchid user='YOUR_USER' service='kde'
```

## 7. Enable SDDM Login

```bash
./fedora/enable-fedora-sddm-login.sh
```

This inserts the Touch ID hook into `/etc/pam.d/sddm` after `pam_selinux_permit.so` and before `password-auth`.

Test requires logout or reboot. Keep password fallback available.

Note: SDDM Touch ID login does not pass your Fedora password to the session. KWallet may ask for the Fedora password after login.

## 8. Status Check

```bash
./fedora/status.sh
```

It prints:

- Helper/heartbeat status.
- Installed file modes.
- PAM services with hooks.
- Recent auth logs.
