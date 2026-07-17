# momiji-dots

Reproducible provisioning for one user on an HP 255 G10 running Arch Linux,
Hyprland, and Caelestia.

The clean-install design now uses:

- LUKS2 encryption for root and home data
- one unencrypted 1 GiB EFI System Partition required for boot
- btrfs subvolumes `@` and `@home` inside the encrypted container
- zram for swap, with no disk-backed swap and no hibernation
- weekly fstrim with discards passed through the LUKS mapping
- SDDM for a normal graphical username and password screen
- no tty autologin

The resulting boot flow is:

1. systemd-boot
2. LUKS passphrase prompt
3. SDDM graphical login
4. Hyprland and Caelestia

Start with [CHECKLIST.md](CHECKLIST.md) for the tickable overview and
[RUNBOOK.md](RUNBOOK.md) for every command and its verification.

## Preflight

```sh
./scripts/validate-repo.sh
```

On an up-to-date Arch environment, also resolve current package names:

```sh
./scripts/validate-repo.sh --arch --aur
```

GitHub Actions repeats the structural checks and verifies `packages.txt`
against current Arch repositories on every push.

## Repeatable scripts

| Script | Purpose |
|---|---|
| `scripts/install-packages.sh` | Full system update, official package set, paru bootstrap, applications, zram config, services |
| `scripts/deploy-configs.sh` | Current Caelestia Lua overrides, sounds, greeting, wallpaper |
| `scripts/enable-display-manager.sh` | Enables SDDM only after a working Caelestia session has been tested |
| `scripts/install-fun.sh` | Installs optional terminal toys independently |
| `scripts/validate-repo.sh` | Lints files, assets, encryption placeholders, login configuration, and package names |

## Source files and destinations

| Source | Destination |
|---|---|
| `boot/loader.conf` | `/boot/loader/loader.conf` |
| `boot/arch.conf.template` | `/boot/loader/entries/arch.conf`, after LUKS UUID substitution |
| `etc/mkinitcpio.conf.d/momiji-encryption.conf` | `/etc/mkinitcpio.conf.d/momiji-encryption.conf` |
| `etc/sddm.conf.d/10-momiji.conf` | `/etc/sddm.conf.d/10-momiji.conf` |
| `etc/zram-generator.conf` | `/etc/systemd/zram-generator.conf` |
| `etc/hosts` | `/etc/hosts` |
| `home/fish/20-greeting.fish` | `~/.config/fish/conf.d/20-greeting.fish` |
| `home/caelestia/hypr-vars.lua` | `~/.config/caelestia/hypr-vars.lua` |
| `home/caelestia/hypr-user.lua` | `~/.config/caelestia/hypr-user.lua` |
| `rice/sounds/*.wav` | `~/.local/share/momiji/sounds/` |
| `wallpapers/maple.png` | `~/Pictures/Wallpapers/maple.png` |

The rtw89 Wi-Fi overrides remain symptom-driven and apply only to Realtek
8852-family cards using the `rtw89` driver. This laptop line also ships with
RTL8822CE (`rtw88`) and MediaTek MT7921 (`mt7921e`) cards depending on the
batch; identify the hardware before deploying anything.

Never commit Wi-Fi credentials, VPN private keys, a LUKS passphrase, a LUKS
header backup, browser profiles, or locally licensed media.
