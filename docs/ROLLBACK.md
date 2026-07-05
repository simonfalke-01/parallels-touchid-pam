# Rollback

Rollback is intentionally split by service so you can disable only the part that is misbehaving.

Run from Fedora in the project directory:

```bash
./fedora/disable-fedora-sddm-login.sh
./fedora/disable-fedora-kde-lock.sh
./fedora/disable-fedora-polkit.sh
./fedora/disable-fedora-sudo.sh
```

Run from macOS in the project directory:

```bash
./macos/uninstall-macos-helper.sh
```

## What Is Left Behind

The Fedora rollback scripts restore/remove PAM hooks. They intentionally leave helper files and config in place:

```text
/usr/local/libexec/fedora-touchid-pam
/usr/local/libexec/fedora-touchid-pam.py
/etc/fedora-touchid-pam/config
/etc/fedora-touchid-pam/secret
```

To remove them after disabling all PAM hooks:

```bash
sudo rm -f /usr/local/libexec/fedora-touchid-pam /usr/local/libexec/fedora-touchid-pam.py
sudo rm -rf /etc/fedora-touchid-pam
```

The macOS uninstall removes only the LaunchAgent plist. To remove helper files:

```bash
rm -rf "$HOME/Library/Application Support/FedoraTouchIDPAM"
```

## Emergency Recovery

If PAM login is broken:

1. Boot into a rescue shell, or use another root-capable session.
2. Remove the marked blocks between:

   ```text
   # fedora-touchid-pam: begin
   # fedora-touchid-pam: end
   ```

3. Restore backups if present:

   ```bash
   sudo cp -a /etc/pam.d/sudo.fedora-touchid-pam.bak /etc/pam.d/sudo
   sudo cp -a /etc/pam.d/sddm.fedora-touchid-pam.bak /etc/pam.d/sddm
   sudo cp -a /etc/pam.d/kde.fedora-touchid-pam.bak /etc/pam.d/kde
   ```

For polkit, removing `/etc/pam.d/polkit-1` restores Fedora's vendor file at `/usr/lib/pam.d/polkit-1` unless a preexisting override was backed up.
