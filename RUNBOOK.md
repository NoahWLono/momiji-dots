# RUNBOOK: HP 255 G10 → Arch + Hyprland + Caelestia + Rice (Complete)

The one document. Sealed box to Maple on the lock screen to Clock in the terminal, one pass, so afterwards there is only tinkering. This supersedes every earlier draft; commit it to the repo as `RUNBOOK.md` and stop keeping the others. The provisioning repo is `github.com/NoahWLono/momiji-dots`.

**Repo reality check, verified July 15, 2026:** the office/VPN package additions, `aur-packages.txt`, the `rice/` layer, and Clock's pony file are **not yet pushed**; the live `packages.txt` is still 73 lines. Phase 0 step 1 exists because of this, and its self-check proves when it's fixed. Do not skip it, or install day curls a payload missing a third of the plan.

**Baked-in decisions** (change them before Phase 3 or live with them):

| Decision | Value |
|---|---|
| Windows 11 Pro | Fully wiped. License stays in firmware (ACPI MSDM); a future Windows reinstall self-activates. Nothing to back up on a new unit. |
| Filesystem | btrfs, subvolumes `@` (root) and `@home`, `compress=zstd,noatime` |
| Partitions | 1 GiB ESP at `/boot`, 20 GiB swap, rest btrfs |
| Bootloader | systemd-boot |
| Login | getty autologin on tty1, fish execs Hyprland. Boots straight to desktop, no password, no greeter, no terminal to wake up to. |
| Privileges | Two identities: `noah` (daily life, sudo for admin) and `root` (break-glass only). The graphical session never runs as root: Hyprland refuses to start as root (⚠ from memory) and `makepkg` hard-refuses, which would kill Phases 8 and 9. Sudo *is* the root power, one word away. |
| Hostname / User | `momiji` / `noah` |
| Locale / TZ | `en_CA.UTF-8` / `America/Toronto` |
| AUR helper | `paru-bin` |
| Rice | Caelestia via `caelestia-cli`; deterministic extras (fun packages, Clock greeting, Maple) installed in Phases 10 and 12; open-ended ricing (paw cursor, plugins, animations) deliberately deferred to `rice/RICING.md` because hunts and taste are not checklist items. |
| Apps | LibreOffice, Obsidian, WireGuard tools in the day-1 payload; Spotify and VS Code through Caelestia components (themed); Proton VPN in Phase 11. |
| Clock | `rice/ponies/clockwork-relativity.pony` ships finished and validated against real ponysay. No conversion step exists on install day. |

**Honest uncertainty flags:** anything marked ⚠ is from memory or subject to upstream drift. Caelestia sections and the ponysay file were checked against live sources in July 2026; HP BIOS behavior, exact `caelestia` CLI flags, and a few package names were not independently verifiable. When this doc and reality disagree, reality and the Arch wiki win.

**One upstream disagreement with the plan:** Caelestia's README recommends greetd + tuigreet, which this setup deliberately omits. TTY login is explicitly supported by Caelestia, so the plan stands; if a future Caelestia update assumes a display manager, this is the seam to check.

---

## Phase 0: Before the mail truck

1. **Push everything that's still local.** From the Mac, idempotent (safe to run even if partially done):
   ```
   cd ~/momiji-dots
   grep -q '^libreoffice-fresh$' packages.txt || printf '%s\n' libreoffice-fresh hunspell hunspell-en_ca wireguard-tools obsidian >> packages.txt
   printf '%s\n' proton-vpn-gtk-app > aur-packages.txt
   unzip -o ~/Downloads/momiji-rice-merge.zip
   unzip -o ~/Downloads/momiji-clock-pack.zip
   ```
   Then open `rice/ponies/README.md` and fill the one artist-credit line from the Derpibooru page (image 3222695). Then:
   ```
   git add -A
   git commit -m "final payload: office suite, vpn, rice layer, Clock"
   git push
   ```
