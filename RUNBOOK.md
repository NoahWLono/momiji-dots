# FINAL: HP 255 G10 from sealed box to encrypted Arch, SDDM, Hyprland, Caelestia, and Momiji

This is the complete install list for one human user, `noah`.

It uses this repository's `main` branch:

```text
https://github.com/NoahWLono/momiji-dots
```

Every clone command in this runbook selects `main` explicitly. Do not
silently switch branches during an installation.

## What the finished machine will use

- Arch Linux
- UEFI and systemd-boot
- one 1 GiB EFI System Partition
- one LUKS2-encrypted partition containing root and home
- btrfs subvolumes `@` and `@home`
- zram swap, with no disk swap and no hibernation
- one normal human account, `noah`
- SDDM as the graphical username and password screen
- Hyprland
- Caelestia
- the Momiji repository configuration, sounds, wallpaper, applications, and optional rice

The normal boot sequence will be:

1. systemd-boot
2. LUKS disk-unlock passphrase
3. SDDM graphical login
4. Hyprland and Caelestia

The LUKS passphrase and the `noah` account password are separate credentials.

---

# Part I: Before the laptop arrives

## 1. Confirm the repository is current and validated

On the Mac that contains the repository:

```sh
cd ~/momiji-dots

git switch main
git pull --ff-only
./scripts/validate-repo.sh
git diff --check
git status
```

The acceptable result is:

- `Validation complete: 0 failure(s), ...`
- `git diff --check` prints nothing
- a clean `git status`
- any Fish or Lua parser messages are warnings only when those parsers are not installed on macOS

Publish any remaining changes:

```sh
git add -A
git commit -m "finalize encrypted Arch install runbook"
git push
```

## 2. Prepare passwords before install day

Prepare three credentials:

1. **LUKS passphrase**  
   Use a long ASCII-only multiword passphrase. Avoid characters that depend on
   a special keyboard layout. Store a recovery copy somewhere other than the
   laptop.

2. **`noah` account password**  
   This is used by SDDM and `sudo`.

3. **Root password**  
   This is a break-glass recovery credential. Root will not appear as a normal
   SDDM user.

Do not put any of these in the Git repository.

## 3. Download and verify the Arch ISO

Download the current Arch ISO from an official Arch mirror.

Follow the current official Arch instructions to verify its signature or
checksum before writing it to USB.

## 4. Write the ISO to USB from macOS

Identify the USB device carefully:

```sh
diskutil list
```

The example below assumes the USB is `/dev/disk4`. Replace it with the real
device.

```sh
diskutil unmountDisk /dev/disk4
sudo dd if=archlinux-x86_64.iso of=/dev/rdisk4 bs=4m
diskutil eject /dev/disk4
```

While `dd` runs on macOS, press `Ctrl+T` to display progress.

A macOS message saying the resulting disk is unreadable is normal for an Arch
installer USB. Choose **Ignore**, not Initialize.

## 5. Prepare fallbacks

Have these available:

- Wi-Fi password
- Ethernet cable, when possible
- a phone and USB cable for tethering
- another computer or phone displaying this runbook
- the LUKS recovery copy

---

# Part II: Unbox and prepare the firmware

## 6. Optionally boot Windows once

On a brand-new machine, boot Windows once if you want to use HP's supplied tools
to install available BIOS or firmware updates before wiping the drive.

Do not store anything in Windows that you need to keep.

## 7. Enter HP firmware setup

Common HP keys are:

- `Esc`: Startup Menu
- `F10`: firmware setup
- `F9`: one-time boot menu

Begin tapping `Esc` immediately after pressing the power button.

## 8. Configure firmware

Confirm or change these settings:

- UEFI boot mode enabled
- Legacy or CSM mode disabled
- Fast Boot disabled
- Secure Boot disabled for this unsigned systemd-boot installation

Save the changes.

Some HP systems display a confirmation code after disabling Secure Boot. Type
the code displayed by the machine and press Enter.

## 9. Boot the Arch USB

Insert the USB, open the HP one-time boot menu, and select its UEFI entry.

You should reach an Arch live shell as root.

---

# Part III: Live ISO checks

## 10. Confirm UEFI mode

Run:

```sh
cat /sys/firmware/efi/fw_platform_size
```

