# Momiji install checklist: HP 255 G10, sealed box to daily driver

Companion to [RUNBOOK.md](RUNBOOK.md); every § points at the step there with
the full commands and expected output. Work strictly top to bottom. If any
verification fails, stop and fix it before ticking the next box. Keep this
file open on a second device during the install.

## Phase 0: before the box arrives (§1 to §5)

- [ ] On the Mac: `cd ~/momiji-dots && git switch main && git pull --ff-only && ./scripts/validate-repo.sh` reports zero failures (§1)
- [ ] Prepare three separate credentials, stored off the laptop: a long ASCII-only LUKS passphrase, the `noah` account password, and a break-glass root password (§2)
- [ ] Download the current Arch ISO and verify its signature per the official instructions (§3)
- [ ] Write the ISO to USB with `dd`; the macOS "disk unreadable" complaint afterwards is normal, choose Ignore (§4)
- [ ] Stage fallbacks: Wi-Fi password, Ethernet cable or phone for USB tethering, a second device showing this checklist, the LUKS recovery copy (§5)

## Phase 1: unbox and firmware (§6 to §9)

- [ ] Optional: boot Windows exactly once to apply HP BIOS and firmware updates; store nothing in it (§6)
- [ ] Tap `Esc` at power-on, then `F10` for firmware setup (§7)
- [ ] Set UEFI on, Legacy/CSM off, Fast Boot off, Secure Boot off; type any confirmation code HP displays (§8)
- [ ] `F9` one-time boot menu, pick the USB's UEFI entry, land in the live root shell (§9)

## Phase 2: live ISO checks (§10 to §13)

- [ ] `cat /sys/firmware/efi/fw_platform_size` prints `64` (§10)
- [ ] Identify the Wi-Fi silicon with `lspci -knn | grep -iA3 net`; write down the chip and driver (rtw89, rtw88, or mt7921e) for the journal (§12)
- [ ] Get online via Ethernet, `iwctl`, or tethering; `ping -c 3 archlinux.org` succeeds (§12)
- [ ] `timedatectl` shows network time sync (§13)

## Phase 3: partition and encrypt, destructive from here (§14 to §21)

- [ ] `lsblk -o NAME,SIZE,MODEL,TYPE` identifies the internal NVMe beyond doubt (§14)
- [ ] `sgdisk --zap-all`, then partition 1 as 1 GiB type ef00 and partition 2 as the remainder type 8309; verify with `sgdisk -p` (§15)
- [ ] `mkfs.fat -F 32 -n ESP` on partition 1 (§16)
- [ ] `cryptsetup luksFormat --type luks2` on partition 2; recheck the device node before typing YES (§17)
- [ ] `cryptsetup open` the container as `cryptroot` (§18)
- [ ] `mkfs.btrfs -L arch /dev/mapper/cryptroot` (§19)
- [ ] Create subvolumes `@` and `@home` (§20)
- [ ] Mount `@` at /mnt, `@home` at /mnt/home, the ESP at /mnt/boot; verify all three with `findmnt` (§21)

## Phase 4: base system (§22 to §23)

- [ ] `pacstrap -K` the §22 list, which carries amd-ucode, btrfs-progs, cryptsetup, networkmanager, and fish
- [ ] `genfstab -U /mnt > /mnt/etc/fstab`; confirm the subvolumes, `compress=zstd`, `noatime`, and no swap entry (§23)

## Phase 5: configure inside the chroot (§24 to §37)

- [ ] `arch-chroot /mnt` (§24)
- [ ] Timezone America/Toronto and `hwclock --systohc` (§25)
- [ ] Locales en_CA and en_US generated, `LANG=en_CA.UTF-8`, `KEYMAP=us` (§26)
- [ ] Hostname `momiji` (§27)
- [ ] Root password set; user `noah` created in wheel with the fish shell; sudoers drop-in passes `visudo -cf` (§28)
- [ ] Clone the repository's `main` as noah; the branch check prints `main` (§29)
- [ ] Install the repository `/etc/hosts` (§30)
- [ ] Enable NetworkManager and timesyncd; `install -d /var/log/journal` so logs persist across crashes (§31)
- [ ] `./scripts/validate-repo.sh` inside the chroot: zero failures (§32)
- [ ] Install the encryption mkinitcpio drop-in; `mkinitcpio -P` completes clean (§33)
- [ ] `bootctl install`; deploy the repository loader.conf (§34)
- [ ] Generate arch.conf from the template with the real LUKS UUID; all four greps pass, including `rd.luks.options=discard` (§35)
- [ ] Final chroot checks: kernel, initramfs, loader entries, both services enabled (§36)
- [ ] `exit`, `umount -R /mnt`, `cryptsetup close cryptroot`, reboot, pull the USB (§37)

