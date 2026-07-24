# Apply this overlay to momiji-dots

The overlay adds the Momiji Maple SDDM theme and replaces
`scripts/enable-display-manager.sh` with the same current workflow plus the
new theme installation step.

Copy it into the repository:

```fish
cd ~/Downloads
unzip momiji-maple-sddm-overlay.zip
cp -a momiji-maple-sddm-overlay/. ~/momiji-dots/
```

Then validate, install, and preview:

```fish
cd ~/momiji-dots
chmod +x scripts/install-sddm-theme.sh \
    scripts/uninstall-sddm-theme.sh \
    scripts/enable-display-manager.sh
./scripts/validate-repo.sh
./scripts/install-sddm-theme.sh
sddm-greeter --test-mode --theme /usr/share/sddm/themes/momiji-maple
```

This does not replace `etc/sddm.conf.d/10-momiji.conf`. Autologin remains
disabled, so boot still requires the separate LUKS and Linux passwords.
