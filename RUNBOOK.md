# Momiji Runbook: HP 255 G10 → Arch + Hyprland + Caelestia

From sealed box to Maple on the lock screen. Manual install, no archinstall, no greeter.

**Baked-in decisions** (change them if you disagree, but change them *before* Phase 3):

| Decision | Value |
|---|---|
| Windows 11 Pro | Fully wiped. License stays in firmware (ACPI MSDM), so a future Windows reinstall self-activates. Nothing to back up on a new unit. |
| Filesystem | btrfs, subvolumes `@` (root) and `@home`, `compress=zstd,noatime` |
| Partitions | 1 GiB ESP at `/boot`, 20 GiB swap, rest btrfs |
| Bootloader | systemd-boot |
| Login | getty autologin on tty1, fish execs Hyprland. No display manager. |
| Hostname | `momiji` (suggestion, pick your own) |
| User | `noah`, shell fish |
| Locale / TZ | `en_CA.UTF-8` / `America/Toronto` |
| AUR helper | `paru-bin` |
| Rice | Caelestia via `caelestia-cli` (verified against the repos, July 2026) |

**Honest uncertainty flags:** anything marked ⚠ is from memory or subject to upstream drift. The Caelestia sections were checked against the live GitHub repos in July 2026; the HP BIOS behavior and exact `caelestia` CLI flags were not independently verifiable. When the doc and reality disagree, reality and the Arch wiki win.

**One upstream disagreement with your plan:** Caelestia's own README recommends greetd + tuigreet, the exact packages we deleted from your list. It also explicitly supports TTY login, which is what you chose. Your call stands; just know the maintainer's default differs, so if a future Caelestia update assumes a display manager, this is the seam to check.

---

## Phase 0: While the mail is in transit

