# RUNBOOK: HP 255 G10 → Arch + Hyprland + Caelestia (Final, v2)

From sealed box to Maple on the lock screen, with the office suite and VPN accounted for. Manual install, no archinstall, no greeter. This supersedes every earlier draft, including the `RUNBOOK.md` currently in the repo; commit this over it. The provisioning repo is live at `github.com/NoahWLono/momiji-dots` and the URLs below were verified to resolve.

**Baked-in decisions** (change them before Phase 3 or live with them):

| Decision | Value |
|---|---|
| Windows 11 Pro | Fully wiped. License stays in firmware (ACPI MSDM); a future Windows reinstall self-activates. Nothing to back up on a new unit. |
| Filesystem | btrfs, subvolumes `@` (root) and `@home`, `compress=zstd,noatime` |
| Partitions | 1 GiB ESP at `/boot`, 20 GiB swap, rest btrfs |
| Bootloader | systemd-boot |
| Login | getty autologin on tty1, fish execs Hyprland. Boots straight to desktop, no password, no greeter. |
| Privileges | Single human, two identities: `noah` (daily life, sudo for admin) and `root` (break-glass only). The graphical session never runs as root: Hyprland refuses to start as root (⚠ from memory of its startup checks) and `makepkg` hard-refuses, which would kill Phases 8 and 9. Sudo *is* the root power, one word away. |
| Hostname / User | `momiji` / `noah` |
| Locale / TZ | `en_CA.UTF-8` / `America/Toronto` |
| AUR helper | `paru-bin` |
| Rice | Caelestia via `caelestia-cli` |
| Apps beyond the rice | LibreOffice, Obsidian, and WireGuard tools ride in the day-1 payload; Spotify and VS Code come through Caelestia components (Phase 9) so they get themed; Proton VPN lands in Phase 11. |
| Payload | `github.com/NoahWLono/momiji-dots` (packages, configs, wallpaper, this file) |

**Honest uncertainty flags:** anything marked ⚠ is from memory or subject to upstream drift. Caelestia sections were checked against the live GitHub repos in July 2026; HP BIOS behavior, exact `caelestia` CLI flags, and a few package names were not independently verifiable. When this doc and reality disagree, reality and the Arch wiki win.

**One upstream disagreement with the plan:** Caelestia's own README recommends greetd + tuigreet, which this setup deliberately omits. TTY login is explicitly supported by Caelestia, so the plan stands; just know the maintainer's default differs. If a future Caelestia update assumes a display manager, this is the seam to check.

---

## Phase 0: Before the mail truck

The repo is live and serving. Two updates to it, then physical prep.

1. **Add the new packages to the payload** (LibreOffice suite, spellcheck, WireGuard tools, Obsidian, all official repo packages). From the Mac:
   ```
   cd ~/momiji-dots
   printf '%s\n' libreoffice-fresh hunspell hunspell-en_ca wireguard-tools obsidian >> packages.txt
   printf '%s\n' proton-vpn-gtk-app > aur-packages.txt
   git add -A
   git commit -m "add office suite, spellcheck, wireguard, obsidian, aur intentions"
   git push
   ```
   Notes: `libreoffice-fresh` is the whole suite in one package (Writer, Calc, Impress, Draw, Base, Math); `-still` is the conservative branch if you'd rather have fewer surprises, pick one, not both. ⚠ `hunspell-en_ca` naming: confirm with `pacman -Ss hunspell-en` on install day and adjust if the split package is named differently. `aur-packages.txt` is a memo list, not fed to pacman; it holds things that only become installable after Phase 8 and have no Caelestia component (currently just the Proton VPN app, ⚠ AUR name per memory, `paru -Ss proton-vpn` confirms).
