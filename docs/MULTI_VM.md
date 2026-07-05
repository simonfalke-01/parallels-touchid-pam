# Multi-VM macOS Helper

The macOS side is no longer tied to Fedora. One LaunchAgent can monitor any number of Parallels VM bridge directories.

## macOS Install Location

```text
~/Library/Application Support/ParallelsTouchIDPAM/
  parallels-touchid-helper
  helper.log
  helper.err
  config.d/
    fedora.env
    kali.env
```

LaunchAgent:

```text
~/Library/LaunchAgents/com.parallels-touchid-pam.helper.plist
```

## Adding Another VM

For each VM:

1. Copy this repo into a Parallels shared folder visible to that VM and macOS.
2. Run the VM-side install in that VM:

   ```bash
   ./linux/install-linux-sudo.sh
   ```

   For Kali:

   ```bash
   ./kali/install-kali-sudo.sh
   ```

3. On macOS, run from the matching shared-folder path:

   ```bash
   ./macos/install-macos-helper.sh
   ```

The macOS installer imports that VM's provisioning file into:

```text
~/Library/Application Support/ParallelsTouchIDPAM/config.d/<vm-id>.env
```

It restarts the same generic helper. Existing VM configs remain in place.

The generic Linux installer defaults each VM to a separate bridge directory:

```text
bridges/<vm-id>/
```

That means Fedora and Kali can use the same shared project copy without sharing request/response files.

## List VM Configs

On macOS:

```bash
./macos/list-vms.sh
```

Secrets are redacted.

## Remove One VM From macOS Helper

On macOS:

```bash
./macos/remove-vm.sh <vm-id>
```

This only removes the macOS-side config. It does not change PAM hooks inside the VM.

## Migrating the Existing Fedora VM

Your original Fedora setup may still have the old single-VM LaunchAgent:

```text
~/Library/LaunchAgents/com.fedora-touchid-pam.helper.plist
```

To migrate Fedora into the generic helper:

1. Copy the updated repo to Fedora's shared folder.
2. In Fedora, run:

   ```bash
   ./fedora/install-fedora-sudo.sh
   ```

   This regenerates a provisioning file using the existing Fedora secret.

3. On macOS, run:

   ```bash
   ./macos/install-macos-helper.sh
   ```

4. After Fedora works through the generic helper, remove the old LaunchAgent:

   ```bash
   launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.fedora-touchid-pam.helper.plist" 2>/dev/null || true
   rm -f "$HOME/Library/LaunchAgents/com.fedora-touchid-pam.helper.plist"
   ```

## Touch ID Prompt Labels

The macOS prompt includes the VM name and PAM service, for example:

```text
Approve kali sudo authentication for kali on kali.
Approve fedora kde authentication for simonfalke on fedora.
```
