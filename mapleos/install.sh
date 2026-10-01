#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run sudo maple-install.' >&2; exit 1; }
[[ -e /run/archiso ]] || { echo 'Use this helper from the MapleOS live ISO.' >&2; exit 1; }
cat <<'EOF'
MapleOS preview installer

This starts the official interactive Archinstall utility. It can ERASE DISKS.
Back up your data first. Test in a VM before installing on physical hardware.
This is an ONLINE installer. Connect using nmtui before continuing.

In Archinstall:
  * Carefully select the target disk, encryption, bootloader, locale and timezone.
  * Create a normal user with administrator (wheel) privileges.
  * Select a minimal installation. Maple's desktop is applied afterward.
  * Use /mnt as the installation mount point.
  * At completion, do NOT reboot yet. Exit Archinstall back to this helper.

MapleOS does not choose a disk or feed unattended destructive settings to Archinstall.
EOF
read -r -p 'Type OPEN INSTALLER to proceed: ' answer
[[ $answer == 'OPEN INSTALLER' ]] || exit 0
archinstall
if mountpoint -q /mnt && [[ -f /mnt/etc/os-release ]]; then
    exec /usr/local/bin/maple-apply
fi
cat <<'EOF'
Archinstall returned without an installed root mounted at /mnt.
Nothing else was changed by this helper. If installation succeeded, remount its
root and EFI partition at /mnt and /mnt/boot as appropriate, then run maple-apply.
Do not point this helper at your running system.
EOF
