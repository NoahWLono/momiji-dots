# Momiji Maple SDDM

This version keeps the two-password boot model:

1. LUKS passphrase unlocks the encrypted drive.
2. SDDM displays Maple and asks for the Linux user password.
3. A successful login launches Hyprland and Caelestia.

It does not enable autologin and does not change LUKS.

## Visual source

The installer uses two existing Momiji assets:

- `wallpapers/maple.png` becomes the full-screen background.
- `~/.face`, the profile picture used by Caelestia, becomes the large Maple avatar.

If `~/.face` does not exist, the installer checks `~/.face.icon`, then falls
back to the wallpaper. Set the Caelestia profile image first for the intended
Maple face:

```fish
cp /path/to/maple-face.png ~/.face
```

Lock with `Super+L` and confirm that Caelestia shows the correct image.

## Install

From Momiji:

```fish
cd ~/momiji-dots
chmod +x scripts/install-sddm-theme.sh scripts/uninstall-sddm-theme.sh
./scripts/install-sddm-theme.sh
```

The script copies the theme to:

```text
/usr/share/sddm/themes/momiji-maple
```

It activates the theme with:

```text
/etc/sddm.conf.d/20-momiji-theme.conf
```

The original `10-momiji.conf` remains responsible for keeping autologin
disabled.

## Preview safely

Do this inside the running Hyprland session:

```fish
sddm-greeter --test-mode --theme /usr/share/sddm/themes/momiji-maple
```

The preview cannot actually log in, reboot, or power off. Check:

- Maple's avatar is visible and not stretched badly.
- The password box is readable.
- Enter triggers the test login action without a QML crash.
- The clock and date are positioned correctly.
- The panel does not cover the important part of the wallpaper.
- The window scales correctly on Momiji's screen.

Close the preview normally. Do not restart SDDM from inside the active graphical
session because that terminates the session.

## First real boot test

After the preview succeeds:

```fish
sudo reboot
```

Expected sequence:

1. systemd-boot
2. LUKS passphrase prompt
3. Momiji Maple SDDM
4. Linux password
5. Hyprland and Caelestia

The LUKS and Linux passwords remain separate.

## Customization

Edit:

```fish
nvim ~/momiji-dots/rice/sddm/momiji-maple/theme.conf
```

Useful values:

```ini
[General]
Subtitle=Welcome home, Noah :3
Prompt=Enter your Momiji password
ButtonText=Unlock Momiji
PanelSide=left
Accent=#D4A017
AccentAlt=#9A3F24
Leaf=#4F7A3A
```

Use `PanelSide=right` when Maple's face or another important subject occupies
the left side of the wallpaper. Rerun the installer after any theme or image
change:

```fish
cd ~/momiji-dots
./scripts/install-sddm-theme.sh
```

## Updating the Maple face

After replacing `~/.face`, rerun:

```fish
cd ~/momiji-dots
./scripts/install-sddm-theme.sh
```

SDDM cannot read Caelestia's live user-session state before login, so the
installer copies a snapshot of the avatar into the system theme directory.

## Recovery from a broken greeter

At a blank or broken SDDM screen, open another tty:

```text
Ctrl+Alt+F2
```

Log in as `noah`, then remove only the theme override:

```fish
sudo rm -f /etc/sddm.conf.d/20-momiji-theme.conf
sudo reboot
```

That restores SDDM's normal theme selection while preserving the existing
password-required login configuration.

To remove the installed theme files too:

```fish
cd ~/momiji-dots
./scripts/uninstall-sddm-theme.sh
sudo reboot
```

The installer also keeps timestamped backups under:

```text
/var/backups/momiji-sddm/
```

## Git commit

After testing successfully:

```fish
cd ~/momiji-dots
git add -A
git diff --cached --stat
git commit -m "Add Maple Nekokami SDDM theme"
git push
git status
```
