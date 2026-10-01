# MapleOS: First Harvest

**1.0.0-preview.1. An independent x86-64 Arch-based live distribution, not a stable daily-driver release.**

Arch roots. Maple personality. Your machine, your agency.

This is a source-buildable Archiso profile derived from selected assets in Noah's Momiji dotfiles. It is NOT a disk clone. It does not contain Momiji's home directory, browser profile, Wi-Fi credentials, SSH keys, VPN state, personal hardware settings, or API credentials.

## The first preview

A Maple-themed Hyprland Lua desktop, Waybar, Fuzzel, SDDM, Fish, Maple ASCII Fastfetch, Firefox, PipeWire, NetworkManager, and zram. The live session logs in as `maple`; its password is `maple`. Root login is locked and SSH is masked. The live password is not an installed-system password.

**This is a lean MapleOS desktop, not the full Caelestia shell.** The original Momiji Caelestia overrides are preserved as provenance, not run without their dependencies. Packaging and validating the complete Caelestia stack is a separate release milestone. No AUR helper, unsigned custom repository, large security-tool suite, or model weights are bundled.

## AI-native, without handing an agent the machine

`maple-ai` is a small Python-standard-library client for user-selected OpenAI-compatible Chat Completions endpoints. It is not affiliated with any model provider. Model compatibility, tool support, prices and account requirements depend on the endpoint you select.

```
maple-ai setup
maple-ai chat
maple-ai agent --workspace demo
maple-ai doctor
maple-ai sandbox 'python -c "print(2 + 2)"' --workspace demo
```

Super+A opens the assistant. Provider setup saves an endpoint and model name, never the key. Cloud keys are read from the chosen environment variable or prompted without echo. There are no built-in subscriptions, API credits, model downloads or automatic paid calls. Connect confirmation is required for each session. The desktop never starts a background agent.

In agent mode, model-proposed shell commands require individual approval. Commands run under bubblewrap with isolated namespaces, no network, no host home, no desktop sockets, no inherited credential environment, no capabilities, bounded output and execution time. Only `/usr` (read-only runtime) and the explicit workspace are exposed. The client refuses root and has no unsandboxed fallback. Session tool calls are capped at eight.

The provider sees your prompts and output from approved commands. Do not place secrets in `~/Maple/Workspaces/<name>`. Approved commands can read, modify or delete everything in that workspace. Keep backups. The sandbox is defense in depth, not a guarantee against kernel vulnerabilities or a substitute for reviewing commands. There is no automatic filesystem indexing or persistent chat transcript.

For local inference, install/start a compatible model server and obtain a model separately. Configure its loopback endpoint and model name. This ISO does not claim offline inference without those components. Native Anthropic endpoints, MCP servers, GUI automation and OpenShell integration are not implemented in this preview.

## Use the live ISO

Download the ISO plus `ISO-SHA256SUMS` from a successful MapleOS release and verify:

```
sha256sum -c ISO-SHA256SUMS
```

If the release has split ISO parts because of GitHub's per-file limit, concatenate the parts in filename order first. The release includes `REASSEMBLE.txt` with the exact command. The resulting ISO is the same image that was tested, verified by `ISO-SHA256SUMS`.

Write the image using an image-writing utility, or attach it to a disposable x86-64 VM. **Writing an image to a USB device erases that selected device.** No raw-device write command is automated by this project. Start VM testing with 4 GiB RAM, two vCPUs and Virtio video. Hardware requirements and driver compatibility have not been comprehensively validated. Secure Boot must be disabled for this unsigned preview. ARM and Apple Silicon native boot are not supported.

Super+Enter opens a terminal; Super+R the launcher; Super+N networking; Super+B Firefox; Super+E files; Super+W the welcome page; Super+Q closes a window. Super+1..0 selects workspaces; Super+Shift+Escape logs out. The initial keyboard layout is US. Change `~/.config/hypr/hyprland.lua` for other layouts.

## Online installation (experimental)

**Back up first. Test in a disposable VM. Disk installation is not covered by the initial live-boot test matrix.**