It must print:

```text
64
```

If the file is missing, stop and reboot the USB in UEFI mode.

## 11. Set an easier console font when needed

```sh
setfont ter-132b
```

This is optional.

## 12. Connect to the network

### Identify the Wi-Fi hardware first

Record which wireless chip this specific unit shipped with:

```sh
lspci -knn | grep -iA3 net
```

Note the chip and the `Kernel driver in use` line for the install journal.
HP ships the 255 G10 with different cards by batch: Realtek 8852 family
(driver `rtw89`), Realtek RTL8822CE (driver `rtw88`), or MediaTek MT7921
(driver `mt7921e`). The repository's `etc/rtw89.conf` applies only to the
first group.

### Ethernet

Plug it in, wait a few seconds, then test:

```sh
ping -c 3 archlinux.org
```

### Wi-Fi

Start `iwctl`:

```sh
iwctl
```

Inside `iwctl`:

```text
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "YourSSID"
exit
```

Replace `wlan0` with the device name shown by `device list`.

Test:

```sh
ping -c 3 archlinux.org
```

### Phone tethering fallback

USB tethering normally appears as an Ethernet-style connection. Enable
tethering on the phone, then test again.

## 13. Confirm the clock

```sh
timedatectl
```

The live environment should show network time synchronization.

---

# Part IV: Destroy Windows and create the encrypted disk

## 14. Identify the internal drive

Run:

```sh
lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINTS
```

This runbook uses these example names:

```text
Internal disk:       /dev/nvme0n1
EFI partition:       /dev/nvme0n1p1
Encrypted partition: /dev/nvme0n1p2
```

Your machine may use different names. Do not continue until the model and size
identify the internal drive unambiguously.

Everything after this point destroys the selected drive.

## 15. Create a GPT with two partitions

`sgdisk` is on the live ISO, is scriptable, and makes every value explicit.
The old interactive `fdisk` sequence depended on fdisk auto-selecting the
sole partition, which made one keystroke a type code and a later identical
keystroke a partition number. That ambiguity is gone here.

Destroy every existing partition structure, then create both partitions:

```sh
sgdisk --zap-all /dev/nvme0n1

sgdisk -n1:0:+1G -t1:ef00 -c1:ESP /dev/nvme0n1
sgdisk -n2:0:0   -t2:8309 -c2:cryptroot /dev/nvme0n1
```

What each flag does:

- `--zap-all` wipes GPT and MBR structures on the whole disk
- `-n1:0:+1G` creates partition 1, 1 GiB, at the default start
- `-t1:ef00` sets partition 1 to type EFI System
- `-n2:0:0` creates partition 2 across all remaining space
- `-t2:8309` sets partition 2 to type Linux LUKS
- `-c` names are cosmetic labels

Verify before continuing:

```sh
sgdisk -p /dev/nvme0n1
lsblk /dev/nvme0n1
```

- partition 1 is approximately 1 GiB and type EFI System
- partition 2 occupies the rest of the drive and is type Linux LUKS
- the disk model and total size identify the internal drive

## 16. Format the EFI System Partition

```sh
mkfs.fat -F 32 -n ESP /dev/nvme0n1p1
```

## 17. Create the LUKS2 container

Run:

```sh
cryptsetup luksFormat \
  --type luks2 \
  --verify-passphrase \
  --label cryptroot \
  /dev/nvme0n1p2
```

This command is destructive.

Type uppercase `YES` only after rechecking that `/dev/nvme0n1p2` is the large
second partition on the internal drive.

Enter the LUKS passphrase twice.

## 18. Open the encrypted container

```sh
cryptsetup open /dev/nvme0n1p2 cryptroot
cryptsetup status cryptroot
```

The decrypted device is now:

```text
/dev/mapper/cryptroot
```

## 19. Create btrfs

```sh
mkfs.btrfs -L arch /dev/mapper/cryptroot
```

## 20. Create the btrfs subvolumes

```sh
mount /dev/mapper/cryptroot /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home

umount /mnt
```

## 21. Mount the target system

```sh
mount -o subvol=@,compress=zstd,noatime \
  /dev/mapper/cryptroot /mnt

mkdir -p /mnt/home /mnt/boot

mount -o subvol=@home,compress=zstd,noatime \
  /dev/mapper/cryptroot /mnt/home

mount /dev/nvme0n1p1 /mnt/boot
```