1. **Flash the USB now.** Download the ISO from a mirror, verify it, write it:
   ```
   # from your main machine (Linux). Triple-check the target device with lsblk first.
   sudo dd if=archlinux-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
   Ventoy also works if you prefer a multi-ISO stick.
2. **Dotfiles repo** on GitHub with, at minimum:
   - `packages.txt` (the day-1 list from Phase 7, one package per line)
   - `wallpapers/maple.png` (your file is 1672x941, exactly 16:9. It will upscale about 1.15x to the 1080p panel, which is fine. If you have a larger original, use that instead.)
   - `autologin.conf` and `10-tty1-hyprland.fish` (contents in Phase 7, pre-author them)
3. **Read once, skim twice:** the Arch wiki Installation Guide. This runbook is a condensation with your decisions filled in; the wiki is canonical when they differ.
4. Confirm you can reach your router's 2.4 GHz and 5 GHz SSIDs and know the passwords. Have an RJ45 cable within reach if possible; the 255 G10 has an ethernet port (⚠ from spec sheets; verify on the physical unit) and it removes the wifi driver from the critical path entirely.

---

## Phase 1: Unboxing and firmware (day 1)

1. **Optional but recommended: boot Windows exactly once** to update the BIOS via HP Support Assistant, then never again. Reason: HP ships firmware updates primarily through Windows tooling. LVFS/fwupd coverage for the 255 G10 is uncertain (⚠), and post-wipe BIOS updates mean HP's bootable-USB method. If you skip this, nothing breaks; it just gets more annoying later. Use an offline local account during Windows setup (press Shift+F10 at the network screen, run `oobe\bypassnro` if it insists on Microsoft accounts) since you're wiping it anyway.
2. **Enter BIOS setup:** power on and tap `Esc` for the HP Startup Menu, then `F10` for setup. (`F9` is the one-time boot menu; you'll want it later.) ⚠ Key timing on HP is tight; start tapping immediately.
3. In setup:
   - **Disable Secure Boot** (usually under System Configuration → Boot Options). The Arch ISO is unsigned and will not boot with it on.
   - **Disable Fast Boot** in the same area.
   - Confirm boot mode is **UEFI**, no Legacy/CSM.
4. Save and exit. ⚠ HP consumer boards often interrupt the next boot with an "Operating System Boot Mode Change" screen demanding you type a displayed 4-digit code and press Enter to confirm the Secure Boot change. This is normal, not malware. Type the code.

---

## Phase 2: Boot the live ISO

1. Plug in the USB, power on, tap `Esc`, then `F9`, pick the USB (UEFI entry). You should land at a zsh prompt as root.
2. **Confirm UEFI mode:**
   ```
   cat /sys/firmware/efi/fw_platform_size
   ```
   Must print `64`. If the file doesn't exist, you booted legacy; go fix the BIOS.
3. **Network.** In order of reliability:
   - **Ethernet:** plug in, wait five seconds, done.
   - **Wifi (rtw89 usually works on the live ISO):**
     ```
     iwctl
     [iwd]# device list
     [iwd]# station wlan0 scan
     [iwd]# station wlan0 get-networks
     [iwd]# station wlan0 connect "YourSSID"
     [iwd]# exit
     ```
   - **Fallback:** USB-tether your phone. It shows up as ethernet, zero drama.
4. Verify: `ping -c 3 archlinux.org`
5. `timedatectl` should already show NTP synchronized. If the console font is ant-sized on the 1080p panel: `setfont ter-132b`.

---

## Phase 3: Disk (this is where Windows dies)

Everything below destroys the entire disk. There is no undo after `w`.

1. Identify the disk:
   ```
   lsblk
   ```
   Expect `/dev/nvme0n1` around 256 to 512 GB. If your unit shows something else (⚠ some budget Mendocino boards use eMMC, named `mmcblk0`, with partitions `mmcblk0p1` etc.), substitute names accordingly for the rest of this doc.
2. Partition with fdisk:
   ```
   fdisk /dev/nvme0n1
   ```
   Keystrokes, in order:
   - `g` (new empty GPT, erases the old table)
   - `n`, partition `1`, default first sector, size `+1G`
   - `t`, partition `1`, type `1` (EFI System)
   - `n`, partition `2`, default, size `+20G`
   - `t`, partition `2`, type `19` (Linux swap)
   - `n`, partition `3`, defaults for everything (uses the rest of the disk)
   - `p` to review. ESP ~1G, swap 20G, big Linux partition.
   - `w` to write and exit.
3. Format:
   ```
   mkfs.fat -F 32 -n ESP /dev/nvme0n1p1
   mkswap -L swap /dev/nvme0n1p2
   mkfs.btrfs -L arch /dev/nvme0n1p3
   ```
4. Create subvolumes and mount. The `@` / `@home` split is what lets future-you nuke and reinstall root while keeping home intact, and it's what snapshots operate on (Appendix D):
   ```
   mount /dev/nvme0n1p3 /mnt
   btrfs subvolume create /mnt/@
   btrfs subvolume create /mnt/@home
   umount /mnt

   mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p3 /mnt
   mkdir -p /mnt/home /mnt/boot
   mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p3 /mnt/home
   mount /dev/nvme0n1p1 /mnt/boot
   swapon /dev/nvme0n1p2
   ```
   If you decide btrfs is one new thing too many: `mkfs.ext4` on p3, mount it at `/mnt`, skip the subvolume block, drop `rootflags=subvol=@` from the boot entry later, and skip Appendix D. Everything else is identical.

---

## Phase 4: Install the base system

1. ```
   pacstrap -K /mnt base linux linux-firmware amd-ucode btrfs-progs networkmanager fish neovim sudo man-db man-pages
   ```
   Why each: `linux-firmware` is your amdgpu no-black-screen insurance. `amd-ucode` is CPU microcode (the initramfs picks it up automatically, see Phase 5). `btrfs-progs` or the filesystem is unmanageable. `networkmanager` and an editor now, so first boot isn't a stranded system. `fish` now so the user account can be created with it as login shell.
2. Generate and *verify* the fstab:
   ```
   genfstab -U /mnt >> /mnt/etc/fstab
   cat /mnt/etc/fstab
   ```
   You want to see: `/` with `subvol=/@`, `/home` with `subvol=/@home`, both with `compress=zstd` and `noatime`, `/boot` as vfat, and the swap partition.

---

## Phase 5: Configure from inside (chroot)

```
arch-chroot /mnt
```

1. **Time:**
   ```
   ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
   hwclock --systohc
   ```
2. **Locale:** edit `/etc/locale.gen` with nvim and uncomment both `en_CA.UTF-8 UTF-8` and `en_US.UTF-8 UTF-8`, then:
   ```
   locale-gen
   echo 'LANG=en_CA.UTF-8' > /etc/locale.conf
   ```
3. **Hostname:**
   ```
   echo momiji > /etc/hostname
   ```
   And `/etc/hosts`:
   ```
   127.0.0.1   localhost
   ::1         localhost
   127.0.1.1   momiji
   ```
4. **Services that must exist before first boot:**
   ```
   systemctl enable NetworkManager systemd-timesyncd
   ```
5. **Initramfs sanity check** (no changes expected, just verify):
   ```
   grep ^HOOKS /etc/mkinitcpio.conf
   ```
   Current mkinitcpio defaults include `microcode` and `kms` in HOOKS. `microcode` folds amd-ucode into the initramfs, which is why the boot entry below has no separate ucode line. `kms` gets amdgpu in early. If either is missing (very old ISO), add them and run `mkinitcpio -P`.
6. **Accounts:**
   ```
   passwd                                    # root password
   useradd -m -G wheel -s /usr/bin/fish noah
   passwd noah
   EDITOR=nvim visudo                        # uncomment: %wheel ALL=(ALL:ALL) ALL
   ```
7. **Bootloader:**
   ```
   bootctl install
   ```
   Create `/boot/loader/loader.conf`:
   ```
   default arch.conf
   timeout 3
   console-mode max
   ```
   Create `/boot/loader/entries/arch.conf`:
   ```
   title   Arch Linux
   linux   /vmlinuz-linux
   initrd  /initramfs-linux.img
   options root=UUID=XXXX rootflags=subvol=@ rw
   ```
   To get the UUID without typos, from inside nvim on that file run:
   ```
   :r !blkid -s UUID -o value /dev/nvme0n1p3
   ```
   then splice it onto the options line. This must be partition 3's UUID, not the ESP's, not swap's.
8. **Leave and reboot:**
   ```
   exit
   umount -R /mnt
   reboot
   ```
   Yank the USB when the screen goes dark. You should land at a `momiji login:` prompt on tty1. That prompt is the whole base install, done.

---

## Phase 6: First boot sanity

1. Log in as `noah` at the tty.
2. Wifi, now via NetworkManager:
   ```
   nmcli device wifi connect "YourSSID" password "yourpassword"
   ping -c 3 archlinux.org
   ```
   (`nmtui` if you prefer a menu. The credential is stored; this is a one-time step.)
3. Confirm sudo works and sync:
   ```
   sudo pacman -Syu
   ```
4. `timedatectl` should show the correct Montreal time and NTP active.
5. Start the log habit now, while the system is one hour old:
   ```
   mkdir -p ~/notes && nvim ~/notes/journal.md
   ```
   First entry: date, "installed per runbook", and anything that deviated. Every non-obvious change to this machine gets a line here, forever. This file is the difference between debugging and archaeology.

---

## Phase 7: Day-1 payload (packages, autologin, Hyprland)

1. **The package list, final revision.** Two removals versus the list we fixed earlier, both because the Caelestia manifest was checked and decides for us:
   - `hyprpolkitagent` removed: Caelestia's `auth` component installs and launches `polkit-gnome` itself. Two polkit agents is one and a half too many.
   - `uwsm` removed from day 1: Caelestia ships uwsm as an *optional* component with its own config. If you want it, enable it through Caelestia (Appendix E), don't pre-install it.

   ```
   sudo pacman -S --needed \
     mesa vulkan-radeon vulkan-icd-loader vulkan-tools libva-utils \
     hyprland xorg-xwayland \
     xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
     qt5-wayland qt6-wayland \
     hypridle hyprlock hyprpicker hyprsunset \
     gnome-keyring libsecret \
     pipewire pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack \
     wireplumber pavucontrol playerctl \
     networkmanager network-manager-applet \
     bluez bluez-utils blueman \
     power-profiles-daemon upower brightnessctl lm_sensors ddcutil \
     udisks2 udiskie gvfs gvfs-mtp gvfs-smb gvfs-gphoto2 exfatprogs \
     sof-firmware \
     noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd \
     foot fish starship fastfetch btop thunar firefox \
     wl-clipboard cliphist grim slurp swappy \
     neovim tmux fzf fd ripgrep bat eza zoxide jq lazygit \
     base-devel git usbutils
   ```
   If you put this in your repo as `packages.txt` (one per line, `#` comments allowed):
   ```
   curl -LO https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/packages.txt
   sudo pacman -S --needed - < packages.txt
   ```
   Much of this overlaps with what `caelestia install` pulls later (foot, fish, starship, thunar, pipewire, fonts, and more, per its manifest). `--needed` makes the overlap free.