2. **Self-check.** All four must pass before install day:
   ```
   B=https://raw.githubusercontent.com/NoahWLono/momiji-dots/main
   curl -s $B/packages.txt | wc -l                                   # expect 78
   curl -s -o /dev/null -w '%{http_code}\n' $B/aur-packages.txt      # expect 200
   curl -s -o /dev/null -w '%{http_code}\n' $B/rice/fun-packages.txt # expect 200
   curl -s -o /dev/null -w '%{http_code}\n' $B/rice/ponies/clockwork-relativity.pony  # expect 200
   ```
3. **Flash the USB from the Mac.** Download the ISO from an Arch mirror, then:
   ```
   diskutil list                      # identify the USB stick, e.g. /dev/disk4. Be certain.
   diskutil unmountDisk /dev/disk4
   sudo dd if=archlinux-x86_64.iso of=/dev/rdisk4 bs=4m status=progress
   diskutil eject /dev/disk4
   ```
   macOS notes: BSD `dd` wants lowercase `4m`; the `rdisk` form is several times faster; the "disk not readable" dialog at the end is the Arch ISO being not-a-Mac-disk, click Ignore. balenaEtcher does the same job with guardrails if preferred.
4. **Network plan:** know the wifi password from memory or paper; ideally have an RJ45 cable within reach (the 255 G10 has an ethernet port, ⚠ per spec sheets, verify on the unit).
5. Optional: **one dry run in a VM** (UTM, UEFI firmware enabled). Phases 3 to 5 are identical to hardware minus wifi; mistakes cost a VM reset instead of morale.
6. Skim the Arch wiki Installation Guide once more; it is canonical when this doc differs.

---

## Phase 1: Unboxing and firmware (day 1)

1. **Optional but recommended: boot Windows exactly once** to update the BIOS via HP Support Assistant, then never again. HP ships firmware updates primarily through Windows tooling and LVFS/fwupd coverage for this model is uncertain (⚠). Use an offline local account during Windows setup (Shift+F10 at the network screen, `oobe\bypassnro` if it insists on a Microsoft account); the install dies in twenty minutes anyway.
2. **Enter BIOS setup:** power on, immediately tap `Esc` for the HP Startup Menu, then `F10` for setup. (`F9` is the one-time boot menu, needed in Phase 2.) ⚠ HP's key window is tight; start tapping at the power press.
3. In setup:
   - **Disable Secure Boot** (usually System Configuration → Boot Options); the Arch ISO is unsigned and will not boot with it on.
   - **Disable Fast Boot** in the same area.
   - Confirm boot mode is **UEFI**, no Legacy/CSM.
4. Save and exit. ⚠ HP consumer boards often interrupt the next boot with an "Operating System Boot Mode Change" screen demanding a displayed 4-digit code plus Enter. Normal, not malware. Type the code.

---

## Phase 2: Boot the live ISO

1. USB in, power on, `Esc`, then `F9`, pick the USB's UEFI entry. You land at a zsh prompt as root.
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
   - **Fallback:** USB-tether a phone; it appears as ethernet.
4. Verify: `ping -c 3 archlinux.org`
5. `timedatectl` should show NTP synchronized. Ant-sized console font: `setfont ter-132b`.

---

## Phase 3: Disk (this is where Windows dies)

Everything below destroys the entire disk. There is no undo after `w`.

1. Identify the disk:
   ```
   lsblk
   ```
   Expect `/dev/nvme0n1`, 256 to 512 GB. If your unit shows `mmcblk0` instead (⚠ some budget Mendocino boards ship eMMC), partitions are `mmcblk0p1` etc.; substitute throughout.
2. Partition:
   ```
   fdisk /dev/nvme0n1
   ```
   Keystrokes, in order:
   - `g` (new empty GPT)
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
4. Subvolumes and mounts (the `@`/`@home` split lets a future reinstall keep home intact, and it's what Phase 13's snapshots operate on):
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
   Escape hatch if btrfs is one new thing too many: `mkfs.ext4` on p3, mount at `/mnt`, skip the subvolume block, drop `rootflags=subvol=@` from the Phase 5 boot entry, skip snapshots in Phase 13. Everything else is identical.

---

## Phase 4: Install the base system

1. ```
   pacstrap -K /mnt base linux linux-firmware amd-ucode btrfs-progs networkmanager fish neovim sudo man-db man-pages
   ```
   Why each: `linux-firmware` is the amdgpu no-black-screen insurance; `amd-ucode` is CPU microcode (folded in automatically, Phase 5); `btrfs-progs` or the filesystem is unmanageable; `networkmanager` and an editor now so first boot isn't stranded; `fish` now so the user account can be created with it as login shell.