Verify:

```sh
findmnt /mnt
findmnt /mnt/home
findmnt /mnt/boot
lsblk -f
```

Expected structure:

- `/mnt` is btrfs through `/dev/mapper/cryptroot`, subvolume `@`
- `/mnt/home` is the same encrypted btrfs filesystem, subvolume `@home`
- `/mnt/boot` is the FAT32 EFI partition
- there is no swap partition

---

# Part V: Install the base system

## 22. Install the minimum bootable system

```sh
pacstrap -K /mnt \
  base \
  linux \
  linux-firmware \
  amd-ucode \
  btrfs-progs \
  cryptsetup \
  networkmanager \
  fish \
  neovim \
  sudo \
  man-db \
  man-pages \
  git \
  curl
```

## 23. Generate and inspect `fstab`

```sh
genfstab -U /mnt > /mnt/etc/fstab
cat /mnt/etc/fstab
```

Verify:

- `/` uses `subvol=/@`
- `/home` uses `subvol=/@home`
- both btrfs entries include `compress=zstd` and `noatime`
- `/boot` is the EFI partition
- there is no disk-swap entry

Do not continue if the mount targets are wrong.

---

# Part VI: Configure the installed system

## 24. Enter the chroot

```sh
arch-chroot /mnt
```

Everything until the explicit `exit` command now operates inside the installed
system.

## 25. Configure time

```sh
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
```

## 26. Configure locale

```sh
sed -i 's/^#en_CA.UTF-8 UTF-8/en_CA.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

locale-gen

printf 'LANG=en_CA.UTF-8\n' > /etc/locale.conf
printf 'KEYMAP=us\n' > /etc/vconsole.conf
```

## 27. Configure hostname

```sh
printf 'momiji\n' > /etc/hostname
```

## 28. Create the human account

Set the root recovery password:

```sh
passwd
```

Create the one human user:

```sh
useradd -m -G wheel -s /usr/bin/fish noah
passwd noah
```

Grant the wheel group normal password-protected `sudo` access:

```sh
install -d -m 0750 /etc/sudoers.d

printf '%%wheel ALL=(ALL:ALL) ALL\n' \
  > /etc/sudoers.d/10-wheel

chmod 440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers.d/10-wheel
```

The final command must report that the file parsed successfully.

## 29. Clone the exact repository branch as `noah`

```sh
runuser -u noah -- git clone \
  --branch main \
  --single-branch \
  https://github.com/NoahWLono/momiji-dots.git \
  /home/noah/momiji-dots
```

Verify the branch:

```sh
runuser -u noah -- git \
  -C /home/noah/momiji-dots \
  branch --show-current
```

It must print:

```text
main
```

## 30. Install the repository-owned hosts file

```sh
install -Dm644 \
  /home/noah/momiji-dots/etc/hosts \
  /etc/hosts

cat /etc/hosts
```

## 31. Enable first-boot services

```sh
systemctl enable NetworkManager.service
systemctl enable systemd-timesyncd.service
```

Make the systemd journal persistent so logs survive reboots and crashes on
the machine that will be debugged most:

```sh
install -d /var/log/journal
```

## 32. Validate the cloned repository

```sh
runuser -u noah -- bash -lc \
  'cd /home/noah/momiji-dots && ./scripts/validate-repo.sh'
```

At this early stage, a missing Lua parser may produce a warning. There must be
zero failures.

## 33. Install the encrypted initramfs configuration

```sh
install -Dm644 \
  /home/noah/momiji-dots/etc/mkinitcpio.conf.d/momiji-encryption.conf \
  /etc/mkinitcpio.conf.d/momiji-encryption.conf

cat /etc/mkinitcpio.conf.d/momiji-encryption.conf
```

The `HOOKS` line must include this order:

```text
systemd ... block sd-encrypt filesystems
```

Generate the initramfs:

```sh
mkinitcpio -P
```

This must complete without an error.

## 34. Install systemd-boot

```sh
bootctl install
install -d /boot/loader/entries
```

Install the repository's loader configuration:

