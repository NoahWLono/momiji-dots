#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run sudo maple-apply from the live ISO.' >&2; exit 1; }
[[ -e /run/archiso ]] || { echo 'This helper only operates from the live ISO.' >&2; exit 1; }
mountpoint -q /mnt || { echo '/mnt is not a mounted installation.' >&2; exit 1; }
[[ -f /mnt/etc/arch-release && -f /mnt/etc/os-release ]] || { echo 'No installed Arch root at /mnt.' >&2; exit 1; }
[[ $(findmnt -n -o MAJ:MIN /mnt) != $(findmnt -n -o MAJ:MIN /) ]] || exit 1
read -r -p 'Normal username created in Archinstall: ' user
[[ $user =~ ^[a-z_][a-z0-9_-]{0,31}$ && $user != root ]] || { echo 'Invalid username.' >&2; exit 1; }
record=$(arch-chroot /mnt getent passwd "$user")
IFS=: read -r _ _ uid _ _ home _ <<<"$record"
[[ $uid =~ ^[0-9]+$ && $uid -ge 1000 && $home == "/home/$user" ]] || { echo 'Expected a normal user with /home/username.' >&2; exit 1; }
cat <<EOF
Target root: $(findmnt -n -o SOURCE /mnt)
Target user: $user
This will fully update this new Arch installation, add MapleOS desktop packages,
back up this user's existing .config and .local directories, and enable SDDM.
It will not change disk partitions, encryption, or your installed bootloader.
EOF
read -r -p 'Type APPLY MAPLEOS to proceed: ' answer
[[ $answer == 'APPLY MAPLEOS' ]] || exit 0
mapfile -t packages </usr/local/share/mapleos/desktop-packages.txt
arch-chroot /mnt pacman -Syu --needed --noconfirm "${packages[@]}"
install -d /mnt/usr/local/bin /mnt/usr/local/share/mapleos /mnt/usr/local/lib/mapleos
for name in maple-ai maple-welcome; do
    install -m755 "/usr/local/bin/$name" "/mnt/usr/local/bin/$name"
done
cp -a /usr/local/share/mapleos/. /mnt/usr/local/share/mapleos/
cp -a /usr/local/lib/mapleos/. /mnt/usr/local/lib/mapleos/
cp -a /etc/skel/. /mnt/etc/skel/
stamp=$(date -u +%Y%m%dT%H%M%SZ)
for name in .config .local; do
    [[ ! -e /mnt/home/$user/$name ]] || mv "/mnt/home/$user/$name" "/mnt/home/$user/$name.before-mapleos-$stamp"
done
cp -a /etc/skel/. "/mnt/home/$user/"
arch-chroot /mnt chown -R "$user:$user" "/home/$user/.config" "/home/$user/.local" "/home/$user/Maple" "/home/$user/Pictures"
arch-chroot /mnt usermod -aG wheel -s /usr/bin/fish "$user"
install -Dm440 /usr/local/share/mapleos/wheel-sudoers /mnt/etc/sudoers.d/20-mapleos
arch-chroot /mnt visudo -cf /etc/sudoers
install -Dm644 /usr/local/share/mapleos/os-release /mnt/etc/os-release.mapleos
rm -f /mnt/etc/os-release
mv /mnt/etc/os-release.mapleos /mnt/etc/os-release
install -Dm644 /usr/local/share/mapleos/zram.conf /mnt/etc/systemd/zram-generator.conf
install -Dm644 /usr/local/share/mapleos/branding.hook /mnt/etc/pacman.d/hooks/99-mapleos-branding.hook
install -Dm644 /usr/local/share/mapleos/mapleos.desktop /mnt/usr/share/wayland-sessions/mapleos.desktop
arch-chroot /mnt systemctl enable NetworkManager.service sddm.service
arch-chroot /mnt systemctl disable sshd.service 2>/dev/null || true
printf '\nMapleOS desktop applied. No live autologin, live passwords, network profiles or API keys were copied.\n'
printf 'Check the bootloader and encryption configuration from Archinstall before rebooting.\n'
