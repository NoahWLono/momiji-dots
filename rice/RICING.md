# Momiji Rice Layer (Final)

The experimental layer, now living inside `momiji-dots` at `rice/` so one clone installs everything. Everything here happens *after* the runbook's done state, under one ground rule:

**Customize with Caelestia, never against it.** Caelestia owns the files it installed (`~/.config/hypr`, its fish config, foot, the shell). Editing those works until the next `caelestia update` clobbers them. Your changes live in the designated override surfaces (`hypr-vars.lua`, `user-config.fish`, your own `conf.d` files) or in configs Caelestia doesn't own at all. Check once where Caelestia's current docs put user Hyprland overrides, and write it in the journal.

⚠ marks anything from memory or subject to upstream drift; verify those against reality before trusting them.

---

## 0. Install-day quick path

Run after the runbook's Phase 11, from the clone:

```
paru -S --needed - < ~/momiji-dots/rice/fun-packages.txt
install -Dm644 ~/momiji-dots/home/fish/20-greeting.fish ~/.config/fish/conf.d/20-greeting.fish
```

If `rice/ponies/clockwork-relativity.pony` is already committed (see section 2's Mac pre-conversion), that is the whole rice quick path: new terminals now open with pony fortunes, half of them delivered by Clock. If only the source PNG is committed, do section 2's conversion first. The cursor (section 3) and plugins (section 4) stay manual because they depend on a theme hunt and a plugin ecosystem respectively; do them the first slow evening.

## 1. The status bar you already have

Caelestia's shell *is* the bar: battery, network, Bluetooth, audio, media, notifications. Before adding anything, learn what's there:

- **Battery** is a stock module. Style and detail live in the shell's configuration (⚠ path per current Caelestia docs, historically under `~/.config/caelestia/`; check their README rather than guessing).
- **Networks on the go need zero setup.** NetworkManager keeps one profile per SSID: connect once at the new café via the shell's network panel or `nmcli device wifi connect "SSID" password "..."`, and it reconnects automatically forever after.
- **VPN:** the imported Proton WireGuard profile is just another NetworkManager connection: `nmcli connection up <name>` / `down`. Whether the shell's panel exposes VPN toggles directly is version-dependent (⚠); the nmcli commands always work, and a keybind wrapping them is a five-minute project.
- **Party trick:** `nmcli device wifi hotspot ssid momiji password "something"` turns the laptop into an access point.

Do not install waybar/polybar on top of this. Two bars is a turf war, not a rice.

## 2. Clock in the terminal (the OC pipeline)

Ponysay's entire canon cast is Desktop Ponies pixel sprites run through a converter; Clock joins the same assembly line. Toolchain verified to exist (util-say at `github.com/maandree/util-say`, linked from ponysay's own manual); exact flags carry ⚠.

1. **Source:** download the pixel art from `https://derpibooru.org/images/3222695` into `rice/ponies/clock-source.png`, and fill the artist credit line in `rice/ponies/README.md` from the image's artist tag.
2. **Size:** terminal art renders two pixels per character row, so 40 to 60 px tall is the sweet spot:
   ```
   magick clock-source.png -filter point -resize x48 clock-small.png
   ```
   (`imagemagick`; the `point` filter keeps pixel art crisp instead of smearing it. Skip if the source is already sprite-sized.)