```sh
install -Dm644 \
  /home/noah/momiji-dots/boot/loader.conf \
  /boot/loader/loader.conf
```

## 35. Generate the encrypted Arch boot entry

Get the LUKS container UUID:

```sh
LUKS_UUID=$(cryptsetup luksUUID /dev/nvme0n1p2)
test -n "$LUKS_UUID"
printf '%s\n' "$LUKS_UUID"
```

Substitute it into the repository template:

```sh
sed "s/LUKS_UUID_PLACEHOLDER/$LUKS_UUID/" \
  /home/noah/momiji-dots/boot/arch.conf.template \
  > /boot/loader/entries/arch.conf
```

Inspect it:

```sh
cat /boot/loader/entries/arch.conf
```

It must contain:

```text
rd.luks.name=<the-LUKS-UUID>=cryptroot
rd.luks.options=discard
root=/dev/mapper/cryptroot
rootflags=subvol=@
```

Verify automatically:

```sh
grep -F "rd.luks.name=$LUKS_UUID=cryptroot" \
  /boot/loader/entries/arch.conf

grep -F 'rd.luks.options=discard' \
  /boot/loader/entries/arch.conf

grep -F 'root=/dev/mapper/cryptroot' \
  /boot/loader/entries/arch.conf

grep -F 'rootflags=subvol=@' \
  /boot/loader/entries/arch.conf
```

The discard option lets weekly `fstrim` pass through the encrypted mapping.
The tradeoff is that free-space patterns become observable on the raw device,
which is acceptable for this threat model.

## 36. Perform final chroot checks

```sh
ls -lh \
  /boot/vmlinuz-linux \
  /boot/initramfs-linux.img \
  /boot/loader/loader.conf \
  /boot/loader/entries/arch.conf

bootctl list
systemctl is-enabled NetworkManager.service
systemctl is-enabled systemd-timesyncd.service
```

Both services should report `enabled`.

## 37. Leave the chroot and reboot

```sh
exit
```

Back in the live ISO:

```sh
sync
umount -R /mnt
cryptsetup close cryptroot
reboot
```

Remove the installer USB when the machine begins rebooting.

---

# Part VII: First encrypted boot

## 38. Unlock the disk

systemd-boot starts the encrypted Arch entry.

Enter the LUKS passphrase when prompted.

This first boot intentionally ends at a text login. SDDM is installed and
enabled later, after Hyprland and Caelestia have been tested.

## 39. Log in as `noah`

At the tty prompt:

```text
login: noah
password: <the noah account password>
```

## 40. Connect Wi-Fi through NetworkManager

```sh
nmcli device wifi list

nmcli device wifi connect \
  "YourSSID" \
  password "yourpassword"

ping -c 3 archlinux.org
```

## 41. Confirm the repository and branch

```sh
cd ~/momiji-dots

git status --short
git branch --show-current
git log -1 --oneline
```

Expected branch:

```text
main
```

## 42. Update the base system

```sh
sudo pacman -Syu
```

Never use:

```text
pacman -Sy <package>
```

## 43. Run the Arch-aware repository validation

```sh
cd ~/momiji-dots
./scripts/validate-repo.sh --arch --aur
```

Stop if this reports any failure. A package name may have changed since the
branch was published, and that must be corrected before running the installer.

## 44. Install the repository package payload

```sh
cd ~/momiji-dots
./scripts/install-packages.sh
```

This script:

- installs the official repository package list
- bootstraps `paru-bin` when `paru` is absent
- installs the AUR application list when it has entries
- installs the repository zram configuration
- enables Bluetooth and power-profile services
- enables periodic SSD trimming

When prompted by `makepkg` or `paru`, inspect the package details before
continuing.

## 45. Verify the package stage

```sh
command -v Hyprland
command -v paru
command -v sddm

systemctl is-enabled bluetooth.service
systemctl is-enabled power-profiles-daemon.service
systemctl is-enabled fstrim.timer
```

SDDM is installed but is not enabled yet.

---

# Part VIII: Install Caelestia

## 46. Install the stable Caelestia CLI

```sh
paru -S --needed caelestia-cli
```

## 47. Run the Caelestia installer

```sh
caelestia install --aur-helper paru
```

Use the default components unless you have a specific reason to change them.

