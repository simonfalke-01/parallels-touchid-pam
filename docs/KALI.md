# Kali KDE Plasma 6 Setup

This setup uses the generic Linux scripts plus Kali convenience wrappers.

## 1. Put the Repo in a Shared Folder

Inside Kali, copy or clone the repo into a Parallels shared folder. Example:

```bash
cd /media/psf/iCloud/fedora-touchid-pam
```

Any shared folder is fine as long as macOS can access the same files.

## 2. Install Dependencies

Kali may already have some of these. Install the basics:

```bash
sudo apt update
sudo apt install -y python3 gcc libc6-dev openssl sudo policykit-1
```

## 3. Install Kali VM Side

From Kali, in the shared-folder repo:

```bash
./kali/install-kali-sudo.sh
```

This installs:

```text
/usr/local/libexec/parallels-touchid-pam
/usr/local/libexec/parallels-touchid-pam.py
/etc/parallels-touchid-pam/config
/etc/parallels-touchid-pam/secret
```

It also adds the `sudo` PAM hook and creates:

```text
provisioning/parallels-touchid-pam.env
```

Kali's runtime bridge defaults to:

```text
bridges/kali/
```

Touch ID is disabled until macOS imports and removes that provisioning file.

## 4. Import Kali Into macOS Helper

On macOS, open Terminal at the matching shared-folder path and run:

```bash
./macos/install-macos-helper.sh
```

This adds Kali to:

```text
~/Library/Application Support/ParallelsTouchIDPAM/config.d/kali.env
```

## 5. Test sudo

Back in Kali:

```bash
sudo -k
sudo true
```

Expected:

- macOS Touch ID prompt appears.
- Kali `sudo true` succeeds.
- Logs show `service='sudo'`.

```bash
journalctl -t parallels-touchid-pam --since "5 minutes ago" --no-pager
```

## 6. Enable Desktop Prompts

```bash
./kali/enable-kali-polkit.sh
pkexec true
```

Expected log:

```text
accepted touchid user='...' service='polkit-1'
```

## 7. Enable KDE Lock/Unlock

```bash
./kali/enable-kali-kde-lock.sh
loginctl lock-session
```

Unlock the session. KDE Plasma uses PAM service `kde` for KScreenLocker by default; the script also hooks `kscreensaver` and `kcheckpass` if present.

Expected log:

```text
accepted touchid user='...' service='kde'
```

## 8. Optional SDDM Login

```bash
./kali/enable-kali-sddm-login.sh
```

Test on logout or reboot. Touch ID login does not provide your Kali password to KWallet, so KWallet may ask to unlock after login.

## Rollback on Kali

```bash
./kali/disable-kali-all.sh
```

Or use the generic individual scripts:

```bash
./linux/disable-sddm-login.sh
./linux/disable-kde-lock.sh
./linux/disable-polkit.sh
./linux/disable-sudo.sh
```