2. Generate and *verify* the fstab:
   ```
   genfstab -U /mnt >> /mnt/etc/fstab
   cat /mnt/etc/fstab
   ```
   You want: `/` with `subvol=/@`, `/home` with `subvol=/@home`, both `compress=zstd` and `noatime`, `/boot` as vfat, and the swap line.

---

## Phase 5: Configure from inside (chroot)

```
arch-chroot /mnt
```

**nvim survival box**, since this phase lives in it: `i` enters insert mode (type normally), `Esc` leaves it, `:wq` + Enter saves and quits, `:q!` + Enter quits without saving. That is 95 percent of what Phase 5 requires. Same editor family you met during the git commit on the Mac.

1. **Time:**
   ```
   ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
   hwclock --systohc
   ```
2. **Locale:** `nvim /etc/locale.gen`, uncomment `en_CA.UTF-8 UTF-8` and `en_US.UTF-8 UTF-8` (delete the leading `#`), then:
   ```
   locale-gen
   echo 'LANG=en_CA.UTF-8' > /etc/locale.conf
   ```
3. **Hostname and hosts** (network works inside the chroot):
   ```
   echo momiji > /etc/hostname
   curl -o /etc/hosts https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/etc/hosts
   cat /etc/hosts
   ```
4. **Services that must exist before first boot:**
   ```
   systemctl enable NetworkManager systemd-timesyncd
   ```
