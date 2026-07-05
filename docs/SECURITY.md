# Security Notes

This bridge is a convenience layer, not biometric hardware passthrough.

## What Touch ID Proves

Touch ID proves that macOS LocalAuthentication accepted the active macOS user. The Linux VM accepts that result only after verifying a response signed with that VM's shared HMAC secret.

Each VM has its own secret and its own macOS config file.

## Secret Handling

Generic Linux installs store the HMAC secret at:

```text
/etc/parallels-touchid-pam/secret
```

It is root-owned and mode `0600`.

The macOS installer stores one copy per VM under:

```text
~/Library/Application Support/ParallelsTouchIDPAM/config.d/<vm-id>.env
```

Each config is mode `0600`.

The one-time provisioning file is created under `provisioning/` in the shared folder and removed by the macOS installer. The VM helper refuses Touch ID while that provisioning file still exists.

## Threat Model

Protected against:

- An unprivileged VM process writing fake success responses without the HMAC secret.
- Stale responses being replayed after the timestamp window.
- Slow password prompts when the macOS helper is down, because heartbeat is checked first.
- One VM forging another VM's responses, unless it can read that other VM's secret.

Not protected against:

- A compromised macOS user session.
- A compromised root account in a VM.
- A malicious process that can read the macOS helper config.
- A malicious process with the ability to replace trusted files in the shared folder and also obtain the HMAC secret.

## setuid Wrapper Risk

The wrapper is setuid root so PAM callers that run as the desktop user can still use the root-only VM secret.

The wrapper mitigations are:

- small C code path,
- fixed Python path,
- fixed script path,
- sanitized environment,
- Python isolated mode,
- no shell execution.

If you do not want setuid root code, do not enable KDE lock/unlock or any PAM service that runs without root privileges. `sudo` and polkit may work without the wrapper on some systems, but the generic Linux installer installs the wrapper consistently.

## KWallet

Touch ID does not provide the VM account password. KWallet and GNOME Keyring may not unlock automatically when login succeeds through Touch ID. This is expected.