2. **Enable services:**
   ```
   sudo systemctl enable --now bluetooth power-profiles-daemon
   sudo systemctl enable fstrim.timer
   ```
   PipeWire runs as user services via socket activation, nothing to enable. Verify with `wpctl status` (you should see your outputs and, thanks to `sof-firmware`, an internal mic; if the mic is absent, one reboot after this install usually surfaces it, see Appendix B).

3. **Test-launch Hyprland once, manually, before wiring autologin.** From the tty:
   ```
   Hyprland
   ```
   You get the default config with a yellow "you have not configured Hyprland" bar. That is success. One catch: the auto-generated config binds Super+Q to kitty, which you did not install. Exit with `Super+M`, then:
   ```
   sed -i 's/kitty/foot/' ~/.config/hypr/hyprland.conf
   ```
   Now Super+Q opens foot. This config gets replaced wholesale by Caelestia in Phase 9; the sed just makes the interim session usable.

4. **Autologin drop-in.** Create the directory and file:
   ```
   sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
   sudoedit /etc/systemd/system/getty@tty1.service.d/autologin.conf
   ```
   Contents:
   ```
   [Service]
   ExecStart=
   ExecStart=-/usr/bin/agetty --autologin noah --noclear %I $TERM
   ```
   Then `sudo systemctl daemon-reload`.

