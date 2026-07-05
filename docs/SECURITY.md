# Security Notes

This bridge is a convenience layer, not biometric hardware passthrough.

## What Touch ID Proves

Touch ID proves that macOS LocalAuthentication accepted the active macOS user. Fedora accepts that result only after verifying a response signed with the shared HMAC secret.

## Secret Handling

Fedora stores the HMAC secret at:

```text
/etc/fedora-touchid-pam/secret
```

It is root-owned and mode `0600`.

The macOS installer stores a copy at:

```text
~/Library/Application Support/FedoraTouchIDPAM/config.env
```

It is mode `0600` under the macOS user account.

The one-time provisioning file is created under `provisioning/` in the shared folder and removed by the macOS installer. The Fedora helper refuses Touch ID while that provisioning file still exists.

## Threat Model

Protected against:

- An unprivileged Fedora process writing fake success responses without the HMAC secret.
- Stale responses being replayed after the timestamp window.
- Slow password prompts when the macOS helper is down, because heartbeat is checked first.

Not protected against:

- A compromised macOS user session.
- A compromised root account on Fedora.
- A malicious process that can read the macOS helper config.
- A malicious process with the ability to replace trusted files in the shared folder and also obtain the HMAC secret.

## setuid Wrapper Risk

The wrapper is setuid root so PAM callers that run as the desktop user can still use the root-only Fedora secret.

The wrapper mitigations are:

- small C code path,
- fixed Python path,
- fixed script path,
- sanitized environment,
- Python isolated mode,
- no shell execution.

If you do not want setuid root code, do not enable KDE lock/unlock or any PAM service that runs without root privileges. `sudo` and polkit may work without the wrapper on some systems, but this project installs the wrapper consistently.

## KWallet

Touch ID does not provide the Fedora account password. KWallet and GNOME Keyring may not unlock automatically when login succeeds through Touch ID. This is expected.