Optional components may include Spotify, VS Code, VSCodium, Zed, Discord,
Todoist, uwsm, and others. Choose only the applications you intend to use.

For an editor, choose either VS Code or VSCodium unless you deliberately want
both.

Allow the installation to finish completely. Some components compile software
and can take a while on the laptop.

## 48. Confirm Caelestia created its configuration

```sh
test -f ~/.config/hypr/hyprland.lua
test -f ~/.config/caelestia/hypr-vars.lua
```

Both commands must return silently with status zero.

---

# Part IX: Test Hyprland before enabling SDDM

## 49. Start Hyprland manually

From the tty:

```sh
Hyprland
```

A manual launch is the safety gate. Do not enable SDDM until this works.

## 50. Open a terminal

Use:

```text
Super+T
```

Inside the terminal, deploy the repository configuration:

```sh
cd ~/momiji-dots
./scripts/deploy-configs.sh
```

Because this runs inside Hyprland, the script can also apply the Maple wallpaper
and dynamic colour scheme.

## 51. Restart the Caelestia shell after deployment

Use:

```text
Ctrl+Super+Alt+R
```

Or run:

```sh
caelestia shell -k
sleep 1
caelestia shell -d
```

## 52. Test the desktop

Run:

```sh
hyprctl monitors
wpctl status
nmcli general status
caelestia scheme get
```

Test these interactions:

- `Super`: launcher
- `Super+T`: terminal
- `Super+W`: Firefox
- `Super+E`: file manager
- `Super+L`: lock screen
- `Super+1`, `Super+2`: workspace switching
- volume keys
- brightness keys
- Wi-Fi panel
- Bluetooth panel
- notification panel

Confirm:

- Maple is the wallpaper
- Caelestia is visible
- the dynamic colour scheme is active
- audio output appears in `wpctl status`
- an audio input appears, or the microphone troubleshooting section applies
- no red Lua configuration error appears
- `pkexec true` raises a graphical authentication prompt, confirming the
  polkit agent is alive
- locking requires the `noah` password

## 53. Exit the manual session

From a terminal:

```sh
hyprctl dispatch exit
```

You should return to the tty.

---

# Part X: Enable the normal graphical login

## 54. Enable SDDM using the repository script

```sh
cd ~/momiji-dots
./scripts/enable-display-manager.sh
```

The script:

- installs the repository SDDM configuration
- removes remnants of the old tty autologin design
- sets `graphical.target`
- enables `sddm.service`
- keeps autologin disabled

Verify:

```sh
systemctl is-enabled sddm.service
systemctl get-default
```

Expected:

```text
enabled
graphical.target
```

## 55. Reboot into the final login flow

```sh
reboot
```

The sequence should now be:

1. systemd-boot
2. LUKS passphrase
3. SDDM graphical login

At the first SDDM screen:

1. select the **Hyprland** session
2. select or enter user `noah`
3. enter the `noah` password

SDDM should remember the last user and session, but it must continue asking for
the password.

---

# Part XI: Final acceptance tests

## 56. Verify encryption and mounts

After logging in:

```sh
lsblk -f
findmnt /
findmnt /home
findmnt /boot
```

Expected:

- `/` and `/home` originate through `/dev/mapper/cryptroot`
- `/boot` is the unencrypted FAT32 EFI partition
- no personal data partition is mounted outside LUKS

Verify TRIM passes through the encrypted mapping:

```sh
sudo fstrim -v /
```

It must print a trimmed byte count. `the discard operation is not supported`
means `rd.luks.options=discard` is missing from the boot entry; the weekly
timer runs with `--quiet-unsupported` and would hide that failure forever.

## 57. Verify zram

```sh
swapon --show
zramctl
```

Expected swap device:

```text
/dev/zram0
```

There should be no NVMe swap partition or swapfile.

## 58. Verify the graphical login service

```sh
systemctl status sddm.service
```

It should be active.

## 59. Verify network, audio, and power services

```sh
systemctl status NetworkManager.service
systemctl status bluetooth.service
systemctl status power-profiles-daemon.service

wpctl status
powerprofilesctl
```

## 60. Test lock, suspend, and resume

First test the lock screen:

```text
Super+L
```

Then test suspend with disposable work open:

