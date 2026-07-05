# New VM Checklist

Use this when setting up another Parallels Linux VM.

1. Confirm Touch ID works on macOS.

2. Confirm the VM has a Parallels shared folder mounted:

   ```bash
   mount | grep /media/psf
   ```

3. Copy this repo to the shared folder:

   ```bash
   rsync -a --delete ~/parallels-touchid-pam/ /media/psf/iCloud/parallels-touchid-pam/
   cd /media/psf/iCloud/parallels-touchid-pam
   ```

4. Install dependencies.

   Fedora:

   ```bash
   sudo dnf install gcc glibc-devel openssl python3
   ```

   Kali/Debian:

   ```bash
   sudo apt update
   sudo apt install -y python3 gcc libc6-dev openssl sudo polkitd pkexec
   ```

5. VM-side install:

   ```bash
   ./linux/install-linux-sudo.sh
   ```

   Kali wrapper:

   ```bash
   ./kali/install-kali-sudo.sh
   ```

6. macOS import, from the matching shared-folder path:

   ```bash
   ./macos/install-macos-helper.sh
   ```

7. Test sudo:

   ```bash
   sudo -k
   sudo true
   ```

8. Enable and test polkit:

   ```bash
   ./linux/enable-polkit.sh
   pkexec true
   ```

9. Enable and test KDE unlock:

   ```bash
   ./linux/enable-kde-lock.sh
   loginctl lock-session
   ```

10. Optional SDDM login:

    ```bash
    ./linux/enable-sddm-login.sh
    ```

11. Check status:

    ```bash
    ./linux/status.sh
    ./macos/list-vms.sh
    ```