2. **Flash the USB from the Mac.** Download the ISO from an Arch mirror, then:
   ```
   diskutil list                      # identify the USB stick, e.g. /dev/disk4. Be certain.
   diskutil unmountDisk /dev/disk4
   sudo dd if=archlinux-x86_64.iso of=/dev/rdisk4 bs=4m status=progress
   diskutil eject /dev/disk4
   ```
   macOS notes: BSD `dd` wants lowercase `4m`, and the `rdisk` form is several times faster. macOS pops a "disk not readable" dialog when done; that is the Arch ISO being not-a-Mac-disk, click Ignore. If this feels sketchy, balenaEtcher does the same job with guardrails.
3. **Have a network plan.** Know the wifi password from memory or on paper, and ideally have an RJ45 cable within reach; the 255 G10 has an ethernet port (⚠ per spec sheets; verify on the unit), which takes the wifi driver out of the critical path.
4. Optional but valuable: **one dry run in a VM** (UTM on the Mac, UEFI firmware enabled so the bootloader steps match). Phases 3 through 5 in a VM are identical to hardware minus wifi; mistakes cost a VM reset instead of morale.
5. Skim the Arch wiki Installation Guide once more. This runbook is a condensation with decisions pre-made; the wiki is canonical when they differ.

---

## Phase 1: Unboxing and firmware (day 1)

1. **Optional but recommended: boot Windows exactly once** to update the BIOS via HP Support Assistant, then never again. HP ships firmware updates primarily through Windows tooling, LVFS/fwupd coverage for this model is uncertain (⚠), and post-wipe BIOS updates mean HP's bootable-USB method. Skipping breaks nothing; it just gets more annoying later. Use an offline local account during Windows setup (Shift+F10 at the network screen, `oobe\bypassnro` if it insists on a Microsoft account) since the install dies in twenty minutes anyway.
2. **Enter BIOS setup:** power on and immediately tap `Esc` for the HP Startup Menu, then `F10` for setup. (`F9` is the one-time boot menu, needed in Phase 2.) ⚠ HP's key window is tight; start tapping at the power press.
3. In setup:
   - **Disable Secure Boot** (usually System Configuration → Boot Options). The Arch ISO is unsigned and will not boot with it on.
   - **Disable Fast Boot** in the same area.
   - Confirm boot mode is **UEFI**, no Legacy/CSM.
4. Save and exit. ⚠ HP consumer boards often interrupt the next boot with an "Operating System Boot Mode Change" screen demanding a displayed 4-digit code plus Enter to confirm the Secure Boot change. Normal, not malware. Type the code.

---

## Phase 2: Boot the live ISO

1. USB in, power on, tap `Esc`, then `F9`, pick the USB's UEFI entry. You land at a zsh prompt as root.
2. **Confirm UEFI mode:**
   ```
   cat /sys/firmware/efi/fw_platform_size
   ```
   Must print `64`. If the file doesn't exist, you booted legacy; back to the BIOS.
3. **Network**, in order of reliability:
   - **Ethernet:** plug in, wait five seconds, done.
   - **Wifi** (rtw89 usually behaves on the live ISO):
     ```
     iwctl
     [iwd]# device list
     [iwd]# station wlan0 scan
     [iwd]# station wlan0 get-networks
     [iwd]# station wlan0 connect "YourSSID"
     [iwd]# exit
     ```
   - **Fallback:** USB-tether a phone; it appears as ethernet, zero drama.
4. Verify: `ping -c 3 archlinux.org`
5. `timedatectl` should already show NTP synchronized. If the console font is ant-sized: `setfont ter-132b`.

---

## Phase 3: Disk (this is where Windows dies)

Everything below destroys the entire disk. There is no undo after `w`.

1. Identify the disk:
   ```
   lsblk
   ```
   Expect `/dev/nvme0n1`, 256 to 512 GB. If your unit shows `mmcblk0` instead (⚠ some budget Mendocino boards ship eMMC), its partitions are `mmcblk0p1` etc.; substitute names throughout.