```sh
systemctl suspend
```

Wake the laptop.

The session should return locked. If it resumes unlocked, manually lock before
closing the lid until the idle and lock configuration is corrected.

This layout intentionally does not support hibernation.

---

# Part XII: Finish security and recovery setup

## 61. Enable the firewall

```sh
sudo pacman -S --needed ufw

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

sudo systemctl enable ufw.service
sudo ufw status verbose
```

## 62. Create the baseline root snapshot

```sh
sudo pacman -S --needed snapper snap-pac

sudo snapper -c root create-config /
sudo snapper -c root create \
  -d "baseline encrypted Momiji install"

sudo snapper -c root list
```

The root snapshot does not include the separate `@home` subvolume.

Snapshots are not backups.

## 63. Back up the LUKS header

Connect trusted external storage and identify its mounted path.

Then run, replacing the destination path:

```sh
sudo cryptsetup luksHeaderBackup \
  /dev/nvme0n1p2 \
  --header-backup-file \
  /path/on/external-media/momiji-luks-header.img
```

Store the header backup away from the laptop.

Never commit it to Git, upload it publicly, or keep its only copy on the
encrypted drive.

## 64. Start a system journal

```sh
mkdir -p ~/notes

cat >> ~/notes/journal.md <<'EOF'
# Momiji system journal

- Installed from main
- LUKS2 root and home
- btrfs @ and @home
- zram swap
- SDDM login
- Hyprland and Caelestia
EOF
```

Record every non-obvious configuration change and every rollback.

## 65. Run the final repository validation

```sh
cd ~/momiji-dots

./scripts/validate-repo.sh --arch --aur
git status
```

The validator must report zero failures.

---

# Part XIII: Optional applications and rice

## 66. Install the optional terminal extras

```sh
~/momiji-dots/scripts/install-fun.sh
```

This is deliberately separate from the boot-critical installation.

## 67. Test the optional Maple fastfetch configuration

```sh
fastfetch \
  --config \
  ~/momiji-dots/rice/fastfetch/config-maple.jsonc
```

Only replace Caelestia's fastfetch configuration if you prefer the result.

## 68. Understand the optional pony greeting

The Fish greeting works without the custom Clock pony. When the optional pony
file is absent, ponysay uses its normal roster.

See:

```text
~/momiji-dots/rice/ponies/README.md
```

## 69. Configure Proton VPN through WireGuard

Generate a WireGuard configuration in the Proton account dashboard.

Keep the downloaded private configuration out of Git.

Import it:

```sh
nmcli connection import \
  type wireguard \
  file ~/Downloads/proton.conf

nmcli connection show
```

Bring it up using the actual imported connection name:

```sh
nmcli connection up "<connection-name>"
```

## 70. Defer experimental rice until after the baseline

Read:

```text
~/momiji-dots/rice/RICING.md
```

That file covers optional work such as:

- paw cursor
- lid sounds
- dynamic cursor plugin
- animation tuning
- window rules
- workspace startup
- personal keybindings

Make one change at a time and record it in the journal.

---

# Troubleshooting

## The Arch USB does not boot

Check:

- Secure Boot is disabled
- the USB was written to the correct whole device
- the UEFI USB entry was selected
- the ISO was not merely copied as a file onto a normal FAT volume

## The LUKS passphrase is rejected

Check:

- Caps Lock
- keyboard layout
- whether the passphrase contains a layout-dependent symbol
- whether you are typing the LUKS passphrase rather than the `noah` password

## The passphrase is accepted but root does not mount

Boot the Arch ISO and connect the network.

Open and mount the encrypted system:

