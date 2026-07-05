# Kali KDE Plasma 6 Setup

Use these wrappers on Kali. They call the generic `linux/` scripts and default the VM name shown in macOS Touch ID prompts to `kali`.

From Kali, run from a Parallels shared-folder copy of this repo:

```bash
./kali/install-kali-sudo.sh
```

This creates Kali's bridge under `bridges/kali/` by default, so the same shared repo copy can also hold other VM configs.

Then on macOS, from the matching shared-folder path:

```bash
./macos/install-macos-helper.sh
```

Back on Kali:

```bash
sudo -k
sudo true
./kali/enable-kali-polkit.sh
pkexec true
./kali/enable-kali-kde-lock.sh
loginctl lock-session
./kali/enable-kali-sddm-login.sh
```

If a dependency is missing:

```bash
sudo apt update
sudo apt install -y python3 gcc libc6-dev openssl sudo policykit-1
```

KDE Plasma uses PAM service `kde` for lock-screen authentication by default; the lock script also covers `kscreensaver` and `kcheckpass` when present.
