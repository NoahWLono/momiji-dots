# Clockwork Relativity pony

The custom `clockwork-relativity.pony` file is optional. It is not currently in
this repository, so a clean install must not depend on it.

When a finished, licensed `.pony` file is available, place it here and run:

```sh
install -Dm644 rice/ponies/clockwork-relativity.pony \
  ~/.local/share/momiji/ponies/clockwork-relativity.pony
fortune -s | ponysay -f ~/.local/share/momiji/ponies/clockwork-relativity.pony
```

The Fish greeting already handles the file being absent and uses ponysay's
normal roster instead. Do not commit source artwork unless its licence permits
redistribution and the artist credit is recorded here.
