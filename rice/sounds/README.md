# Neko session sounds

Three original clips, synthesized (additive/FM synthesis plus shaped
noise), dedicated to the public domain (CC0). No anime, game, or VA
audio was used; these are license-clean for a public repo.

- `nya-open.wav` (0.55s): rising-falling "mew", plays on lid open
- `purr-close.wav` (1.35s): amplitude-modulated purr with two breath
  cycles, deliberately mastered quieter, plays on lid close
- `login-chime.wav` (1.0s): three ascending bells with a tiny mew tail,
  plays at session start (which, with autologin, means every boot)

Swap rule: these filenames are load points. If you find clips you like
better, drop them over the same names and the config never changes.
Licensing rule for replacements: anything you did not make or license
does not belong in a public repo; keep such clips in a gitignored
`sounds-local/` and point the snippet there instead.

Wiring: see `rice/snippets/neko-sounds.conf`.
