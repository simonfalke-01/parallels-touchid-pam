# Troubleshooting

## Check Overall Status

From Fedora:

```bash
./fedora/status.sh
```

Or directly:

```bash
/usr/local/libexec/fedora-touchid-pam --status
```

Healthy output includes:

```text
heartbeat: ok age=...
provisioning: absent
```

## Fedora Logs

```bash
journalctl -t fedora-touchid-pam --since "10 minutes ago" --no-pager
```

Successful examples:

```text
accepted touchid user='simonfalke' service='sudo'
accepted touchid user='simonfalke' service='polkit-1'
accepted touchid user='simonfalke' service='kde'
```

## macOS Logs

The LaunchAgent writes:

```text
~/Library/Application Support/FedoraTouchIDPAM/helper.log
~/Library/Application Support/FedoraTouchIDPAM/helper.err
```

Check LaunchAgent state:

```bash
launchctl print "gui/$(id -u)/com.fedora-touchid-pam.helper"
```

Restart it:

```bash
launchctl kickstart -k "gui/$(id -u)/com.fedora-touchid-pam.helper"
```

## No Touch ID Prompt

Check:

1. The macOS helper is running.
2. `bridge/state/heartbeat` is fresh.
3. `provisioning/fedora-touchid-pam.env` is absent.
4. The PAM service has the hook.
5. Fedora logs show which PAM service is actually used.

For KDE unlock, Fedora logs showed `pam_unix(kde:auth)`, so the hook had to be added to `/etc/pam.d/kde`.

## `Permission denied: /etc/fedora-touchid-pam/secret`

The setuid wrapper is missing or not mode `4755`.

Fix by rerunning:

```bash
./fedora/install-fedora-sudo.sh
```

Expected file modes:

```bash
ls -l /usr/local/libexec/fedora-touchid-pam /usr/local/libexec/fedora-touchid-pam.py
```

The wrapper should look like:

```text
-rwsr-xr-x root root /usr/local/libexec/fedora-touchid-pam
```

## `heartbeat: missing`

The macOS helper is not running or cannot write to the shared folder.

On macOS:

```bash
./macos/install-macos-helper.sh
launchctl print "gui/$(id -u)/com.fedora-touchid-pam.helper"
```

## `provisioning: present`

The macOS installer has not imported the one-time secret yet. Run:

```bash
./macos/install-macos-helper.sh
```

from macOS in the shared-folder copy.

## Swift Compiler Missing

Install Xcode Command Line Tools:

```bash
xcode-select --install
```

Then rerun:

```bash
./macos/install-macos-helper.sh
```

## SDDM Login Works but KWallet Prompts

Expected. Touch ID does not provide the Fedora password to PAM modules like `pam_kwallet`.

## Disable One Service

See [ROLLBACK.md](ROLLBACK.md).
