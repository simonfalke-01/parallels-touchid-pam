# Architecture

## Flow

1. A PAM-enabled program in Fedora asks to authenticate a user.
2. PAM runs:

   ```text
   pam_exec.so quiet seteuid /usr/local/libexec/fedora-touchid-pam
   ```

3. The setuid wrapper executes the Python helper as root with a sanitized environment.
4. The Python helper reads `/etc/fedora-touchid-pam/secret`.
5. It writes a JSON request under `bridge/requests/`.
6. The macOS LaunchAgent sees the request, verifies its HMAC, and calls Apple LocalAuthentication.
7. macOS shows a Touch ID prompt.
8. The helper writes a signed response under `bridge/responses/`.
9. The Fedora helper verifies the response HMAC and exits `0` for success or nonzero for fallback/failure.
10. PAM accepts the `sufficient` module on success or continues to password auth on failure.

## Runtime Files

Runtime files are deliberately ignored by git:

- `bridge/requests/`
- `bridge/responses/`
- `bridge/processed/`
- `bridge/state/heartbeat`
- `provisioning/fedora-touchid-pam.env`

The provisioning file is one-time setup material. The Fedora installer creates it; the macOS installer imports it and removes it.

## HMAC Protocol

Fedora request fields include:

- `id`
- `user`
- `service`
- `tty`
- `host`
- `timestamp`
- `nonce`
- `request_hmac`

The HMAC is SHA-256 over a stable newline-separated message. The macOS helper verifies it before prompting Touch ID.

macOS response fields include:

- `id`
- `status`
- `timestamp`
- `request_hmac`
- `response_hmac`

The Fedora helper verifies:

- response HMAC
- matching request ID
- echoed request HMAC
- fresh timestamp

## Heartbeat

The macOS LaunchAgent writes `bridge/state/heartbeat` every poll loop. Fedora refuses Touch ID if the heartbeat is missing or older than `HEARTBEAT_MAX_AGE_SECONDS`.

This prevents slow PAM prompts when the macOS helper is not running.

## Why a setuid Wrapper Exists

`sudo` and polkit run PAM helpers with enough privilege to read root-only files. KDE lock/unlock does not; its PAM flow can run as the desktop user. Without a wrapper, KDE unlock cannot read `/etc/fedora-touchid-pam/secret`, and the bridge fails before it can create a request.

The wrapper is intentionally small. It:

- becomes uid/gid 0,
- preserves only PAM variables needed by the Python helper,
- sets a minimal `PATH`,
- runs Python in isolated mode with `-I`,
- executes `/usr/local/libexec/fedora-touchid-pam.py`.

## PAM Services

Installed hooks:

- `sudo`: CLI sudo.
- `polkit-1`: KDE/system desktop authorization prompts.
- `kde`: KDE lock/unlock on Fedora KDE.
- `kscreensaver`, `kcheckpass`: compatibility lock-screen services.
- `sddm`: graphical login.

Do not modify `sddm-greeter`; that service only starts the greeter and is not user authentication.