3. **Converter:** check the AUR first (`paru -Ss util-say`), else `git clone https://github.com/maandree/util-say` and build per its README. It's Java-era tooling: `paru -S jre-openjdk` first (the same runtime LibreOffice Base wants, so it double-dips). ⚠ Early-2010s code; if it fights you, its cowsay-format output plus `cowsay -f` is the fallback.
4. **Convert:** `./img2ponysay -- clock-small.png > clockwork-relativity.pony` (⚠ exact invocation per util-say's README; the tool name is high-confidence, the flags are from memory).
5. **Test instantly, no install:** `fortune -s | ponysay -f ./clockwork-relativity.pony`
6. **Commit the .pony into `rice/ponies/`.** From then on, every reinstall gets Clock for free and the quick path in section 0 is truly one command.
7. Optional flourish: peek at an installed `.pony` file and imitate its `$$$` metadata header with his name, so `ponysay -l` lists Clockwork Relativity in the roster (formally as an "extra pony", which for Luna's uncanonical mortal son is midda k'neged midda all the way down).

**Mac pre-conversion (recommended):** nothing in steps 2 to 5 needs the laptop. Java plus imagemagick via Homebrew on the Mac, convert this week, commit the `.pony` now, and install day inherits a finished pony. The greeting file already deploys the coin flip: half of new terminals get Clock, half get canon; edit the `random` condition out if it should always be him. A pony whose one blind spot is his own future, dispensing fortunes to yours: that's not a gimmick, that's characterization.

## 3. The cat paw cursor

Cursors are themes, not packages, so this is a hunt plus wiring:

1. **Hunt:** gnome-look.org / pling, Cursors section, search "paw", "cat", "neko"; some themes are packaged in the AUR (`paru -Ss cursor paw` and variations). ⚠ No specific paw theme name is vouched for here; prefer themes shipping a standard `cursors/` directory in XCursor format.
2. **Install:** extract into `~/.local/share/icons/` so it sits like `~/.local/share/icons/PawThemeName/cursors/...`
3. **Wire:** deploy `rice/snippets/hypr-cursor.conf` into your Hyprland override surface with `PawThemeName` replaced, and run its gsettings line once. Caelestia's theming may set its own cursor (⚠); your lines need to load after its.
4. **DIY route**, if the hunt disappoints and the hyperfocus is willing: draw paw frames as PNGs, write the `.in` hotspot files, build with `xcursorgen`, optionally convert with `hyprcursor-util`. A hand-made cursor is deeply on-brand for this machine.

## 4. Cursor physics (the fun multiplier)

A Hyprland plugin makes the cursor tilt, stretch, and spring as it moves, which combined with a paw shape is exactly the energy: ⚠ known as `hypr-dynamic-cursors` (VirtCode's project; verify name and repo before trusting this doc).

```
hyprpm update
hyprpm add https://github.com/VirtCode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors
```

**The plugin tax, stated up front:** plugins compile against your exact Hyprland version. After every Hyprland upgrade, run `hyprpm update` or plugins silently fail to load. Journal it next to the update cadence. Also worth knowing: an overview/exposé plugin (`hyprexpo`) and window motion trails (`hyprtrails`) exist, ⚠ same tax, same verify-first rule.

## 5. Terminal joy, the rest

`rice/fun-packages.txt` covers the canon (paru resolves the repo/AUR mix; ⚠ individual names may drift): `cbonsai` (grow a bonsai, weirdly calming), `pipes.sh` and `cmatrix` (idle animations), `asciiquarium` (fish), `tty-clock` (big clock), `sl` (the typo train, a rite of passage), `lolcat` and `figlet` (rainbow banners), `hyfetch` (fastfetch with pride palettes). Plus **Maple in fastfetch**: foot supports sixel, so the actual wallpaper can be the logo; `rice/fastfetch/config-maple.jsonc` is ready to test non-destructively with `fastfetch --config` before deciding whether to override Caelestia's fastfetch config.

## 6. Hyprland feel

All in your override surface, all cheap to experiment with (`Ctrl+Super+Alt+R` after edits):

- **Animations:** custom bezier curves change the desktop's personality more than any color. Small experiments: faster `workspaces`, springy `windowsIn`.
- **Blur, with a hardware honesty check:** the 7320U has two RDNA2 compute units. One blur pass looks fine; stacked passes plus heavy transparency show up as lag. If the desktop ever feels sticky, blur passes are suspect number one.
- **Window rules:** float and center the calculator, pin foot scratchpads, force Obsidian to a workspace. Highest utility-per-line config in Hyprland.
- **Workspace autostart:** `exec-once` rules that open your standing layout (Obsidian on 2, Firefox on 1) so the machine boots into your context instead of an empty desk.

## 7. The AuDHD utility layer

Less decoration, more prosthetics:

- **Clipboard history is already installed** (`cliphist`, day-1 payload). Wire a keybind to `cliphist list | fuzzel --dmenu | cliphist decode | wl-copy` (⚠ Caelestia may already bind this; check before duplicating).
- **A brain-dump keybind:** one hotkey opening `foot -e nvim ~/notes/inbox.md` parks intrusive thoughts in under two seconds. Process later; capture speed is the point.
- **Timers you can see:** `termdown 25m` (AUR, ⚠ name) in a pinned terminal is the lowest-friction pomodoro that exists.
- **The journal, extended:** `~/notes/journal.md` is also the rice log. Every experiment gets a line; every abandoned experiment gets a line saying why.

## 8. What gets committed where

One repo now. `rice/` is the experimental layer inside the boring provisioning truth. Commit here: override snippets that worked, the fun list as it grows, theme names and where you found them, the `.pony` file, honest notes on reverts. When an experiment becomes something the machine is wrong without, promote it: package names move into `packages.txt` or `aur-packages.txt`, config files move into `home/` or `etc/` with a row in the root README's deploy table. The test for promotion: would a fresh reinstall be incomplete without it?