## Phase 6: first encrypted boot (§38 to §45)

- [ ] LUKS passphrase accepted, tty login as noah works (§38, §39)
- [ ] Wi-Fi up through `nmcli device wifi connect` (§40)
- [ ] Repository present on `main` with a clean status (§41)
- [ ] `sudo pacman -Syu`, never `pacman -Sy <package>` (§42)
- [ ] `./scripts/validate-repo.sh --arch --aur`: zero failures; stop here if any package name has drifted (§43)
- [ ] `./scripts/install-packages.sh` runs to completion (§44)
- [ ] Verify Hyprland, paru, and sddm on PATH; bluetooth, power-profiles-daemon, and fstrim.timer enabled (§45)

## Phase 7: Caelestia (§46 to §48)

- [ ] `paru -S --needed caelestia-cli` (§46)
- [ ] `caelestia install --aur-helper paru`, choosing only the optional components actually wanted (§47)
- [ ] `~/.config/hypr/hyprland.lua` and `~/.config/caelestia/hypr-vars.lua` both exist (§48)

## Phase 8: manual Hyprland gate, before any display manager (§49 to §53)

- [ ] Launch `Hyprland` from the tty (§49)
- [ ] `Super+T` for a terminal, then run `./scripts/deploy-configs.sh` (§50)
- [ ] Restart the Caelestia shell (§51)
- [ ] Full test list passes: launcher, terminal, Firefox, file manager, lock, workspaces, volume, brightness, Wi-Fi, Bluetooth, notifications, Maple wallpaper, dynamic colours, audio in and out, and `pkexec true` raises an authentication prompt (§52)
- [ ] `hyprctl dispatch exit` returns cleanly to the tty (§53)

## Phase 9: graphical login (§54 to §55)

- [ ] `./scripts/enable-display-manager.sh`; sddm enabled and graphical.target default (§54)
- [ ] Reboot into the final flow: systemd-boot, LUKS prompt, SDDM, Hyprland session as noah, no autologin (§55)

## Phase 10: acceptance (§56 to §60)

- [ ] `/` and `/home` originate through /dev/mapper/cryptroot; /boot is the FAT32 ESP (§56)
- [ ] `sudo fstrim -v /` prints a trimmed byte count, not "not supported" (§56)
- [ ] `/dev/zram0` is the only swap device (§57)
- [ ] sddm, NetworkManager, bluetooth, and power-profiles-daemon all active (§58, §59)
- [ ] Lock works; suspend and resume returns to a locked session (§60)

## Phase 11: security and recovery (§61 to §65)

- [ ] ufw enabled: deny incoming, allow outgoing (§61)
- [ ] snapper baseline snapshot of root exists; remember it excludes @home and snapshots are not backups (§62)
- [ ] Decide a real backup target for @home and record the choice in the journal; nothing in this repo covers it yet
- [ ] LUKS header backed up to external media stored away from the laptop, never committed to git (§63)
- [ ] `~/notes/journal.md` started, including the Wi-Fi chip recorded in Phase 2 (§64)
- [ ] Final `./scripts/validate-repo.sh --arch --aur`: zero failures (§65)

## Phase 12: optional layer, only after the baseline (§66 to §70)

- [ ] `./scripts/install-fun.sh` for the terminal toys (§66)
- [ ] Test the Maple fastfetch config before adopting it (§67)
- [ ] Proton VPN WireGuard profile imported through nmcli; the config file never enters git (§69)
- [ ] Rice one change at a time per rice/RICING.md, journaling every change and every reversion (§70)

## Done when

Every box above is ticked and the RUNBOOK "Final done state" list is also
fully true. At that point the machine is an encrypted, recoverable, documented
baseline, and experiments can begin without fear.