```sh
cryptsetup open /dev/nvme0n1p2 cryptroot

mount -o subvol=@ \
  /dev/mapper/cryptroot /mnt

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

The UUID printed by `cryptsetup luksUUID` must match the UUID in
`rd.luks.name=`.

## SDDM does not appear

Switch to tty2:

```text
Ctrl+Alt+F2
```

Log in as `noah`.

Check:

```sh
systemctl status sddm.service
journalctl -b -u sddm.service
```

Temporarily disable it:

```sh
sudo systemctl disable --now sddm.service
sudo systemctl set-default multi-user.target
```

Test manually:

```sh
Hyprland
```

After fixing the issue:

```sh
cd ~/momiji-dots
./scripts/enable-display-manager.sh
reboot
```

## Hyprland starts but Caelestia does not

Inside Hyprland:

```sh
caelestia shell -l
caelestia shell -k
sleep 1
caelestia shell -d
```

Reapply repository configuration:

```sh
cd ~/momiji-dots
./scripts/deploy-configs.sh
```

## Wi-Fi is unreliable

Do not install driver workarounds preemptively.

First confirm which driver this unit actually uses (recorded in the journal
during the live-ISO phase):

```sh
lspci -knn | grep -iA3 net
```

Then inspect kernel messages for that driver:

```sh
dmesg | grep -iE 'rtw89|rtw88|mt7921'
journalctl -k -b | grep -iE 'rtw89|rtw88|mt7921'
```

The NetworkManager power-saving override is driver-agnostic. Disable Wi-Fi
power saving only when symptoms match:

```sh
sudo install -Dm644 \
  ~/momiji-dots/etc/wifi-powersave.conf \
  /etc/NetworkManager/conf.d/wifi-powersave.conf

sudo systemctl restart NetworkManager
```

The module options in `etc/rtw89.conf` apply only when the driver in use is
`rtw89`. Before using them, verify the running module supports the named
parameters:

```sh
modinfo rtw89_pci |
  grep -E 'disable_aspm_l1|disable_clkreq'
```

Then, only when both parameters exist:

```sh
sudo install -Dm644 \
  ~/momiji-dots/etc/rtw89.conf \
  /etc/modprobe.d/rtw89.conf

sudo reboot
```

For `rtw88` or `mt7921e` cards, stop at the power-saving override, record the
symptoms and kernel messages in the journal, and research that module's own
parameters before writing anything to `/etc/modprobe.d/`.

## The microphone is missing

```sh
wpctl status

arecord -d 3 /tmp/mic-test.wav
aplay /tmp/mic-test.wav

dmesg | grep -iE 'sof|acp|audio'
```

Confirm:

```sh
pacman -Q sof-firmware alsa-utils
```

Do not edit PipeWire configuration before confirming that the hardware driver
and firmware are present.

## zram is missing after the final reboot

```sh
cat /etc/systemd/zram-generator.conf
systemctl daemon-reload
systemctl list-units 'dev-zram*.swap'
zramctl
```

The repository source is:

```text
~/momiji-dots/etc/zram-generator.conf
```

Reinstall it when necessary:

```sh
sudo install -Dm644 \
  ~/momiji-dots/etc/zram-generator.conf \
  /etc/systemd/zram-generator.conf

sudo systemctl daemon-reload
sudo reboot
```

---

# Normal update routine

Use:

```sh
caelestia update
```

For ordinary package work, use:

```sh
paru
```

Never create a partial upgrade with:

```text
pacman -Sy <package>
```

Before any future reinstall:

```sh
cd ~/momiji-dots
git switch main
git pull --ff-only

./scripts/validate-repo.sh --arch --aur
```

---

# Final done state

The machine is complete when all of the following are true:

- [ ] the internal data partition is LUKS2 encrypted
- [ ] `/` uses btrfs subvolume `@`
- [ ] `/home` uses btrfs subvolume `@home`
- [ ] `/boot` is the 1 GiB EFI System Partition
- [ ] the machine asks for the LUKS passphrase at boot
- [ ] SDDM shows a normal graphical login screen
- [ ] SDDM does not autologin
- [ ] `noah` can log into the Hyprland session
- [ ] Caelestia starts correctly
- [ ] Maple is applied as the wallpaper
- [ ] dynamic colours work
- [ ] networking works
- [ ] audio output works
- [ ] microphone input has been tested
- [ ] zram appears as `/dev/zram0`
- [ ] the firewall is enabled
- [ ] a baseline root snapshot exists
- [ ] a LUKS header backup exists on separate trusted media
- [ ] `./scripts/validate-repo.sh --arch --aur` reports zero failures
- [ ] every deviation is recorded in `~/notes/journal.md`

At that point, the laptop has moved from sealed box to an encrypted Momiji
desktop with a normal login page. Experimental ricing can begin from a known,
documented, recoverable baseline.
