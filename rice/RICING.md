# Momiji rice layer

Complete the clean install and baseline snapshot before using this file. Keep
custom work in Caelestia's supported override surfaces so updates do not erase
it:

- `~/.config/caelestia/hypr-vars.lua` for variable overrides
- `~/.config/caelestia/hypr-user.lua` for user Hyprland Lua
- `~/.config/caelestia/user-config.fish` or separate Fish `conf.d` files

## Optional terminal extras

Install optional packages independently so one renamed AUR package does not
block the rest:

```sh
~/momiji-dots/scripts/install-fun.sh
```

The greeting works without the custom Clock pony. See `rice/ponies/README.md`.

## Paw cursor

Follow `rice/snippets/paw-cursor.md`. The old Hyprland `.conf` syntax is not the
right override format for current Caelestia.

## Lid sounds

The login chime is installed by default. Lid event state and device names are
hardware-dependent, so test them before merging
`rice/snippets/neko-lid-sounds.lua` into `hypr-user.lua`.

## Dynamic cursor plugin

The upstream-supported HyprPM commands are:

```sh
hyprpm add https://github.com/VirtCode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors
```

The plugin targets specific Hyprland versions. After a Hyprland update, run
`hyprpm update` and re-enable or rebuild the plugin if it does not load. Keep
plugins out of the mandatory install path.

## Useful user-owned additions

Examples belong in `hypr-user.lua`, using the same `hl.bind`, `hl.on`, and
`hl.exec_cmd` APIs as Caelestia itself:

- a brain-dump key that opens `foot -e nvim ~/notes/inbox.md`
- window rules for Obsidian and calculators
- workspace startup commands
- animation and blur changes appropriate for the laptop's performance

Commit an experiment only after it has survived a reboot and a Caelestia
update. Record reversions in `~/notes/journal.md`.