2. Partition:
   ```
   fdisk /dev/nvme0n1
   ```
   Keystrokes, in order:
   - `g` (new empty GPT, erases the old table)
   - `n`, partition `1`, default first sector, size `+1G`
   - `t`, partition `1`, type `1` (EFI System)
   - `n`, partition `2`, default, size `+20G`
   - `t`, partition `2`, type `19` (Linux swap)
   - `n`, partition `3`, defaults throughout (rest of disk)
   - `p` to review: ESP ~1G, swap 20G, one big Linux partition
   - `w` to write and exit
3. Format:
   ```
   mkfs.fat -F 32 -n ESP /dev/nvme0n1p1
   mkswap -L swap /dev/nvme0n1p2
   mkfs.btrfs -L arch /dev/nvme0n1p3
   ```
4. Subvolumes and mounts. The `@`/`@home` split lets future-you reinstall root while keeping home intact, and it's what snapshots operate on (Appendix D):
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
   Escape hatch if btrfs is one new thing too many: `mkfs.ext4` on p3, mount at `/mnt`, skip the subvolume block, drop `rootflags=subvol=@` from the boot entry in Phase 5, skip Appendix D. Everything else is identical.

---

## Phase 4: Install the base system

1. ```
   pacstrap -K /mnt base linux linux-firmware amd-ucode btrfs-progs networkmanager fish neovim sudo man-db man-pages
   ```
   Why each: `linux-firmware` is the amdgpu no-black-screen insurance. `amd-ucode` is CPU microcode (the initramfs folds it in automatically, Phase 5). `btrfs-progs` or the filesystem is unmanageable. `networkmanager` and an editor now so first boot isn't stranded. `fish` now so the user account can be created with it as login shell.
2. Generate and *verify* the fstab:
   ```
   genfstab -U /mnt >> /mnt/etc/fstab
   cat /mnt/etc/fstab
   ```
   You want: `/` with `subvol=/@`, `/home` with `subvol=/@home`, both with `compress=zstd` and `noatime`, `/boot` as vfat, and the swap line.

---

## Phase 5: Configure from inside (chroot)

```
arch-chroot /mnt
```

**nvim survival box**, since this phase lives in it: `i` enters insert mode (type normally), `Esc` leaves it, `:wq` + Enter saves and quits, `:q!` + Enter quits without saving. That is 95 percent of what Phase 5 requires. You met this editor during the git commit on the Mac; same rules.

1. **Time:**
   ```
   ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
   hwclock --systohc
   ```
2. **Locale:** `nvim /etc/locale.gen`, uncomment both `en_CA.UTF-8 UTF-8` and `en_US.UTF-8 UTF-8` (delete the leading `#`), then:
   ```
   locale-gen
   echo 'LANG=en_CA.UTF-8' > /etc/locale.conf
   ```
