# Momiji encrypted clean-install runbook

This runbook targets one user and these fixed decisions:

- Arch Linux on the entire internal drive
- one 1 GiB EFI System Partition
- one LUKS2 encrypted partition containing btrfs
- btrfs subvolumes `@` and `@home`
- zram swap, with no disk swap and no hibernation
- systemd-boot
- hostname `momiji`
- user `noah`, Fish login shell
- SDDM graphical login with no autologin
- Hyprland with current Caelestia Lua configuration
- timezone `America/Toronto`, locale `en_CA.UTF-8`

The normal boot sequence is systemd-boot, a LUKS passphrase prompt, the SDDM
login screen, then Hyprland. The disk-unlock passphrase and the user login
password are separate credentials.

## Encryption boundary

LUKS protects root, home, installed applications, logs, and all other data in
the large encrypted partition. The EFI System Partition must remain readable by
firmware, so it contains systemd-boot, the kernel, and the initramfs and is not
encrypted.

With Secure Boot disabled, encryption protects data at rest but does not
authenticate the boot files. A later Secure Boot and Unified Kernel Image
project can protect that boot chain. It is not required for this clean install.

Use an ASCII-only LUKS passphrase so the early boot keyboard layout cannot make
it impossible to type. A long multiword passphrase is easier to enter reliably
than a short symbol-heavy one. Store a recovery copy somewhere that is not this
laptop.

## Phase 0: Preflight

1. Apply the encrypted-login bundle to the repository, then run:

   ```sh
   cd ~/momiji-dots
   ./scripts/validate-repo.sh
   git status
   git add -A
   git commit -m "use LUKS encryption and SDDM login"
   git push
   ```

2. Confirm the public branch contains the required files:

   ```sh
   B=https://raw.githubusercontent.com/NoahWLono/momiji-dots/main
   for path in \
     packages.txt \
     boot/arch.conf.template \
     etc/mkinitcpio.conf.d/momiji-encryption.conf \
     etc/sddm.conf.d/10-momiji.conf \
     scripts/enable-display-manager.sh; do
       curl -fsS "$B/$path" >/dev/null || exit 1
       printf 'OK  %s\n' "$path"
   done
   ```

3. Download the current Arch ISO from the official Arch site and verify its
   signature or checksum using the official instructions.

4. On macOS, identify the USB carefully and write the ISO. Replace `disk4` and
   the ISO filename with the actual values:

   ```sh
   diskutil list
   diskutil unmountDisk /dev/disk4
   sudo dd if=archlinux-x86_64.iso of=/dev/rdisk4 bs=4m
   diskutil eject /dev/disk4
   ```

   Press `Ctrl+T` while `dd` runs to print progress.

5. Keep the Wi-Fi password and the planned LUKS passphrase available away from
   the laptop.

## Phase 1: Firmware

1. Optionally boot Windows once to install available firmware updates.
2. Enter firmware setup. HP commonly uses `Esc`, then `F10`, and the one-time
   boot menu commonly uses `F9`. Verify the prompts shown by the machine.
3. Confirm UEFI boot mode and disable Fast Boot.
4. Disable Secure Boot for this unsigned systemd-boot setup.
5. Save and start the USB's UEFI entry.

## Phase 2: Live ISO and network

Confirm UEFI mode:

```sh
cat /sys/firmware/efi/fw_platform_size
```

It must print `64`.

For Wi-Fi:

```text
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect "YourSSID"
[iwd]# exit
```

Replace `wlan0` with the listed device. Verify connectivity and time:

```sh
ping -c 3 archlinux.org
timedatectl
```

## Phase 3: Disk destruction and LUKS2

Everything in this phase erases the selected disk. The examples assume an NVMe
named `/dev/nvme0n1`. Stop and substitute the real device if `lsblk` shows a
different name.

```sh
lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINTS
```

Partition the correct disk:

```sh
fdisk /dev/nvme0n1
```

Create a new GPT and two partitions:

1. 1 GiB, EFI System
2. Remaining space, Linux filesystem or Linux LUKS

Select partition types by the names displayed by the current `fdisk`, not by
type numbers copied from an older guide. Use `p` to review the model, sizes, and
partition table before `w`.

Format only the EFI partition:

```sh
mkfs.fat -F 32 -n ESP /dev/nvme0n1p1
```

Create the encrypted container on partition 2:

```sh
cryptsetup luksFormat \
  --type luks2 \
  --verify-passphrase \
  --label cryptroot \
  /dev/nvme0n1p2
```

This command is destructive. Type `YES` only after checking the device name.
Enter the new LUKS passphrase twice.

Open it:

```sh
cryptsetup open /dev/nvme0n1p2 cryptroot
cryptsetup status cryptroot
```

Create btrfs inside the unlocked mapping:

```sh
mkfs.btrfs -L arch /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt
mkdir -p /mnt/home /mnt/boot
mount -o subvol=@home,compress=zstd,noatime \
  /dev/mapper/cryptroot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
```

There is no disk swap partition. zram is configured after first boot. This also
means hibernation is not supported.

## Phase 4: Base system

`cryptsetup` must be installed in the target system and included in the
initramfs.

```sh
pacstrap -K /mnt \
  base linux linux-firmware amd-ucode \
  btrfs-progs cryptsetup \
  networkmanager fish neovim sudo man-db man-pages curl git

genfstab -U /mnt > /mnt/etc/fstab
cat /mnt/etc/fstab
```

Verify entries for `/`, `/home`, and `/boot`. The btrfs lines should show
`subvol=/@` and `subvol=/@home`. There should be no disk-swap line.

## Phase 5: Chroot, encrypted initramfs, and bootloader

```sh
arch-chroot /mnt
```

Time and locale:

```sh
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
sed -i 's/^#en_CA.UTF-8 UTF-8/en_CA.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
printf 'LANG=en_CA.UTF-8\n' > /etc/locale.conf
printf 'KEYMAP=us\n' > /etc/vconsole.conf
```

Hostname and hosts:

```sh
printf 'momiji\n' > /etc/hostname
curl -fL -o /etc/hosts \
  https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/etc/hosts
cat /etc/hosts
```

Services:

```sh
systemctl enable NetworkManager.service systemd-timesyncd.service
```

Accounts:

```sh
passwd
useradd -m -G wheel -s /usr/bin/fish noah
passwd noah
EDITOR=nvim visudo
```

In `visudo`, uncomment:

```text
%wheel ALL=(ALL:ALL) ALL
```

Install the mkinitcpio drop-in:

```sh
install -d /etc/mkinitcpio.conf.d
curl -fL \
  -o /etc/mkinitcpio.conf.d/momiji-encryption.conf \
  https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/etc/mkinitcpio.conf.d/momiji-encryption.conf

cat /etc/mkinitcpio.conf.d/momiji-encryption.conf
mkinitcpio -P
```

The hook list must contain `systemd`, `sd-vconsole`, and `sd-encrypt`, with
`sd-encrypt` before `filesystems`.

Install systemd-boot and generate the loader entry from the LUKS UUID:

```sh
bootctl install
install -d /boot/loader/entries

curl -fL -o /boot/loader/loader.conf \
  https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/boot/loader.conf

LUKS_UUID=$(cryptsetup luksUUID /dev/nvme0n1p2)
test -n "$LUKS_UUID"

curl -fL -o /tmp/arch.conf.template \
  https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/boot/arch.conf.template

sed "s/LUKS_UUID_PLACEHOLDER/$LUKS_UUID/" \
  /tmp/arch.conf.template \
  > /boot/loader/entries/arch.conf

rm /tmp/arch.conf.template

grep -F "rd.luks.name=$LUKS_UUID=cryptroot" \
  /boot/loader/entries/arch.conf
grep -F 'root=/dev/mapper/cryptroot' \
  /boot/loader/entries/arch.conf
cat /boot/loader/entries/arch.conf
bootctl list
```

The UUID here is the LUKS container UUID from partition 2. It is not the btrfs
filesystem UUID and not the EFI partition UUID.

Leave and reboot:

```sh
exit
umount -R /mnt
cryptsetup close cryptroot
reboot
```

Remove the USB when firmware starts again.

## Phase 6: First encrypted boot

The first prompt after systemd-boot is the LUKS passphrase. A correct passphrase
unlocks the root filesystem. At this stage SDDM is not enabled yet, so the
machine reaches a tty login.

Log in as `noah`. Connect Wi-Fi if needed:

```sh
nmcli device wifi connect "YourSSID" password "yourpassword"
ping -c 3 archlinux.org
```

Clone and validate the exact payload:

```sh
git clone https://github.com/NoahWLono/momiji-dots.git ~/momiji-dots
cd ~/momiji-dots
./scripts/validate-repo.sh
```

Install packages, paru, applications, zram, and services:

```sh
./scripts/install-packages.sh
```

## Phase 7: Caelestia

Install the stable CLI package and launch its installer:

```sh
paru -S --needed caelestia-cli
caelestia install --aur-helper paru
```

Deploy the repository-owned overrides and assets:

```sh
cd ~/momiji-dots
./scripts/deploy-configs.sh
```

Current Caelestia uses:

- `~/.config/caelestia/hypr-vars.lua`
- `~/.config/caelestia/hypr-user.lua`

## Phase 8: Test Hyprland before enabling the login manager

From the tty:

```sh
Hyprland
```

Inside a terminal, run:

```sh
hyprctl monitors
wpctl status
nmcli general status
caelestia scheme get
```

Acceptance criteria:

- the shell, launcher, terminal, and Firefox keybind work
- Maple is the wallpaper and the dynamic colour scheme is active
- audio output is listed
- the lock screen opens with `Super+L`
- no red Lua error is printed by Hyprland

Exit:

```sh
hyprctl dispatch exit
```

## Phase 9: Enable the normal graphical login

Only after the manual session test succeeds:

```sh
cd ~/momiji-dots
./scripts/enable-display-manager.sh
reboot
```

The next boot sequence is:

1. systemd-boot
2. LUKS passphrase
3. SDDM graphical login

At the first SDDM screen, select the `Hyprland` session and sign in as `noah`.
SDDM remembers the last user and session. Autologin is explicitly disabled.

After login, verify zram:

```sh
swapon --show
zramctl
```

The swap device should be `/dev/zram0`, not an NVMe partition or file.

Test suspend and resume with disposable work open. The existing session should
return locked. If the session resumes unlocked, use `Super+L` before closing the
lid until the Caelestia idle and lock configuration has been corrected.

## Phase 10: Baseline protections

Firewall:

```sh
sudo pacman -S --needed ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable ufw.service
```

Snapshots:

```sh
sudo pacman -S --needed snapper snap-pac
sudo snapper -c root create-config /
sudo snapper -c root create -d "baseline encrypted clean install"
```

The root snapshot does not include the separate `@home` subvolume and is not a
backup.

LUKS header backup:

```sh
sudo cryptsetup luksHeaderBackup /dev/nvme0n1p2 \
  --header-backup-file /path/on/external-media/momiji-luks-header.img
```

Store that file on separate trusted media. Never commit it, email it, or leave
the only copy on the encrypted laptop. A header backup does not replace the
passphrase.

Sensors:

```sh
sudo sensors-detect
sensors
```

Write every deviation to `~/notes/journal.md`.

## Optional extras

```sh
~/momiji-dots/scripts/install-fun.sh
```

The custom Clock pony is optional. Open-ended cursor, sound, and plugin work is
in `rice/RICING.md`.

## Proton VPN through WireGuard

Keep the downloaded private configuration out of Git:

```sh
nmcli connection import type wireguard file ~/Downloads/proton.conf
nmcli connection show
nmcli connection up proton
```

Use the imported connection name printed by NetworkManager.

## Microphone troubleshooting

```sh
wpctl status
arecord -d 3 /tmp/mic-test.wav
aplay /tmp/mic-test.wav
dmesg | grep -iE 'sof|acp|audio'
```

`alsa-utils` and `sof-firmware` are in `packages.txt`.

## Wi-Fi troubleshooting

Deploy these only for matching rtw89 symptoms:

```sh
sudo install -Dm644 ~/momiji-dots/etc/wifi-powersave.conf \
  /etc/NetworkManager/conf.d/wifi-powersave.conf
sudo systemctl restart NetworkManager
```

Before installing the driver option:

```sh
modinfo rtw89_pci | grep -E 'disable_aspm_l1|disable_clkreq'
```

Then, only if both parameters are supported:

```sh
sudo install -Dm644 ~/momiji-dots/etc/rtw89.conf \
  /etc/modprobe.d/rtw89.conf
sudo reboot
```

## Recovery

### LUKS password is accepted, but root does not mount

Boot the Arch ISO, connect the network, then:

```sh
cryptsetup open /dev/nvme0n1p2 cryptroot
mount -o subvol=@ /dev/mapper/cryptroot /mnt
mount /dev/nvme0n1p1 /mnt/boot
arch-chroot /mnt
```

Inspect:

```sh
cat /etc/mkinitcpio.conf.d/momiji-encryption.conf
cat /boot/loader/entries/arch.conf
cryptsetup luksUUID /dev/nvme0n1p2
mkinitcpio -P
```

### SDDM fails

Switch to a tty with `Ctrl+Alt+F2`, sign in, and run:

```sh
sudo systemctl disable --now sddm.service
sudo systemctl set-default multi-user.target
```

Fix the graphical session, test `Hyprland` manually, then re-run
`scripts/enable-display-manager.sh`.

## Update routine

Use:

```sh
caelestia update
```

Never run `pacman -Sy <package>`. Before a future reinstall:

```sh
cd ~/momiji-dots
./scripts/validate-repo.sh --arch --aur
```
