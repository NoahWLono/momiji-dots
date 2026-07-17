# Neko session sounds

Three original synthesized clips are dedicated to the public domain under CC0:

- `login-chime.wav`: session start
- `nya-open.wav`: optional lid-open sound
- `purr-close.wav`: optional lid-close sound

`scripts/deploy-configs.sh` copies them to
`~/.local/share/momiji/sounds/`. The login chime is wired by
`home/caelestia/hypr-user.lua`.

Lid switches vary between laptops. The optional current-format Lua example is
`rice/snippets/neko-lid-sounds.lua`. Confirm the switch name and state mapping
with `hyprctl devices` before merging it.

Keep private or separately licensed replacements under `rice/sounds-local/`,
which is ignored by Git.
