# New System Checklist

Use this when setting up another Fedora Parallels VM.

1. Confirm Touch ID works on macOS.
2. Confirm the Fedora VM has a Parallels shared folder mounted:

   ```bash
   mount | grep /media/psf
   ```

3. Copy this repo to the shared folder:

   ```bash
   rsync -a --delete ~/fedora-touchid-pam/ /media/psf/iCloud/fedora-touchid-pam/
   cd /media/psf/iCloud/fedora-touchid-pam
   ```

4. Fedora install:

   ```bash
   ./fedora/install-fedora-sudo.sh
   ```

5. macOS install, from the matching shared-folder path:

   ```bash
   ./macos/install-macos-helper.sh
   ```

6. Test sudo:

   ```bash
   sudo -k
   sudo true
   ```

7. Enable and test polkit:

   ```bash
   ./fedora/enable-fedora-polkit.sh
   pkexec true
   ```

8. Enable and test KDE unlock:

   ```bash
   ./fedora/enable-fedora-kde-lock.sh
   loginctl lock-session
   ```

9. Optional SDDM login:

   ```bash
   ./fedora/enable-fedora-sddm-login.sh
   ```

10. Check status:

    ```bash
    ./fedora/status.sh
    ```