5. **Fish execs Hyprland on tty1.** Put this in `~/.config/fish/conf.d/10-tty1-hyprland.fish` rather than `config.fish`, because Caelestia's fish component will later copy its own files into `~/.config/fish` and a separate conf.d file survives that:
   ```fish
   if status is-login; and test (tty) = /dev/tty1; and not set -q WAYLAND_DISPLAY
       exec Hyprland
   end
   ```
   The `WAYLAND_DISPLAY` guard stops nested launches. Note the failure mode this design has: if Hyprland ever crashes, getty restarts, autologin fires, Hyprland relaunches, and a hard crash therefore loops. The escape hatch is `Ctrl+Alt+F2`: a clean tty2 login where the exec condition is false and you can fix things. Remember that chord.

6. **Reboot.** The machine should go firmware → systemd-boot (3s) → tty1 flashes past → Hyprland, no password, no greeter. Lock/idle security comes from Caelestia's lock screen plus `hyprlock`/`hypridle` once configured; until then this laptop is a walk-up-and-own-it device, which is fine for week one of a tinker box.

---

## Phase 8: AUR bootstrap

```
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin && makepkg -si
cd .. && rm -rf paru-bin
```

`paru-bin` and not `paru` because compiling a Rust codebase on four Zen 2 cores is a scheduled break you did not ask for. From here on, `paru` handles AUR and repo packages alike.

---

## Phase 9: Caelestia

Verified against `caelestia-dots` on GitHub, July 2026. The old `install.fish` route is deprecated; the CLI does everything now.

1. ```
   paru -S caelestia-cli
   caelestia install
   ```
   Expect real compile time: this pulls `caelestia-shell`, which needs `quickshell-git` (git version required, per their README) plus a C++/QML build. On the 7320U, plug into AC and let it cook. Tens of minutes is normal, not a hang.

2. **What `caelestia install` does** (from its manifest, so you are not surprised):
   - Default components copy configs into `~/.config` for: hypr, fish, foot, fastfetch, btop, micro, thunar, starship, plus GTK/Qt theming (adw-gtk-theme, Papirus, Darkly) and auth (gnome-keyring, polkit-gnome).
   - The **firefox component writes `userChrome.css` and `user.js` into your Firefox profile** for theming. If Firefox looks different afterwards, that is why. Delete those two files from the profile to revert.
   - The tools component adds `trash-cli`, `ydotool`, `xdg-user-dirs`, and friends.
   - Optional components exist for spotify, vscodium, vscode, zed, discord (equibop), todoist, uwsm, and zen-browser. Decline anything you don't want; components can be added later by rerunning. ⚠ The exact prompting flow may differ; read what it asks.
3. **Point the browser keybind at Firefox.** Caelestia's default Super+W targets zen. Their Hyprland config is configured through Lua now; create `~/.config/caelestia/hypr-vars.lua`:
   ```lua
   return {
       browser = "firefox",
   }
   ```
   ⚠ Variable name taken from their README example; if it doesn't bite, check their docs for the current key.