5. **Initramfs sanity check** (verify, don't change):
   ```
   grep ^HOOKS /etc/mkinitcpio.conf
   ```
   Current defaults include `microcode` (why the boot entry below has no separate ucode line) and `kms` (early amdgpu). If either is missing on an old ISO, add them and run `mkinitcpio -P`.
6. **Accounts.** The step that creates *you*; these four commands are the entire ceremony:
   ```
   passwd                                    # root password (break-glass identity)
   useradd -m -G wheel -s /usr/bin/fish noah
   passwd noah
   EDITOR=nvim visudo                        # uncomment: %wheel ALL=(ALL:ALL) ALL
   ```
   The username lives in two places that must agree: this `useradd` and the autologin drop-in deployed in Phase 7. As committed, they match; rename means changing both.
7. **Bootloader:**
   ```
   bootctl install
   curl -o /boot/loader/loader.conf https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/boot/loader.conf
   curl -o /boot/loader/entries/arch.conf https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/boot/arch.conf.template
   nvim /boot/loader/entries/arch.conf
   ```
   Replace `FILL-ME-IN-FROM-BLKID` with the real UUID by running, from inside nvim:
   ```
   :r !blkid -s UUID -o value /dev/nvme0n1p3
   ```
   then splice it into place. **Partition 3's** UUID, not the ESP's, not swap's. Final file:
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
   Yank the USB when the screen goes dark. A `momiji login:` prompt on tty1 is the entire base install, working.

---

## Phase 6: First boot sanity

1. Log in as `noah` at the tty. (A terminal, exactly once. Autologin gets wired in Phase 7; after that reboot you never see this prompt again unless you ask for it.)
2. Wifi via NetworkManager (one-time; the credential is stored):
   ```
   nmcli device wifi connect "YourSSID" password "yourpassword"
   ping -c 3 archlinux.org
   ```
3. Confirm sudo and sync:
   ```
   sudo pacman -Syu
   ```
4. `timedatectl` should show correct Montreal time, NTP active.
5. Start the log while the system is an hour old:
   ```
   mkdir -p ~/notes && nvim ~/notes/journal.md
   ```
   First entry: date, "installed per runbook", anything that deviated. Every non-obvious change gets a line here, forever. This file is the difference between debugging and archaeology.

---

## Phase 7: Day-1 payload (packages, repo, autologin, Hyprland)

1. **Install the package list from the repo** (78 packages after Phase 0):
   ```
   curl -LO https://raw.githubusercontent.com/NoahWLono/momiji-dots/main/packages.txt
   sudo pacman -S --needed - < packages.txt
   ```
   Deliberately absent: `hyprpolkitagent` and `uwsm` (Caelestia installs and launches `polkit-gnome` itself and ships uwsm as an optional component, Appendix D). Overlap with what Caelestia pulls later is free via `--needed`. If pacman rejects `hunspell-en_ca`, find the real name with `pacman -Ss hunspell-en` (⚠ flagged since Phase 0).
2. **Clone the repo.** Git just arrived; files now deploy from the local clone:
   ```
   git clone https://github.com/NoahWLono/momiji-dots.git ~/momiji-dots
   ```
3. **Enable services:**
   ```
   sudo systemctl enable --now bluetooth power-profiles-daemon
   sudo systemctl enable fstrim.timer
   ```
   PipeWire runs as user services, nothing to enable. `wpctl status` should show outputs and, thanks to `sof-firmware`, an internal mic (if absent, one reboot usually surfaces it; Appendix B).
4. **Test-launch Hyprland once, manually, before wiring autologin:**
   ```
   Hyprland
   ```
   Default config, yellow "not configured" bar: that is success. The generated config binds Super+Q to kitty, which is not installed; exit with `Super+M`, then:
   ```
   sed -i 's/kitty/foot/' ~/.config/hypr/hyprland.conf
   ```
   Caelestia replaces this config wholesale in Phase 9; the sed makes the interim usable.
5. **Deploy autologin and the tty1 exec from the clone** (`install -Dm644` creates parents and sets permissions in one shot):
   ```
   sudo install -Dm644 ~/momiji-dots/etc/getty-autologin.conf /etc/systemd/system/getty@tty1.service.d/autologin.conf
   install -Dm644 ~/momiji-dots/home/fish/10-tty1-hyprland.fish ~/.config/fish/conf.d/10-tty1-hyprland.fish
   sudo systemctl daemon-reload
   ```
   The getty drop-in autologs `noah` on tty1; the fish snippet execs Hyprland there, guarded by `WAYLAND_DISPLAY` so it never nests. Failure mode: a hard Hyprland crash loops through autologin. Escape hatch: `Ctrl+Alt+F2`, a clean tty2 login. Remember that chord.
6. **Reboot.** Firmware → systemd-boot (3s) → tty1 flashes past → Hyprland desktop. No password, no greeter. This is the desktop-mode behavior, achieved as a normal user. Until Caelestia's lock and hypridle are configured, the laptop is walk-up-and-own-it: acceptable for week one at home, not beyond.

---

## Phase 8: AUR bootstrap

```
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin && makepkg -si
cd .. && rm -rf paru-bin
```

`paru-bin` because compiling a Rust codebase on four Zen 2 cores is a scheduled break nobody asked for. From here on, `paru` handles AUR and repo packages alike. (Also the concrete reason the session runs as `noah`: `makepkg` refuses root, full stop.)

---

## Phase 9: Caelestia

Verified against the `caelestia-dots` GitHub org, July 2026; the old `install.fish` route is deprecated.

1. ```
   paru -S caelestia-cli
   caelestia install
   ```
   Real compile time: `caelestia-shell` requires `quickshell-git` plus a C++/QML build. Plug into AC; tens of minutes is normal, not a hang.
2. **What it does** (from its manifest): copies configs into `~/.config` for hypr, fish, foot, fastfetch, btop, micro, thunar, starship; GTK/Qt theming (adw-gtk-theme, Papirus, Darkly); auth (gnome-keyring, polkit-gnome); tools (trash-cli, ydotool, xdg-user-dirs). The **firefox component writes `userChrome.css` and `user.js` into your Firefox profile**; deleting those two files reverts it.
3. **Optional components: Spotify and VS Code come from here.** Opting into **spotify** installs it *with* spicetify and the Caelestia theme; a **vscode/vscodium** component adds the theming integration. Bare paru installs later work but skip the theming. ⚠ Which exact VS Code build each component installs wasn't verifiable; if marketplace completeness matters, confirm it's `visual-studio-code-bin` before accepting, or install that manually and skip the component. Decline the rest (zen, discord, todoist, uwsm...); rerunning adds components later.
4. **Point the browser keybind at Firefox** (default Super+W targets zen):
   ```
   install -Dm644 ~/momiji-dots/home/caelestia/hypr-vars.lua ~/.config/caelestia/hypr-vars.lua
   ```
   ⚠ Key name from Caelestia's README example; if it doesn't bite, check their docs.
5. **Enter the real session:** `hyprctl dispatch exit` from a terminal; autologin drops you into the Caelestia-configured session, shell autostarting via exec-once.
6. **Day-one keybinds:** `Super` launcher, `Super+T` terminal, `Super+#` workspaces, `Ctrl+Alt+Delete` session menu, `Ctrl+Super+Alt+R` restart shell after config edits.
7. Updates later: `caelestia update` handles system plus dots together.

---

## Phase 10: Maple

1. ```
   install -Dm644 ~/momiji-dots/wallpapers/maple.png ~/Pictures/Wallpapers/maple.png
   caelestia wallpaper -f ~/Pictures/Wallpapers/maple.png
   ```
   ⚠ Flag syntax per `caelestia wallpaper --help`. Bare `caelestia wallpaper` picks randomly from the directory, which with one image is also correct behavior, permanently.
2. Colors follow the wallpaper when the scheme is dynamic; the install seeds a static default, so if they don't: `caelestia scheme list`, set the dynamic one (`caelestia scheme set -n dynamic`, ⚠ name per docs).
3. Audit: sky and snowfield give the extractor cool surfaces, rice field and momiji drive accents. Gold-on-gold means crop a variant with more sky. Check whether the bar sits on her face at 1080p.

---

## Phase 11: The apps and how software works here

The reflex is `paru -S <thing>`, never website-installer-clickthrough. Two tiers behind the one command: official repos (curated, signed) and the AUR (community recipes). Habit worth keeping given the day job: paru shows the PKGBUILD before building; glancing at it is reading the script before piping it to bash.

1. **Already handled:** LibreOffice, Obsidian, `wireguard-tools` arrived in Phase 7; Spotify and VS Code, if wanted, came themed via Phase 9.
2. **LibreOffice extras:** spellcheck works via the hunspell dictionaries. Base wants Java; skip until the day you open Base, then `paru -S jre-openjdk`.
3. **Proton VPN, two routes:**
   - Official app: `paru -S --needed - < ~/momiji-dots/aur-packages.txt` (⚠ package name per `paru -Ss proton-vpn`). Earns its keep with the kill switch.
   - The boring route: generate a WireGuard config in Proton's dashboard, then `nmcli connection import type wireguard file ~/Downloads/proton-ca.conf`. Becomes a normal NetworkManager connection with no AUR Python chain to break. Running both, app plus imported fallback, is legitimate.
4. **Future wants:** repo packages append to `packages.txt`, AUR intentions to `aur-packages.txt`, committed from any machine. The repo stays the single answer to "what does this laptop have and why."

---

## Phase 12: The rice, deterministic part

Everything with a known answer happens now; everything requiring taste or a hunt is deliberately deferred.

1. **Fun packages** (ponysay, fortune, cbonsai, cmatrix, pipes, asciiquarium, sl, lolcat, hyfetch, tty-clock, figlet):
   ```
   paru -S --needed - < ~/momiji-dots/rice/fun-packages.txt
   ```
2. **The greeting** (coin flip between Clock and the canon cast on every new terminal):
   ```
   install -Dm644 ~/momiji-dots/home/fish/20-greeting.fish ~/.config/fish/conf.d/20-greeting.fish
   ```
3. **Prove Clock.** His `.pony` ships finished and pre-validated; there is no conversion step:
   ```
   fortune -s | ponysay -f ~/momiji-dots/rice/ponies/clockwork-relativity.pony
   ```
   A teal unicorn with an hourglass cutie mark delivering a fortune he cannot foresee for himself is the acceptance test. Open a new terminal afterwards; roughly half of them are him.
4. **Optional, Maple in fastfetch** (foot renders sixel):
   ```
   fastfetch --config ~/momiji-dots/rice/fastfetch/config-maple.jsonc
   ```
   Non-destructive; only copy it over `~/.config/fastfetch/config.jsonc` if you prefer it to Caelestia's.
5. **The handoff.** Everything open-ended lives in `rice/RICING.md` and is *not* install-day work, by design: the paw cursor hunt, cursor physics via hyprpm, animation curves, window rules, workspace autostart, the AuDHD keybind layer. Those need judgment, not a checklist, and doing them from a working baseline is the whole point of having one.

---

## Phase 13: Baseline and habits (the last mandatory phase)

1. **Snapshots, before the first experiment:**
   ```
   sudo pacman -S snapper snap-pac
   sudo snapper -c root create-config /
   sudo snapper -c root create -d "baseline, fresh install, riced"
   ```
   `snap-pac` now snapshots around every pacman transaction; `sudo snapper -c root list` to see them. Restoring on this layout is manual (`btrfs subvolume` surgery from the ISO, or cherry-picking from `/.snapshots`), fine for a learning box. Snapshots cover `@` only; `@home` is data and gets backed up like data.
2. **Firewall:**
   ```
   sudo pacman -S ufw
   sudo ufw enable && sudo systemctl enable ufw
   ```
   Default deny-incoming/allow-outgoing is exactly right for a laptop running no services.
3. **Sensors:** `sudo sensors-detect` (accept defaults), then `sensors`. Feeds btop and Caelestia's monitors.
4. **Journal entry:** date, "runbook complete", every deviation, and the answers to the two things this doc told you to check once (where Caelestia puts user Hyprland overrides; which VS Code build the component installed, if taken).
5. **The operating covenant, from here to forever:**
   - Never install anything without a full `sudo pacman -Syu` (or `paru`) in the same sitting; never `pacman -Sy <package>` (partial upgrade, the classic Arch foot-gun).
   - If the box slept in a drawer for weeks: `archlinux-keyring` first, then the world.
   - If Hyprland plugins ever get installed (RICING.md section 4): `hyprpm update` after every Hyprland upgrade, or they silently stop loading.
   - Pick a cadence (weekly is the usual answer for a secondary box) and write it in the journal.

---

## Appendix A: rtw89 wifi, if and only if it misbehaves

Symptoms: random disconnects, latency spikes after idle, wifi dead after suspend. Do not deploy preemptively; recent kernels are often fine.

1. NetworkManager power save off:
   ```
   sudo install -Dm644 ~/momiji-dots/etc/wifi-powersave.conf /etc/NetworkManager/conf.d/wifi-powersave.conf
   sudo systemctl restart NetworkManager
   ```
2. Driver-level:
   ```
   sudo install -Dm644 ~/momiji-dots/etc/rtw89.conf /etc/modprobe.d/rtw89.conf
   ```
   then reboot (sets `disable_aspm_l1=1 disable_clkreq=1`; ⚠ `modinfo rtw89_pci` lists what your kernel accepts).
3. Diagnose, don't guess: `dmesg | grep -i rtw89`, `journalctl -k -b`. Findings go in the journal.

## Appendix B: Microphone check

After the first reboot: `wpctl status` should list an input. Record test: `arecord -d 3 test.wav && aplay test.wav`. If no input: `dmesg | grep -iE 'sof|acp'` and confirm `sof-firmware` is installed before touching PipeWire config; the failure looks exactly like a PipeWire problem and isn't.

## Appendix C: Suspend-then-hibernate (optional)

The 20 GiB swap partition exists for this; Mendocino is s2idle-only, so plain suspend drains overnight.

1. Append to the options line of `/boot/loader/entries/arch.conf`:
   ```
   resume=UUID=<uuid-of-/dev/nvme0n1p2>
   ```
   (`blkid -s UUID -o value /dev/nvme0n1p2`; the **swap** partition's UUID, unlike the root UUID already there.)
2. In `/etc/mkinitcpio.conf`, add `resume` to HOOKS after `filesystems`, then `sudo mkinitcpio -P`.
3. Test with files saved: `systemctl hibernate`; full power-off, power on, session restored means success.
4. Lid behavior, from the clone:
   ```
   sudo install -Dm644 ~/momiji-dots/etc/sleep-hibernate.conf /etc/systemd/sleep.conf.d/hibernate.conf
   sudo install -Dm644 ~/momiji-dots/etc/logind-lid.conf /etc/systemd/logind.conf.d/lid.conf
   ```
   Make sure only one layer owns idle: lid = logind, idle timeout = hypridle.

## Appendix D: The uwsm variant (optional, later)

For the session as proper systemd units: enable Caelestia's `uwsm` component (rerun `caelestia install`, opt in), then replace the tty1 snippet body with:

```fish
if status is-login; and test (tty) = /dev/tty1; and uwsm check may-start
    exec uwsm start hyprland.desktop
end
```

⚠ Verify against Caelestia's uwsm config expectations first; env propagation is exactly where "portals stopped working" bugs live. Only after the plain-exec setup works, so there's a known-good state to diff against.

## Appendix E: Odds and ends

- **Firmware from Linux:** `sudo pacman -S fwupd && fwupdmgr get-devices`; HP consumer LVFS coverage is spotty (⚠), which is why Phase 1 suggested one Windows boot.
- **Mirrors, if pacman is slow from Montreal:** `sudo pacman -S reflector`, then `sudo reflector --country Canada,US --latest 10 --sort rate --save /etc/pacman.d/mirrorlist`.
- **Sudo friction:** the deliberate setup is autologin to desktop, password for sudo. A `NOPASSWD` sudoers rule exists, tradeoff stated plainly: combined with autologin, anyone at the lid and any code that compromises your user is instantly root, zero friction. Recommendation: keep the password; it is the last speed bump on a machine that otherwise has none.

---

## Troubleshooting quick table

| Symptom | Likely cause | Fix |
|---|---|---|
| Install-day curl gets 404 or a 73-line list | Phase 0 step 1 never pushed | Phase 0, run the self-check |
| ISO won't boot at all | Secure Boot still on | Phase 1, step 3 |
| Boots to nothing/UEFI shell after install | Boot entry typo or wrong UUID | Boot ISO, remount, chroot, fix `arch.conf` (partition 3's UUID, `rootflags=subvol=@`) |
| Black screen right after systemd-boot | Missing `linux-firmware` or kms hook | Handled in Phases 4/5; chroot, verify, `mkinitcpio -P` |
| First boot: no wifi command works | NetworkManager not enabled | Chroot, `systemctl enable NetworkManager` |
| Wifi exists but is flaky | rtw89 power saving | Appendix A |
| Autologin loops on a crash | By design, getty restarts | `Ctrl+Alt+F2`, log in, fix, `Ctrl+Alt+F1` |
| Super+Q does nothing in default Hyprland | Config references kitty | Phase 7, step 4 sed |
| An editor opened and you feel trapped | It's vim | Phase 5 survival box: `Esc`, `:q!`, breathe |
| No microphone | sof-firmware missing or no reboot yet | Appendix B |
| Caelestia icons render as squares | Material Symbols font missing | `paru -S` the shell's font deps, `fc-cache -f`, restart shell |
| Firefox suddenly themed/weird | Caelestia firefox component | Phase 9, step 2; delete `userChrome.css`/`user.js` |
| Spotify/VS Code doesn't match the theme | Bare install instead of component | Rerun `caelestia install`, opt in |
| `hunspell-en_ca` not found | Package name drift | `pacman -Ss hunspell-en`, install the real name |
| Colors don't match Maple | Scheme not dynamic | Phase 10, step 2 |
| No pony on new terminals | Greeting not deployed, or packages missing | Phase 12, steps 1 and 2 |
| Pony appears but never Clock | Coin flip, or the .pony path moved | `test -e ~/momiji-dots/rice/ponies/clockwork-relativity.pony`; force with `ponysay -f <path>` |

---

## Done state

Lid opens, three seconds of bootloader, no password, Caelestia fades in over a 30,000-year-old harvest deity holding out her hand above a rice field. A new terminal opens and either a canon pony or a teal unicorn with an hourglass cutie mark, who can read every future but his own, hands you a fortune. Writer and Calc are a keystroke away, the VPN toggles from the shell, snapshots guard the root, and every piece of it came from one repo with your name on it. Write the journal entry. Then tinker: RICING.md is the menu, and the baseline snapshot means nothing you try tonight is permanent unless you want it to be.