Connect with `nmtui`, then run `sudo maple-install`. It explicitly asks before opening the official interactive Archinstall utility. You choose the disk, partition layout, encryption, bootloader, timezone, locale and normal administrator user. Select a minimal installation and `/mnt` as the mount point. Do not reboot before the overlay step.

When Archinstall finishes, `maple-apply` verifies an installed Arch root is mounted at `/mnt`, asks for the created username and asks you to type `APPLY MAPLEOS`. It performs a full system update in the target, installs the Maple desktop packages and applies the user configuration. It does not partition disks or choose encryption/bootloader settings for you. Internet is required. If Archinstall unmounted the target, remount it according to your chosen disk layout before running `maple-apply`.

Installed accounts use their own passwords and do not inherit live autologin, the live account password, Wi-Fi credentials or API keys. Existing `.config` and `.local` directories are renamed with a timestamp before applying this preview's defaults. The overlay is intended for a fresh installation, not for upgrading a valuable existing desktop.

## Build

Use a disposable x86-64 Linux build host with Docker and sufficient disk space (roughly 25 GiB free is a starting estimate; actual usage depends on Arch packages). The container must be privileged for Archiso mounts. **Never run unreviewed pull-request code in this privileged job.**

From the root of the repository, after reviewing the source:

```sh
mkdir -p mapleos-out
sudo docker run --rm --privileged \
  -v "$PWD:/src:ro" -v "$PWD/mapleos-out:/out" \
  -w /src -e MAPLE_OUT_DIR=/out \
  archlinux:base@sha256:b21322c663be387c0ed9cbc7bbbfe18e41633ad4e7b7c77cfad45f128be20040 \
  bash -euc 'pacman -Syu --noconfirm archiso python; bash mapleos/build.sh'
```

The read-only source mount avoids modification of your checkout. Builds install current signed packages from the configured official Arch repositories. The container digest and project commit are pinned, but the package repositories roll. Every build records its exact package versions and asset hashes. **This is not a claim of bit-for-bit reproducibility.** A fixed, independently verified Arch Linux Archive snapshot is a later milestone.

GitHub Actions builds from the isolated `mapleos-v1` branch. It runs offline unit tests, builds the ISO, boots the actual image through BIOS and UEFI in QEMU, verifies the live account/sandbox/desktop, and captures screenshots and serial logs. The publishing step requires both boot tests to pass. It stages a draft release, uploads all files and checksums, then publishes the prerelease. No empty or failed build is intentionally published as a working ISO.

## Release evidence and limits

`build-info.json`: source commit, asset hashes, ISO digest, build-tool version.

`packages.txt` and `package-metadata.txt`: exact installed packages, versions, licenses and upstream URLs.

`boot-tests.json`, `bios-serial.log`, `uefi-serial.log`, desktop screenshots: actual live-boot evidence. These are not evidence of a tested disk install or universal hardware compatibility.

`mapleos-source.tar.gz`: MapleOS source and its explicitly selected Momiji assets.

`ISO-SHA256SUMS` and `SHA256SUMS`: integrity checks. Checksums alone do not establish publisher identity. This preview has no maintainer signing key or Secure Boot signing chain.

Known gaps before stable 1.0: end-to-end encrypted disk-install testing, physical Intel/AMD/NVIDIA/Wi-Fi testing, suspend/resume, accessibility review, full Caelestia packaging, source-redistribution audit and retention, reproducible package snapshot, signed releases, upgrade/rollback policy and a maintenance/security process.

## Project identity and licensing

MapleOS is independent of Arch Linux, Caelestia, OpenAI and NVIDIA. The Maple mascot is fictional. The operating system's assistant branding does not confer authority on a model or make the assistant a person.

New MapleOS integration code is under `LICENSE`. Third-party packages, upstream Archiso templates, and Momiji assets retain their own rights and licenses. See `THIRD_PARTY.md`. No blanket relicensing of dependencies is intended.

References: https://wiki.archlinux.org/title/Archiso ; https://man.archlinux.org/man/mkarchiso.1 ; https://wiki.hypr.land/Configuring/Start/ ; https://github.com/archlinux/archinstall ; https://github.com/containers/bubblewrap ; https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