4. **Get into the real session.** The shell autostarts via an exec-once in Caelestia's Hyprland config, so the cleanest move after install finishes: log out of the interim default session (`hyprctl dispatch exit` from a terminal) and let autologin drop you into the Caelestia-configured one.
5. **Keybinds to know on day one:** `Super` opens the launcher, `Super+T` terminal (foot, which is why it was in your list), `Super+#` workspaces, `Ctrl+Alt+Delete` session menu, `Ctrl+Super+Alt+R` restarts the shell after config edits.
6. Updates later: `caelestia update` handles system plus dots together.

---

## Phase 10: Maple

1. Get the art onto the machine (it should already be in your dotfiles repo):
   ```
   mkdir -p ~/Pictures/Wallpapers
   cp ~/path/to/repo/wallpapers/maple.png ~/Pictures/Wallpapers/
   ```
2. Set it:
   ```
   caelestia wallpaper -f ~/Pictures/Wallpapers/maple.png
   ```
   ⚠ Flag syntax from memory; `caelestia wallpaper --help` is authoritative. Bare `caelestia wallpaper` picks randomly from the wallpapers directory, which with exactly one image is also correct behavior, permanently.
3. The shell generates its Material color scheme from the wallpaper when the scheme is set to dynamic. If the colors don't follow the image, check `caelestia scheme list` and set the dynamic one (`caelestia scheme set -n dynamic`, ⚠ name per current docs). The install seeds a static default scheme, so this switch may be needed once.
4. Audit the result: her sky and the snowfield should hand the extractor its cool surface tones while the rice field and momiji drive the accents. If the whole UI comes out gold-on-gold, crop a variant with more sky and feed it that instead. Also check whether the launcher and bar sit on her face at 1080p; the left side of the field is the quiet zone if any widget placement is configurable.

---

## Appendix A: rtw89 wifi, if and only if it misbehaves

Symptoms: random disconnects, latency spikes after idle, wifi dead after suspend. Do not touch this preemptively; recent kernels are often fine.

1. First lever, NetworkManager power save off. Create `/etc/NetworkManager/conf.d/wifi-powersave.conf`:
   ```
   [connection]
   wifi.powersave = 2
   ```
   (2 means disabled.) Then `sudo systemctl restart NetworkManager`.
2. Second lever, driver-level. Create `/etc/modprobe.d/rtw89.conf`:
   ```
   options rtw89_pci disable_aspm_l1=1 disable_clkreq=1
   ```
   Reboot. These disable the PCIe power states that historically caused most rtw89 grief. ⚠ Option set from the community playbook; `modinfo rtw89_pci` lists what your kernel version actually accepts.
3. Diagnose, don't guess: `dmesg | grep -i rtw89` and note firmware version and any timeout lines in the journal (`journalctl -k -b`).

## Appendix B: Microphone check

`sof-firmware` was installed in Phase 7 for the AMD ACP audio path. After the first reboot:
```
wpctl status
```
Look for an input device. Quick record test: `arecord -d 3 test.wav && aplay test.wav`. If no input exists: `dmesg | grep -iE 'sof|acp'` and confirm `sof-firmware` is installed before debugging PipeWire, because it will look exactly like a PipeWire problem and isn't.

## Appendix C: Suspend-then-hibernate (optional)

The 20 GiB swap partition from Phase 3 exists for this. Mendocino is s2idle-only, so plain suspend drains battery noticeably overnight; suspend-then-hibernate fixes that.

1. Kernel parameter: edit `/boot/loader/entries/arch.conf` and append to the options line:
   ```
   resume=UUID=<uuid-of-/dev/nvme0n1p2>
   ```
   (`blkid -s UUID -o value /dev/nvme0n1p2`)
2. Initramfs: in `/etc/mkinitcpio.conf`, add `resume` to HOOKS after `filesystems`, then:
   ```
   sudo mkinitcpio -P
   ```
3. Reboot, then test with files saved: `systemctl hibernate`. Power fully off, power on, session restored means success.
4. Make it the lid behavior. `/etc/systemd/sleep.conf.d/hibernate.conf`:
   ```
   [Sleep]
   HibernateDelaySec=60min
   ```
   `/etc/systemd/logind.conf.d/lid.conf`:
   ```
   [Login]
   HandleLidSwitch=suspend-then-hibernate
   ```
   Note: Caelestia/hypridle have their own idle and lock behavior; make sure only one layer owns "what happens on idle" or you get double-sleep weirdness. Lid closed = logind, idle timeout = hypridle is a sane division.

