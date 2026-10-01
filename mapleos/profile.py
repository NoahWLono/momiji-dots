#!/usr/bin/env python3
"""Generate an Archiso 91 releng derivative using an explicit Momiji asset allowlist."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
VERSION = (HERE / 'VERSION').read_text().strip()
DESKTOP = '''bubblewrap fastfetch firefox fish foot fuzzel git grim hyprland hyprpolkitagent
networkmanager noto-fonts noto-fonts-emoji openssh pipewire pipewire-alsa pipewire-pulse
python rsync sddm slurp sudo swaybg thunar ttf-dejavu waybar wireplumber wl-clipboard
xdg-desktop-portal-gtk xdg-desktop-portal-hyprland xdg-user-dirs xdg-utils
xorg-server xorg-xwayland zram-generator'''.split()

HYPR = '''-- MapleOS First Harvest. Current Lua API; no Momiji-specific monitor or device IDs.
hl.monitor({output = "", mode = "preferred", position = "auto", scale = 1})
hl.env("XCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.config({
  general = {gaps_in = 5, gaps_out = 12, border_size = 2, layout = "dwindle",
    col = {active_border = {colors = {"rgba(d4a017ee)", "rgba(4f7a3aee)"}, angle = 45}, inactive_border = "rgba(444444aa)"}},
  decoration = {rounding = 12, blur = {enabled = false}},
  animations = {enabled = false},
  input = {kb_layout = "us", follow_mouse = 1, touchpad = {natural_scroll = true}},
  misc = {disable_hyprland_logo = true, force_default_wallpaper = 0}
})
hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
  hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
  hl.exec_cmd("swaybg -i /usr/local/share/mapleos/maple.png -m fill")
  hl.exec_cmd("waybar")
  hl.exec_cmd("foot --title='MapleOS First Harvest' maple-welcome --terminal")
end)
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + R", hl.dsp.exec_cmd("fuzzel"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("foot --title='Maple AI' maple-ai"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("foot nmtui"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("maple-welcome"))
hl.bind("SUPER + V", hl.dsp.window.float({action = "toggle"}))
hl.bind("SUPER + SHIFT + ESCAPE", hl.dsp.exit())
for _, direction in ipairs({"left", "right", "up", "down"}) do
  hl.bind("SUPER + " .. direction, hl.dsp.focus({direction = direction}))
end
for i = 1, 10 do
  hl.bind("SUPER + " .. (i % 10), hl.dsp.focus({workspace = i}))
  hl.bind("SUPER + SHIFT + " .. (i % 10), hl.dsp.window.move({workspace = i}))
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {mouse = true})
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), {mouse = true})
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), {locked = true, repeating = true})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), {locked = true, repeating = true})
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), {locked = true})
'''
WELCOME = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Welcome to MapleOS</title>
<style>body{font:18px/1.6 system-ui,sans-serif;background:#171c19;color:#ede4ce;max-width:950px;margin:4em auto;padding:0 2em}h1{font-size:3.5em;line-height:1.1;color:#d4a017}h2{color:#a9c49a}code{color:#f4ca69}a{color:#d4a017}.tag{letter-spacing:.2em;text-transform:uppercase}img{width:100%;max-height:440px;object-fit:cover;border-radius:20px}article{padding:1em 0;border-bottom:1px solid #435146}</style>
<p class="tag">First Harvest / Technology Preview</p><h1>MapleOS.</h1><p>Arch roots. Maple personality. Your machine, your agency.</p><img src="maple.png" alt="Maple Nekokami wallpaper from Momiji">
<article><h2>A desktop with a workspace assistant, not an assistant that owns your desktop.</h2><p>Press Super+A for Maple. Choose a local or cloud OpenAI-compatible endpoint and a model. No weights, API keys or paid subscription are included. Chat sends only your prompts. Agent mode adds permission-gated commands in a dedicated workspace.</p><p><code>maple-ai setup</code><br><code>maple-ai chat</code><br><code>maple-ai agent --workspace demo</code><br><code>maple-ai doctor</code></p><p>Tools have no network, no access to your home, no host sudo and no desktop socket. Every model-proposed command requires approval. This is defense in depth, not a guarantee against kernel vulnerabilities. Put no secrets in agent workspaces.</p></article>
<article><h2>Find your way around</h2><p>Super+Enter: terminal. Super+R: launcher. Super+B: Firefox. Super+E: files. Super+N: networking. Super+Q: close window. Super+1..0: workspaces. Super+Shift+Escape: logout.</p><p>The live login is <code>maple</code>, password <code>maple</code>. Changes to the live system disappear on reboot. SSH is not enabled. Do not use the live account as a long-term installation.</p></article>
<article><h2>Installation is an explicit human action</h2><p>This preview uses the official interactive Archinstall utility followed by Maple's desktop overlay. Internet is required. Back up first and test a disposable VM. Run <code>sudo maple-install</code>. Nothing chooses or erases a disk automatically.</p><p>After the minimal Arch installation, keep the target mounted at /mnt and apply Maple's desktop. Installed accounts have their own password, no live autologin and no bundled credentials.</p></article>
<article><h2>What this preview is, and is not</h2><p>A bootable x86-64 Arch derivative with a Maple-themed Hyprland desktop, Fish, Firefox and an opt-in AI workspace assistant. The desktop uses a lean Waybar/Fuzzel shell. It is not yet a complete repackaging of Caelestia. Momiji's machine-specific settings, security-tool stack and personal data are intentionally excluded.</p><p>Secure Boot is not supported out of the box. NVIDIA proprietary drivers, ARM, offline installation, arbitrary autonomous desktop control and a fully maintained Maple package repository are not part of this preview.</p><p>Source, test evidence, known limitations and licenses accompany each build. MapleOS is an independent project, not an official Arch Linux, OpenAI, NVIDIA or Caelestia product.</p></article></html>'''

LIVE_SETUP = '''#!/usr/bin/env bash
set -Eeuo pipefail
[[ -e /run/archiso ]] || exit 0
if ! id maple >/dev/null 2>&1; then
    useradd -m -u 1000 -U -G wheel,video,audio,render -s /usr/bin/fish maple
    printf 'maple:maple\\n' | chpasswd
    chmod 700 /home/maple
fi
usermod -L root
cp /usr/local/share/mapleos/os-release /etc/os-release.mapleos
rm -f /etc/os-release
mv /etc/os-release.mapleos /etc/os-release
'''
BOOTCHECK = '''#!/usr/bin/env bash
set -Eeuo pipefail
[[ -e /run/archiso ]] || exit 0
report() { printf '%s\\n' "$1"; if [[ -c /dev/ttyS0 ]]; then printf '%s\\n' "$1" >/dev/ttyS0; fi; }
trap 'report MAPLEOS_BOOT_FAILED' ERR
[[ $(. /etc/os-release; echo "$ID") == mapleos ]]
id maple
! systemctl is-active --quiet sshd.service
runuser -u maple -- /usr/local/bin/maple-ai doctor
report MAPLEOS_LIVE_OK
for _ in $(seq 1 150); do
    if pgrep -u maple -x Hyprland >/dev/null; then
        if runuser -u maple -- env XDG_RUNTIME_DIR=/run/user/1000 hyprctl -i 0 -j configerrors >/run/maple-hypr-errors.json 2>/dev/null; then
            if python -c 'import json; assert json.load(open("/run/maple-hypr-errors.json")) == []'; then
                sleep 8
                report MAPLEOS_DESKTOP_OK
                exit 0
            fi
            cat /run/maple-hypr-errors.json
            exit 1
        fi
    fi
    sleep 1
done
report MAPLEOS_DESKTOP_TIMEOUT
exit 1
'''


def build_profile(destination: Path, upstream: Path, template: Path) -> None:
    if destination.exists():
        raise SystemExit('Refusing to overwrite an existing profile directory: ' + str(destination))
    shutil.copytree(template, destination, symlinks=True)
    root = destination / 'airootfs'
    # Keep official initramfs setup, but replace live services and root-session behavior.
    for rel in ('etc/systemd/system', 'etc/ssh', 'root'):
        p = root / rel
        if p.is_dir() and not p.is_symlink(): shutil.rmtree(p)
        elif p.exists() or p.is_symlink(): p.unlink()
    (root / 'root').mkdir(mode=0o750)
    (root / 'etc/systemd/system').mkdir(parents=True, exist_ok=True)
    executables = []
    def put(rel: str, content: str, mode: int = 0o644) -> None:
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        if p.is_symlink(): p.unlink()
        p.write_text(content)
        p.chmod(mode)
        if mode & 0o111: executables.append('/' + rel)
    def link(rel: str, target: str) -> None:
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        if p.exists() or p.is_symlink(): p.unlink()
        p.symlink_to(target)
    def enable(name: str, target: str = 'multi-user.target') -> None:
        link('etc/systemd/system/' + target + '.wants/' + name, '/usr/lib/systemd/system/' + name)
    def copy_asset(source: str, target: str) -> None:
        s = upstream / source
        if not s.is_file() or s.is_symlink(): raise SystemExit('Missing or symlinked allowlisted asset: ' + source)
        p = root / target
        p.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(s, p)
        p.chmod(0o644)
    for source, target in (
        ('wallpapers/maple.png', 'usr/local/share/mapleos/maple.png'),
        ('rice/fastfetch/maple-ascii.txt', 'etc/skel/.config/fastfetch/maple-ascii.txt'),
        ('home/caelestia/hypr-user.lua', 'usr/local/share/mapleos/provenance/momiji-hypr-user.lua'),
        ('home/caelestia/hypr-vars.lua', 'usr/local/share/mapleos/provenance/momiji-hypr-vars.lua')):
        copy_asset(source, target)
    put('etc/hostname', 'mapleos-live\n')
    put('etc/shadow', 'root:!:14871::::::\n', 0o400)
    put('etc/passwd', 'root:x:0:0:root:/root:/usr/bin/bash\n')
    put('etc/locale.conf', 'LANG=en_US.UTF-8\n')
    put('etc/locale.gen', 'en_US.UTF-8 UTF-8\n')
    put('etc/motd', 'MapleOS First Harvest preview. Live login: maple / maple. Run maple-welcome.\n')
    put('etc/pacman.d/mirrorlist', 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch\n')
    put('etc/NetworkManager/conf.d/20-mapleos.conf', '[main]\ndns=default\n[connectivity]\nenabled=false\n')
    link('etc/resolv.conf', '/run/NetworkManager/resolv.conf')
    put('etc/sudoers.d/20-mapleos', '%wheel ALL=(ALL:ALL) ALL\n', 0o440)
    put('usr/local/share/mapleos/wheel-sudoers', '%wheel ALL=(ALL:ALL) ALL\n')
    put('usr/local/share/mapleos/os-release', 'NAME="MapleOS"\nPRETTY_NAME="MapleOS ' + VERSION + ' (First Harvest)"\nID=mapleos\nID_LIKE=arch\nVERSION_ID="' + VERSION + '"\nBUILD_ID="' + VERSION + '"\nANSI_COLOR="0;33"\nHOME_URL="https://github.com/NoahWLono/momiji-dots/tree/mapleos-v1/mapleos"\n')
    put('usr/local/share/mapleos/branding.hook', '[Trigger]\nOperation = Upgrade\nType = Package\nTarget = filesystem\n[Action]\nDescription = Restoring MapleOS identity\nWhen = PostTransaction\nExec = /usr/bin/install -m644 /usr/local/share/mapleos/os-release /etc/os-release\n')
    zram = '[zram0]\nzram-size = min(ram / 2, 4096)\ncompression-algorithm = zstd\n'
    put('etc/systemd/zram-generator.conf', zram)
    put('usr/local/share/mapleos/zram.conf', zram)
    put('etc/sddm.conf.d/10-mapleos-live.conf', '[Autologin]\nUser=maple\nSession=mapleos.desktop\nRelogin=false\n')
    session = '[Desktop Entry]\nName=MapleOS\nComment=MapleOS Hyprland desktop\nExec=Hyprland\nType=Application\nDesktopNames=Hyprland;\n'
    put('usr/share/wayland-sessions/mapleos.desktop', session)
    put('usr/local/share/mapleos/mapleos.desktop', session)
    put('usr/local/bin/maple-ai', (HERE / 'maple_ai.py').read_text(), 0o755)
    put('usr/local/bin/maple-install', (HERE / 'install.sh').read_text(), 0o755)
    put('usr/local/bin/maple-apply', (HERE / 'apply.sh').read_text(), 0o755)
    put('usr/local/lib/mapleos/live-setup', LIVE_SETUP, 0o755)
    put('usr/local/lib/mapleos/boot-check', BOOTCHECK, 0o755)
    put('usr/local/share/mapleos/desktop-packages.txt', '\n'.join(sorted(DESKTOP)) + '\n')
    put('usr/local/share/mapleos/welcome.html', WELCOME)
    put('usr/local/bin/maple-welcome', '''#!/usr/bin/env bash
set -eu
if [[ ${1:-} == --terminal ]]; then
    printf '\\nMapleOS | First Harvest | Technology Preview\\n\\n'
    printf 'Super+Enter terminal | Super+R launcher | Super+A Maple AI\\n'
    printf 'Super+N networking | Super+W full welcome | Super+Q close\\n\\n'
    printf 'AI: maple-ai setup, maple-ai chat, maple-ai agent --workspace demo\\n'
    printf 'Live login: maple / maple. Installation: sudo maple-install\\n'
    printf 'No AI provider, API key, model weights, or background agent is bundled.\\n\\n'
    exec fish
fi
exec firefox file:///usr/local/share/mapleos/welcome.html
''', 0o755)
    put('usr/lib/systemd/system/mapleos-live.service', '[Unit]\nDescription=Create the ephemeral MapleOS live account\nConditionPathExists=/run/archiso\nAfter=systemd-user-sessions.service\nBefore=display-manager.service\n[Service]\nType=oneshot\nExecStart=/usr/local/lib/mapleos/live-setup\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target\n')
    put('usr/lib/systemd/system/mapleos-check.service', '[Unit]\nDescription=MapleOS preview live health checks\nConditionPathExists=/run/archiso\nAfter=mapleos-live.service display-manager.service\nWants=mapleos-live.service\n[Service]\nType=oneshot\nExecStart=/usr/local/lib/mapleos/boot-check\nTimeoutStartSec=210\n[Install]\nWantedBy=graphical.target\n')
    put('usr/lib/systemd/system/mapleos-keyring.service', '[Unit]\nDescription=Initialize the live package-signing keyring\nAfter=local-fs.target\nConditionPathExists=/run/archiso\n[Service]\nType=oneshot\nExecStart=/usr/bin/pacman-key --init\nExecStart=/usr/bin/pacman-key --populate archlinux\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target\n')
    for name in ('NetworkManager.service', 'mapleos-live.service', 'mapleos-keyring.service'):
        enable(name)
    enable('mapleos-check.service', 'graphical.target')
    link('etc/systemd/system/display-manager.service', '/usr/lib/systemd/system/sddm.service')
    link('etc/systemd/system/default.target', '/usr/lib/systemd/system/graphical.target')
    for name in ('sshd.service', 'sshd.socket', 'cloud-init.service', 'cloud-init-local.service', 'cloud-config.service', 'cloud-final.service'):
        link('etc/systemd/system/' + name, '/dev/null')
    put('etc/skel/.config/hypr/hyprland.lua', HYPR)
    put('etc/skel/.config/foot/foot.ini', '[main]\nfont=monospace:size=10\nshell=/usr/bin/fish\npad=12x12\n[colors]\nbackground=172019\nforeground=ede4ce\n')
    put('etc/skel/.config/fish/conf.d/20-mapleos.fish', '''if status is-interactive
    function fish_greeting
        printf '\\n  MapleOS / First Harvest\\n  Arch roots. Your machine, your agency.\\n\\n'
        if command -q fastfetch
            fastfetch
        end
    end
end
''')
    put('etc/skel/.config/fastfetch/config.jsonc', json.dumps({'logo': {'type': 'file', 'source': '~/.config/fastfetch/maple-ascii.txt', 'color': {'1': '#D4A017', '2': '#9A3F24', '3': '#4F7A3A', '4': '#EDE4CE'}, 'padding': {'right': 3}}, 'modules': ['title', 'separator', 'os', 'kernel', 'uptime', 'packages', 'shell', 'display', 'wm', 'terminal', 'cpu', 'memory', 'break', 'colors']}, indent=2) + '\n')
    put('etc/skel/.config/waybar/config.jsonc', json.dumps({'layer': 'top', 'position': 'top', 'height': 34, 'modules-left': ['custom/maple', 'hyprland/workspaces'], 'modules-center': ['clock'], 'modules-right': ['network', 'pulseaudio', 'memory', 'tray'], 'custom/maple': {'format': 'MapleOS', 'on-click': 'maple-welcome', 'tooltip': False}, 'clock': {'format': '{:%a %d %b  %H:%M}'}, 'network': {'format-wifi': 'Wi-Fi {signalStrength}%', 'format-ethernet': 'Ethernet', 'format-disconnected': 'Offline', 'on-click': 'foot nmtui'}, 'memory': {'format': 'RAM {percentage}%'}, 'pulseaudio': {'format': 'Volume {volume}%', 'format-muted': 'Muted'}}, indent=2) + '\n')
    put('etc/skel/.config/waybar/style.css', '* {font-family: sans-serif; font-size: 13px;} window#waybar {background: #172019; color: #ede4ce;} #custom-maple {color: #d4a017; font-weight: bold; padding: 0 16px;} #workspaces button {color: #a9c49a; padding: 0 8px;} #clock, #network, #pulseaudio, #memory, #tray {padding: 0 12px;}\n')
    put('etc/skel/.config/fuzzel/fuzzel.ini', '[main]\nfont=monospace:size=12\nterminal=foot\n[colors]\nbackground=172019ff\ntext=ede4ceff\nmatch=d4a017ff\nselection=435146ff\nselection-text=ede4ceff\nborder=d4a017ff\n')
    put('etc/skel/Maple/Workspaces/README.txt', 'Create disposable projects here. Agent tools can read, edit or delete anything in their named workspace after your approval. Do not put secrets here. No network access in tools.\n')
    (root / 'etc/skel/Pictures/Wallpapers').mkdir(parents=True, exist_ok=True)
    link('etc/skel/Pictures/Wallpapers/maple.png', '/usr/local/share/mapleos/maple.png')
    put('etc/skel/.local/share/applications/maple-ai.desktop', '[Desktop Entry]\nType=Application\nName=Maple AI\nComment=Opt-in workspace assistant\nExec=foot --title=Maple-AI maple-ai\nTerminal=false\nCategories=Development;Utility;\n')
    put('etc/skel/.local/share/applications/maple-welcome.desktop', '[Desktop Entry]\nType=Application\nName=Welcome to MapleOS\nExec=maple-welcome\nTerminal=false\nCategories=Utility;\n')
    put('etc/skel/.local/share/applications/maple-install.desktop', '[Desktop Entry]\nType=Application\nName=Install MapleOS (online)\nExec=foot sudo maple-install\nTerminal=false\nCategories=System;\n')
    put('usr/lib/firefox/distribution/policies.json', json.dumps({'policies': {'DisableTelemetry': True, 'DisableFirefoxStudies': True, 'DontCheckDefaultBrowser': True}}, indent=2) + '\n')
    for name in ('README.md', 'LICENSE', 'THIRD_PARTY.md'):
        p = HERE / name
        if p.exists(): put('usr/local/share/mapleos/' + name, p.read_text())
    pkgs = destination / 'packages.x86_64'
    if not pkgs.is_file(): raise SystemExit('Expected Archiso x86-64 package list')
    baseline = {x.strip() for x in pkgs.read_text().splitlines() if x.strip() and not x.lstrip().startswith('#')}
    pkgs.write_text('\n'.join(sorted(baseline | set(DESKTOP))) + '\n')
    perms = '\n'.join('  ["' + p + '"]="0:0:755"' for p in executables)
    (destination / 'profiledef.sh').write_text('''#!/usr/bin/env bash
iso_name="mapleos"
iso_label="MAPLEOS_100P1"
iso_publisher="MapleOS Community"
iso_application="MapleOS First Harvest Live Preview"
iso_version="''' + VERSION + '''"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M' '-processors' '2')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers.d/20-mapleos"]="0:0:440"
  ["/root"]="0:0:750"
''' + perms + '\n)\n')
    for subdir in ('syslinux', 'efiboot', 'grub'):
        for p in (destination / subdir).rglob('*'):
            if p.is_file() and not p.is_symlink():
                try: text = p.read_text()
                except UnicodeError: continue
                text = text.replace('Arch Linux', 'MapleOS Preview')
                lines = []
                for line in text.splitlines():
                    if ('archisobasedir=' in line or 'archisolabel=' in line or 'archisosearchuuid=' in line) and 'console=ttyS0' not in line:
                        line += ' console=ttyS0,115200 console=tty0'
                    lines.append(line)
                p.write_text('\n'.join(lines) + '\n')
    print('Profile generated at', destination)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--upstream', type=Path, default=HERE.parent)
    parser.add_argument('--template', type=Path, default=Path('/usr/share/archiso/configs/releng'))
    args = parser.parse_args()
    build_profile(args.root, args.upstream, args.template)