3. **Hostname and hosts.** The network is available inside the chroot; pull the hosts file from the repo:
   ```
   echo momiji > /etc/hostname
   curl -o /etc/hosts https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/etc/hosts
   cat /etc/hosts
   ```
   (Contents, if you'd rather type three lines: `127.0.0.1 localhost`, `::1 localhost`, `127.0.1.1 momiji`.)
4. **Services that must exist before first boot:**
   ```
   systemctl enable NetworkManager systemd-timesyncd
   ```
5. **Initramfs sanity check** (verify, don't change):
   ```
   grep ^HOOKS /etc/mkinitcpio.conf
   ```
   Current defaults include `microcode` (folds amd-ucode into the initramfs, which is why the boot entry below has no separate ucode line) and `kms` (early amdgpu). If either is missing on an old ISO, add them and run `mkinitcpio -P`.
6. **Accounts.** This is the step that creates *you*. There is no setup wizard in a manual install; these four commands are the entire account ceremony:
   ```
   passwd                                    # sets the root password (break-glass identity)
   useradd -m -G wheel -s /usr/bin/fish noah # your account: home dir, fish shell, admin group
   passwd noah
   EDITOR=nvim visudo                        # uncomment: %wheel ALL=(ALL:ALL) ALL
   ```
   The username matters in two places that must agree: this `useradd` and the autologin drop-in deployed in Phase 7 (`etc/getty-autologin.conf` in the repo, which names `noah`). As committed, they match; if you ever rename, change both or the boot stalls at a login prompt wondering who to be.
7. **Bootloader:**
   ```
   bootctl install
   curl -o /boot/loader/loader.conf https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/boot/loader.conf
   curl -o /boot/loader/entries/arch.conf https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/boot/arch.conf.template
   nvim /boot/loader/entries/arch.conf
   ```
   The template's options line reads `root=UUID=FILL-ME-IN-FROM-BLKID rootflags=subvol=@ rw`. Fill the real UUID without typos by running, from inside nvim:
   ```
   :r !blkid -s UUID -o value /dev/nvme0n1p3
   ```
   which inserts the UUID on a new line; splice it into place and delete the placeholder. This must be **partition 3's** UUID, not the ESP's, not swap's. Final file:
   ```
   title   Arch Linux
   linux   /vmlinuz-linux
   initrd  /initramfs-linux.img
   options root=UUID=<real-uuid> rootflags=subvol=@ rw
   ```
8. **Leave and reboot:**
   ```
   exit
   umount -R /mnt
   reboot
   ```
   Yank the USB when the screen goes dark. You should land at a `momiji login:` prompt on tty1. That prompt is the entire base install, working.

---

## Phase 6: First boot sanity

1. Log in as `noah` at the tty. (Yes, a terminal, exactly once. Autologin to the desktop gets wired in Phase 7; after that reboot, you never see this prompt again unless you ask for it.)
2. Wifi, now via NetworkManager (one-time; the credential is stored):
   ```
   nmcli device wifi connect "YourSSID" password "yourpassword"
   ping -c 3 archlinux.org
   ```
   (`nmtui` if you prefer a menu.)
3. Confirm sudo works and sync:
   ```
   sudo pacman -Syu
   ```
4. `timedatectl` should show correct Montreal time with NTP active.
5. Start the log habit while the system is one hour old:
   ```
   mkdir -p ~/notes && nvim ~/notes/journal.md
   ```
   First entry: date, "installed per runbook", anything that deviated. Every non-obvious change to this machine gets a line here, forever. This file is the difference between debugging and archaeology.

---

## Phase 7: Day-1 payload (packages, repo, autologin, Hyprland)

1. **Install the package list straight from the repo:**
   ```
   curl -LO https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/packages.txt
   sudo pacman -S --needed - < packages.txt
   ```
   With the Phase 0 additions this is roughly 78 packages: graphics/Wayland core, the Hypr tools, the full PipeWire stack plus `sof-firmware` for the mic, network and Bluetooth, power and disk plumbing, fonts, foot/Firefox/Thunar, screenshot and clipboard tools, the terminal quality-of-life set, build tooling for the AUR, and now LibreOffice, spellcheck dictionaries, WireGuard tools, and Obsidian. Deliberately absent: `hyprpolkitagent` and `uwsm` (Caelestia's manifest installs and launches `polkit-gnome` itself and ships uwsm as an optional component, Appendix E). Much of the list overlaps with what `caelestia install` pulls later; `--needed` makes the overlap free. If pacman rejects `hunspell-en_ca`, find the real name with `pacman -Ss hunspell-en` and install it by hand (⚠ flagged in Phase 0).
2. **Clone the repo.** Git just arrived; from here on, files deploy from the local clone:
   ```
   git clone https://github.com/NoahWLono/momiji-dots.git ~/momiji-dots
   ```
3. **Enable services:**
   ```
   sudo systemctl enable --now bluetooth power-profiles-daemon
   sudo systemctl enable fstrim.timer
   ```
   PipeWire runs as user services via socket activation, nothing to enable. Verify with `wpctl status`: outputs present and, thanks to `sof-firmware`, an internal mic (if absent, one reboot usually surfaces it; Appendix B).
4. **Test-launch Hyprland once, manually, before wiring autologin.** From the tty:
   ```
   Hyprland
   ```
   You get the default config with a yellow "you have not configured Hyprland" bar. That is success. One catch: the auto-generated config binds Super+Q to kitty, which is not installed. Exit with `Super+M`, then:
   ```
   sed -i 's/kitty/foot/' ~/.config/hypr/hyprland.conf
   ```
   Caelestia replaces this config wholesale in Phase 9; the sed just makes the interim usable.
5. **Deploy autologin and the tty1 exec, from the clone.** `install -Dm644` creates parent directories and sets permissions in one shot:
   ```
   sudo install -Dm644 ~/momiji-dots/etc/getty-autologin.conf /etc/systemd/system/getty@tty1.service.d/autologin.conf
   install -Dm644 ~/momiji-dots/home/fish/10-tty1-hyprland.fish ~/.config/fish/conf.d/10-tty1-hyprland.fish
   sudo systemctl daemon-reload
   ```
   What those two files do: the getty drop-in autologs `noah` on tty1; the fish snippet (in conf.d so Caelestia's fish config can't clobber it) execs Hyprland on that login, guarded by `WAYLAND_DISPLAY` so it never nests. The failure mode of the design: if Hyprland hard-crashes, getty restarts, autologin fires, and it loops. The escape hatch is `Ctrl+Alt+F2`, a clean tty2 login where the exec condition is false. Remember that chord.
6. **Reboot.** Firmware → systemd-boot (3s) → tty1 flashes past → Hyprland desktop. No password, no greeter, no terminal to wake up to: this is the "desktop mode" behavior, achieved as a normal user, no root session required or possible. Until Caelestia's lock screen and hypridle are configured, the laptop is a walk-up-and-own-it device, acceptable for week one in your own home and not beyond that.

---

## Phase 8: AUR bootstrap

```
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin && makepkg -si
cd .. && rm -rf paru-bin
```

`paru-bin` and not `paru` because compiling a Rust codebase on four Zen 2 cores is a scheduled break nobody asked for. From here on, `paru` handles AUR and repo packages alike. (This step is also the concrete reason the session runs as `noah`: `makepkg` refuses to run as root, full stop.)

---

## Phase 9: Caelestia

Verified against the `caelestia-dots` GitHub org, July 2026. The old `install.fish` route is deprecated; the CLI does everything.

1. ```
   paru -S caelestia-cli
   caelestia install
   ```
   Expect real compile time: this pulls `caelestia-shell`, which requires `quickshell-git` (the git version specifically, per their README) plus a C++/QML build. Plug into AC and let the 7320U cook; tens of minutes is normal, not a hang.
2. **What `caelestia install` does** (from its manifest, so nothing surprises you):
   - Default components copy configs into `~/.config` for hypr, fish, foot, fastfetch, btop, micro, thunar, starship, plus GTK/Qt theming (adw-gtk-theme, Papirus, Darkly) and auth (gnome-keyring, polkit-gnome).
   - The **firefox component writes `userChrome.css` and `user.js` into your Firefox profile** for theming. If Firefox looks different afterwards, that is why; deleting those two files reverts it.
   - The tools component adds `trash-cli`, `ydotool`, `xdg-user-dirs`, and friends.
3. **Optional components: this is where Spotify and VS Code should come from.** The installer offers spotify, vscodium, vscode, zed, discord (equibop), todoist, uwsm, and zen-browser. Opting into **spotify** here installs it *with* spicetify and the Caelestia theme, so it matches Maple's scheme; opting into a **vscode/vscodium** component adds the caelestia-vscode-integration theming. Installing either app bare via paru later works but skips the theming, so take them here if you want them. ⚠ Which exact package each vscode component installs (OSS build vs Microsoft `-bin` vs VSCodium) wasn't verifiable; read the prompt, and if marketplace completeness matters to you, confirm it's giving you `visual-studio-code-bin` before accepting, or install that one manually afterwards and skip the component. Decline everything else you don't want; rerunning `caelestia install` adds components later.
4. **Point the browser keybind at Firefox** (default Super+W targets zen). From the clone:
   ```
   install -Dm644 ~/momiji-dots/home/caelestia/hypr-vars.lua ~/.config/caelestia/hypr-vars.lua
   ```
   Three lines of Lua returning `browser = "firefox"`. ⚠ Key name from Caelestia's README example; if it doesn't bite, check their current docs.
5. **Get into the real session:** log out of the interim default session (`hyprctl dispatch exit` from a terminal) and let autologin drop you into the Caelestia-configured one, where the shell autostarts via exec-once.
6. **Keybinds for day one:** `Super` launcher, `Super+T` terminal (foot), `Super+#` workspaces, `Ctrl+Alt+Delete` session menu, `Ctrl+Super+Alt+R` restart the shell after config edits.
7. Updates later: `caelestia update` handles system plus dots together.

---

## Phase 10: Maple

1. From the clone:
   ```
   install -Dm644 ~/momiji-dots/wallpapers/maple.png ~/Pictures/Wallpapers/maple.png
   caelestia wallpaper -f ~/Pictures/Wallpapers/maple.png
   ```
   ⚠ Flag syntax from memory; `caelestia wallpaper --help` is authoritative. Bare `caelestia wallpaper` picks randomly from the wallpapers directory, which with exactly one image is also correct behavior, permanently.
2. The shell generates its Material color scheme from the wallpaper when the scheme is dynamic. The install seeds a static default, so if colors don't follow the image: `caelestia scheme list`, then set the dynamic one (`caelestia scheme set -n dynamic`, ⚠ name per current docs).
3. Audit the result: the sky and snowfield hand the extractor its cool surface tones while the rice field and momiji drive the accents. If the UI comes out gold-on-gold, crop a variant with more sky and feed it that. Check whether the launcher or bar sits on her face at 1080p; the left of the field is the quiet zone.
4. The image is 1672x941, exactly 16:9; it upscales about 1.15x to the panel, visually fine. If a larger original ever exists, add it to the repo alongside, not over, this one.

---

## Phase 11: The rest of the apps, and how getting software works here

The reflex on this system is `paru -S <thing>`, never "go to the website and download an installer." Two tiers behind that one command: the official repos (curated, signed) and the AUR (community build recipes for nearly everything else). One habit worth keeping, given your day job: AUR recipes are user-submitted, and paru shows you the PKGBUILD before building. Glancing at it is the local equivalent of reading a script before piping it to bash. Don't reflexively skip it.

1. **Already handled by earlier phases, no action:** LibreOffice, Obsidian, and `wireguard-tools` arrived with the Phase 7 payload; Spotify and VS Code, if you wanted them, came themed through Phase 9's components.
2. **LibreOffice extras:** spellcheck works via the hunspell dictionaries from the payload. Base (the database module) wants a Java runtime; skip until the day you actually open Base, then `paru -S jre-openjdk`.
3. **Proton VPN, two routes, both legitimate:**
   - **The official app**, from your memo list:
     ```
     paru -S --needed - < ~/momiji-dots/aur-packages.txt
     ```
     (⚠ package name `proton-vpn-gtk-app` per memory; `paru -Ss proton-vpn` confirms.) Earns its keep with the kill switch and easy server switching.
   - **The boring route:** generate a WireGuard config in Proton's web dashboard, then:
     ```
     nmcli connection import type wireguard file ~/Downloads/proton-ca.conf
     ```
     The VPN becomes a normal NetworkManager connection, toggleable from Caelestia's network UI, with no AUR Python dependency chain to break on update. Nothing stops you from running the app and keeping a WireGuard profile imported as the fallback for the day the AUR package breaks.
4. **Future wants:** repo packages get appended to `packages.txt`, AUR intentions to `aur-packages.txt`, committed from whatever machine you're on. The repo stays the single answer to "what does this laptop have and why."

---

## Appendix A: rtw89 wifi, if and only if it misbehaves

Symptoms: random disconnects, latency spikes after idle, wifi dead after suspend. Do not deploy these preemptively; recent kernels are often fine.

1. First lever, NetworkManager power save off:
   ```
   sudo install -Dm644 ~/momiji-dots/etc/wifi-powersave.conf /etc/NetworkManager/conf.d/wifi-powersave.conf
   sudo systemctl restart NetworkManager
   ```
   (The file sets `wifi.powersave = 2`, meaning disabled.)
2. Second lever, driver-level:
   ```
   sudo install -Dm644 ~/momiji-dots/etc/rtw89.conf /etc/modprobe.d/rtw89.conf
   ```
   then reboot. It sets `disable_aspm_l1=1 disable_clkreq=1`, disabling the PCIe power states behind most historical rtw89 grief. ⚠ Option set from the community playbook; `modinfo rtw89_pci` lists what your kernel actually accepts.
3. Diagnose, don't guess: `dmesg | grep -i rtw89` and `journalctl -k -b` for firmware version and timeout lines. Write findings in the journal.

## Appendix B: Microphone check

`sof-firmware` (Phase 7) covers the AMD ACP audio path. After the first reboot:
```
wpctl status
```
Look for an input device. Record test: `arecord -d 3 test.wav && aplay test.wav`. If no input exists: `dmesg | grep -iE 'sof|acp'` and confirm sof-firmware is installed before touching PipeWire config, because the failure looks exactly like a PipeWire problem and isn't.

## Appendix C: Suspend-then-hibernate (optional)

The 20 GiB swap partition exists for this. Mendocino is s2idle-only, so plain suspend drains battery noticeably overnight; suspend-then-hibernate fixes that.

1. Kernel parameter: edit `/boot/loader/entries/arch.conf` and append to the options line:
   ```
   resume=UUID=<uuid-of-/dev/nvme0n1p2>
   ```
   (`blkid -s UUID -o value /dev/nvme0n1p2`; note this is the **swap** partition's UUID, unlike the root UUID already on that line.)
2. Initramfs: in `/etc/mkinitcpio.conf`, add `resume` to HOOKS after `filesystems`, then:
   ```
   sudo mkinitcpio -P
   ```
3. Reboot, then test with files saved: `systemctl hibernate`. Full power-off, power on, session restored means success.
4. Make it the lid behavior, from the clone:
   ```
   sudo install -Dm644 ~/momiji-dots/etc/sleep-hibernate.conf /etc/systemd/sleep.conf.d/hibernate.conf
   sudo install -Dm644 ~/momiji-dots/etc/logind-lid.conf /etc/systemd/logind.conf.d/lid.conf
   ```
   (Suspend, then hibernate after 60 minutes; lid close triggers the sequence.) Caelestia/hypridle have their own idle behavior; make sure only one layer owns "what happens on idle". Lid = logind, idle timeout = hypridle is a sane division.

## Appendix D: Snapshots (recommended within week one)

```
sudo pacman -S snapper snap-pac
sudo snapper -c root create-config /
sudo snapper -c root create -d "baseline, fresh install"
```

`snap-pac` then snapshots automatically before and after every pacman transaction; `sudo snapper -c root list` to see them. Restoring on this simple layout means booting the ISO for `btrfs subvolume` surgery or cherry-picking files out of `/.snapshots`, manual but fine for a learning box; the fully automated rollback layouts live on the wiki's Snapper page if that becomes the special interest. Snapshots cover `@` only. `@home` is data and gets backed up like data; snapshots are not backups.

## Appendix E: The uwsm variant (optional, later)

For the session run as proper systemd units (cleaner env propagation to portals, per-app units): enable Caelestia's `uwsm` component (rerun `caelestia install` and opt in; it installs uwsm and ships a config), then replace the tty1 snippet's body with:

```fish
if status is-login; and test (tty) = /dev/tty1; and uwsm check may-start
    exec uwsm start hyprland.desktop
end
```

⚠ Verify against Caelestia's uwsm config expectations first; env-var propagation is exactly the layer where "portals stopped working" bugs live. Do this only after the plain-exec setup works, so there is a known-good state to diff against.

## Appendix F: Odds and ends for a normal networked laptop

- **Sensors:** `sudo sensors-detect` (accept defaults), then `sensors`. Feeds btop and Caelestia's monitors.
- **Firewall:** Arch ships with none, and this laptop will join networks you don't control. `sudo pacman -S ufw`, then `sudo ufw enable && sudo systemctl enable ufw`. Default policy already denies incoming and allows outgoing, exactly right for a laptop running no services.
- **Sudo friction:** the deliberate setup is autologin to desktop, password for sudo. A `NOPASSWD` sudoers rule exists if the password ever grates, with its tradeoff stated plainly: combined with autologin, anyone at the lid, and any code that compromises your user, is instantly root with zero friction. Recommendation stands: keep the password; it is the last speed bump on a machine that otherwise has none.
- **Firmware updates from Linux:** `sudo pacman -S fwupd && fwupdmgr get-devices`. HP consumer coverage on LVFS is spotty (⚠); you may only see the NVMe. That is why Phase 1 suggested one Windows boot.
- **Mirrors:** if pacman feels slow from Montreal: `sudo pacman -S reflector`, then `sudo reflector --country Canada,US --latest 10 --sort rate --save /etc/pacman.d/mirrorlist`.
- **Update discipline:** Arch is rolling; packages assume the whole system moves together. Two rules prevent 90 percent of self-inflicted breakage: never install anything without a full `sudo pacman -Syu` (or `paru`) in the same sitting, and never run `pacman -Sy <package>` (that is a partial upgrade, the classic Arch foot-gun). A second machine tends to sit idle between hyperfocus arcs; if it has been weeks or months, update `archlinux-keyring` first, then the world. Pick a cadence (weekly is the usual answer for a secondary box) and put it in the journal.

---

## Troubleshooting quick table

| Symptom | Likely cause | Fix |
|---|---|---|
| ISO won't boot at all | Secure Boot still on | Phase 1, step 3 |
| Boots to nothing/UEFI shell after install | Boot entry typo or wrong UUID | Boot ISO, remount, chroot, fix `arch.conf` (partition 3's UUID, `rootflags=subvol=@`) |
| Black screen right after systemd-boot | Missing `linux-firmware` or kms hook | Both handled in Phases 4/5; chroot, verify, `mkinitcpio -P` |
| First boot: no wifi command works | NetworkManager not enabled | Chroot, `systemctl enable NetworkManager` |
| Wifi exists but is flaky | rtw89 power saving | Appendix A |
| Autologin loops on a crash | By design, getty restarts | `Ctrl+Alt+F2`, log in, fix, `Ctrl+Alt+F1` |
| Super+Q does nothing in default Hyprland | Config references kitty | Phase 7, step 4 sed |
| An editor opened and you feel trapped | It's vim | Phase 5 survival box: `Esc`, `:q!`, breathe |
| No microphone | sof-firmware missing or no reboot yet | Appendix B |
| Caelestia icons render as squares | Material Symbols font missing | `paru -S` the shell's font deps, `fc-cache -f`, restart shell |
| Firefox suddenly themed/weird | Caelestia firefox component | Phase 9, step 2; delete `userChrome.css`/`user.js` to revert |
| Spotify or VS Code doesn't match the theme | Installed bare via paru instead of a component | Rerun `caelestia install`, opt into the component |
| `hunspell-en_ca` not found | Package name drift | `pacman -Ss hunspell-en`, install the real name |
| Colors don't match Maple | Scheme not set to dynamic | Phase 10, step 2 |

---

## Done state

Lid opens, three seconds of bootloader, no password prompt, Caelestia fades in, and a 30,000-year-old harvest deity is holding out her hand over a rice field on your lock screen. Writer and Calc are a launcher keystroke away, the VPN toggles from the shell, and the whole thing came from a repo with your name on it. Write the journal entry. Take the baseline snapshot. Then go break something, on purpose, knowing exactly how you'd put it back.