## Appendix D: Snapshots (recommended within week one)

```
sudo pacman -S snapper snap-pac
sudo snapper -c root create-config /
sudo snapper -c root create -d "baseline, fresh install"
```

`snap-pac` then snapshots automatically before and after every pacman transaction. `sudo snapper -c root list` to see them. Restoring on this simple layout means booting the ISO and using `btrfs subvolume` surgery or cherry-picking files out of `/.snapshots`, which is manual but fine for a learning box; the fully-automated rollback layouts are documented on the wiki's Snapper page if that becomes the special interest. Snapshots cover `@` only; `@home` is your data and gets backed up like data, snapshots are not backups.

## Appendix E: The uwsm variant (optional, later)

If you want the session run as proper systemd units (cleaner env propagation to portals, per-app units), enable Caelestia's `uwsm` component (rerun `caelestia install` and opt in; it installs uwsm and ships a config). Then replace the tty1 snippet's body with:

```fish
if status is-login; and test (tty) = /dev/tty1; and uwsm check may-start
    exec uwsm start hyprland.desktop
end
```

⚠ Verify against Caelestia's uwsm config expectations before switching; env-var propagation is exactly the layer where "portals stopped working" bugs live. Do this only after the plain-exec setup works, so you have a known-good state to diff against.

## Appendix F: Odds and ends for a normal networked laptop

- **Sensors:** `sudo sensors-detect` (accept defaults), then `sensors`. Feeds btop and Caelestia's monitors.
- **Firmware updates from Linux:** `sudo pacman -S fwupd && fwupdmgr get-devices`. HP consumer coverage on LVFS is spotty (⚠); you may only see the NVMe. That is why Phase 1 suggested one Windows boot.
- **Mirrors:** if pacman feels slow from Montreal: `sudo pacman -S reflector` then `sudo reflector --country Canada,US --latest 10 --sort rate --save /etc/pacman.d/mirrorlist`.
- **Update discipline:** Arch is rolling; packages assume the whole system moves together. Two rules prevent 90 percent of self-inflicted breakage: never install anything without a full `sudo pacman -Syu` (or `paru`) in the same sitting, and never run `pacman -Sy <package>` (that is a partial upgrade, the classic Arch foot-gun). A second machine tends to sit idle between hyperfocus arcs; if it has been weeks or months, update `archlinux-keyring` first, then the world. Pick a cadence (weekly is the usual answer for a secondary box) and put it in the journal.
- **Firewall:** Arch ships with none, and this laptop will presumably join networks you don't control. Two commands close that: `sudo pacman -S ufw`, then `sudo ufw enable && sudo systemctl enable ufw`. Default policy already denies incoming and allows outgoing, which is exactly right for a laptop running no services.

---

## Troubleshooting quick table

| Symptom | Likely cause | Fix |
|---|---|---|
| ISO won't boot at all | Secure Boot still on | Phase 1, step 3 |
| Machine boots to nothing/UEFI shell after install | Boot entry typo or wrong UUID | Boot ISO, remount, chroot, fix `arch.conf` (must be p3's UUID, `rootflags=subvol=@`) |
| Black screen right after systemd-boot | Missing `linux-firmware` or kms hook | Both installed in Phase 4/5; chroot and verify, run `mkinitcpio -P` |
| First boot: no wifi command works | NetworkManager not enabled | Chroot, `systemctl enable NetworkManager` |
| Wifi exists but is flaky | rtw89 power saving | Appendix A |
| Autologin loops on a crash | By design, getty restarts | `Ctrl+Alt+F2`, log in, fix, `Ctrl+Alt+F1` |
| Super+Q does nothing in default Hyprland | Config references kitty | Phase 7, step 3 sed |
| No microphone | sof-firmware missing or no reboot yet | Appendix B |
| Caelestia icons render as squares | Material Symbols font missing | `paru -S` the shell's font deps, `fc-cache -f`, restart shell |
| Firefox suddenly themed/weird | Caelestia firefox component | Phase 9, step 2; delete `userChrome.css`/`user.js` to revert |
| Colors don't match Maple | Scheme not set to dynamic | Phase 10, step 3 |

---

## Done state

Lid opens, three seconds of bootloader, no password prompt, Caelestia shell fades in, and a 30,000-year-old harvest deity is holding out her hand over a rice field on your lock screen. Write the journal entry. Then go break something, on purpose, with a snapshot taken first.
