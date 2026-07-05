# Rollback

Rollback is intentionally split by service so you can disable only the part that is misbehaving.

Run from the VM in the project directory:

```bash
./linux/disable-sddm-login.sh
./linux/disable-kde-lock.sh
./linux/disable-polkit.sh
./linux/disable-sudo.sh
```

Run from macOS in the project directory:

```bash
./macos/uninstall-macos-helper.sh
```

## What Is Left Behind

The generic Linux rollback scripts restore/remove PAM hooks. They intentionally leave helper files and config in place:

```text
/usr/local/libexec/parallels-touchid-pam
/usr/local/libexec/parallels-touchid-pam.py
/etc/parallels-touchid-pam/config
/etc/parallels-touchid-pam/secret
```

To remove them after disabling all PAM hooks:

```bash
sudo rm -f /usr/local/libexec/parallels-touchid-pam /usr/local/libexec/parallels-touchid-pam.py
sudo rm -rf /etc/parallels-touchid-pam
```

The macOS uninstall removes only the LaunchAgent plist. To remove helper files:

```bash
rm -rf "$HOME/Library/Application Support/ParallelsTouchIDPAM"
```

## Emergency Recovery

If PAM login is broken:

1. Boot into a rescue shell, or use another root-capable session.
2. Remove the marked blocks between:

   ```text
   # parallels-touchid-pam: begin
   # parallels-touchid-pam: end
   ```

3. Restore backups if present:

   ```bash
   sudo cp -a /etc/pam.d/sudo.parallels-touchid-pam.bak /etc/pam.d/sudo
   sudo cp -a /etc/pam.d/sddm.parallels-touchid-pam.bak /etc/pam.d/sddm
   sudo cp -a /etc/pam.d/kde.parallels-touchid-pam.bak /etc/pam.d/kde
   ```

For polkit, removing `/etc/pam.d/polkit-1` restores Fedora's vendor file at `/usr/lib/pam.d/polkit-1` unless a preexisting override was backed up.
