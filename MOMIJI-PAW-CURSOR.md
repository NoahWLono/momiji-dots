# Momiji-Paw system-wide cursor

This overlay creates a real dual-format cursor theme:

- **Hyprcursor** for Hyprland and server-side Wayland cursors
- **XCursor** for GTK, Qt fallback behavior, Firefox, Electron/XWayland, and legacy apps

The normal pointer is a Maple-colored cat paw. Links add a green heart.
Text, wait, forbidden, and move states remain recognizable while staying
neko-themed.

## Apply the overlay

From Fish:

```fish
cd ~/Downloads
unzip momiji-paw-cursor-overlay.zip
cp -a momiji-paw-cursor-overlay/. ~/momiji-dots/
```

## Install build tools

```fish
sudo pacman -S --needed xorg-xcursorgen librsvg hyprcursor
```

`hyprcursor` is normally already present as a Hyprland dependency, but keeping
the command complete makes the build reproducible.

## Build and activate

```fish
cd ~/momiji-dots
chmod +x scripts/install-paw-cursor.sh scripts/uninstall-paw-cursor.sh
./scripts/install-paw-cursor.sh
```

The active theme is installed at:

```text
~/.local/share/icons/Momiji-Paw
```

The installer also:

- creates `~/.icons/Momiji-Paw`
- sets the GTK cursor through `gsettings`
- updates Caelestia's active `hypr-vars.lua`
- applies the Hyprcursor immediately with `hyprctl`
- creates a user-local `default` cursor inheritance file for stubborn XWayland apps
- backs up previous cursor and Caelestia files with timestamps

## Finish activation

Save any open work and reboot:

```fish
sudo reboot
```

Then log back in through the Maple SDDM screen. A full new session is needed
so XWayland and applications launched through the desktop inherit the cursor
environment.

## Verify

```fish
echo $XCURSOR_THEME
gsettings get org.gnome.desktop.interface cursor-theme
hyprctl setcursor Momiji-Paw 32
find ~/.local/share/icons/Momiji-Paw -maxdepth 2 -type f | sort
```

Expected theme name:

```text
Momiji-Paw
```

Test it in:

- the bare Hyprland desktop
- Foot
- Thunar
- Obsidian or Signal
- Firefox
- an XWayland application, if one is running

Some already-open applications cache their cursor. Close and reopen them after
the new login.

## Change size

Edit:

```fish
nvim ~/momiji-dots/home/caelestia/hypr-vars.lua
```

Change:

```lua
cursorSize = 32,
```

Then redeploy and restart the session.

## Remove

```fish
cd ~/momiji-dots
./scripts/uninstall-paw-cursor.sh
```

Restore the newest backup of:

```text
~/.config/caelestia/hypr-vars.lua.bak.TIMESTAMP
```

or edit the file and remove the `cursorTheme` and `cursorSize` lines. Then log
out and back in.

## Commit after testing

```fish
cd ~/momiji-dots
pacman -Qqen | sort > packages.txt
pacman -Qqem | sort > aur-packages.txt
git add -A
git commit -m "Add Momiji paw cursor theme"
git push
```
