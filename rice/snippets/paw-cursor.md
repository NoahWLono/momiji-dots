# Paw cursor override

Caelestia now manages Hyprland through Lua. Do not use the old `env = ...`
Hyprland snippet.

1. Install an XCursor or Hyprcursor theme under
   `~/.local/share/icons/<ThemeName>/`.
2. Edit `~/.config/caelestia/hypr-vars.lua` and add:

```lua
return {
    browser = "firefox",
    cursorTheme = "ThemeName",
    cursorSize = 24,
}
```

3. Restart the session. Caelestia applies the Hyprland environment,
   `hyprctl setcursor`, and GTK cursor settings from these variables.
