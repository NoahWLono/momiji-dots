#!/usr/bin/env fish

# ============================================================
# MOMIJI SECURITY WORKSTATION INSTALLER
#
# "BlackArch energy without turning Momiji into BlackArch"
#
# Target:
#   Arch Linux
#   Fish shell
#   Existing Momiji configuration
#
# This script:
#   * DOES NOT add the BlackArch repository
#   * DOES NOT modify pacman.conf
#   * DOES NOT use --overwrite='*'
#   * DOES NOT enable daemons
#   * DOES NOT modify user groups
#   * DOES NOT replace Hyprland / Caelestia
#   * DOES NOT reinstall packages already on the machine
#
# Use security tooling only on systems you own or have
# explicit authorization to test.
# ============================================================


# ------------------------------------------------------------
# GLOBAL OPTIONS
# ------------------------------------------------------------

set -g DRY_RUN 0
set -g ASSUME_YES 0
set -g ENABLE_AUR 1
set -g ENABLE_LABS 0
set -g ENABLE_RADIO 0
set -g ENABLE_AI 0

set -g STATE_DIR "$HOME/.local/state/momiji-secstack"

set -g ALREADY_INSTALLED
set -g UNRESOLVED_OFFICIAL
set -g UNRESOLVED_AUR
set -g FAILED_OFFICIAL
set -g FAILED_AUR


# ------------------------------------------------------------
# PRETTY OUTPUT
# ------------------------------------------------------------

function banner
    set_color --bold magenta
    echo
    echo '============================================================'
    echo '         MOMIJI SECURITY WORKSTATION INSTALLER'
    echo '       Arch BTW, but with a suspicious number of tools'
    echo '============================================================'
    set_color normal
    echo
end


function say
    set_color --bold cyan
    printf '[+] '
    set_color normal
    echo (string join ' ' -- $argv)
end


function okay
    set_color --bold green
    printf '[✓] '
    set_color normal
    echo (string join ' ' -- $argv)
end


function warn
    set_color --bold yellow
    printf '[!] '
    set_color normal
    echo (string join ' ' -- $argv)
end


function fail
    set_color --bold red
    printf '[X] '
    set_color normal
    echo (string join ' ' -- $argv)
end


function usage
    echo 'Usage:'
    echo '  ./momiji-secstack.fish [options]'
    echo
    echo 'Options:'
    echo '  --dry-run        Resolve packages but install nothing'
    echo '  --yes            Pass --noconfirm to pacman'
    echo '  --official-only  Completely disable AUR packages'
    echo '  --with-labs      Add QEMU/libvirt/container lab tooling'
    echo '  --with-radio     Add SDR / radio analysis tooling'
    echo '  --with-ai        Add garak and promptfoo'
    echo '  --everything     Enable labs, radio, AI, and AUR'
    echo '  --help           Show this message'
end


# ------------------------------------------------------------
# ARGUMENT PARSING
# ------------------------------------------------------------

for arg in $argv
    switch $arg
        case --dry-run
            set -g DRY_RUN 1

        case --yes
            set -g ASSUME_YES 1

        case --official-only
            set -g ENABLE_AUR 0

        case --with-labs
            set -g ENABLE_LABS 1

        case --with-radio
            set -g ENABLE_RADIO 1

        case --with-ai
            set -g ENABLE_AI 1

        case --everything
            set -g ENABLE_AUR 1
            set -g ENABLE_LABS 1
            set -g ENABLE_RADIO 1
            set -g ENABLE_AI 1

        case --help -h
            usage
            exit 0

        case '*'
            fail "Unknown argument: $arg"
            usage
            exit 1
    end
end


banner


# ------------------------------------------------------------
# PREFLIGHT
# ------------------------------------------------------------

if test (id -u) -eq 0
    fail 'Do not run this script as root.'
    echo 'Run it as your normal Momiji user. It invokes sudo itself.'
    exit 1
end


if not test -r /etc/arch-release
    fail 'This script is for Arch Linux.'
    exit 1
end


if not command -q pacman
    fail 'pacman not found.'
    exit 1
end


if not command -q sudo
    fail 'sudo not found.'
    exit 1
end


mkdir -p "$STATE_DIR"

set -g STAMP (date +%Y%m%d-%H%M%S)


say "State directory: $STATE_DIR"


# ------------------------------------------------------------
# SNAPSHOT CURRENT PACKAGE STATE
# ------------------------------------------------------------

if test $DRY_RUN -eq 0
    say 'Recording current package state...'

    pacman -Qqe | sort \
        > "$STATE_DIR/explicit-before-$STAMP.txt"

    pacman -Qqm | sort \
        > "$STATE_DIR/foreign-before-$STAMP.txt"

    okay 'Package inventory saved.'
else
    warn 'Dry run enabled. No package inventory will be written.'
end


# ------------------------------------------------------------
# SUDO
# ------------------------------------------------------------

if test $DRY_RUN -eq 0
    say 'Requesting sudo credentials...'

    sudo -v

    or begin
        fail 'Could not authenticate sudo.'
        exit 1
    end
end


# ------------------------------------------------------------
# SYSTEM UPDATE
# ------------------------------------------------------------

say 'Updating Arch before installing security tooling...'

if test $DRY_RUN -eq 0
    if test $ASSUME_YES -eq 1
        sudo pacman -Syu --noconfirm
    else
        sudo pacman -Syu
    end

    or begin
        fail 'System update failed. Stopping before installing anything else.'
        exit 1
    end
else
    echo 'DRY RUN: sudo pacman -Syu'
end


# ------------------------------------------------------------
# PARU BOOTSTRAP
#
# Your Momiji repo already includes paru.
# This is only a fallback if it is absent locally.
# ------------------------------------------------------------

function ensure_paru

    if command -q paru
        okay 'paru already installed.'
        return 0
    end

    if test $ENABLE_AUR -eq 0
        return 1
    end

    warn 'paru is missing.'

    if test $DRY_RUN -eq 1
        echo 'DRY RUN: bootstrap paru-bin from the AUR'
        return 1
    end

    say 'Bootstrapping paru-bin using the same basic strategy as momiji-dots...'

    set -l tmpdir (mktemp -d)

    git clone \
        https://aur.archlinux.org/paru-bin.git \
        "$tmpdir/paru-bin"

    or begin
        fail 'Could not clone paru-bin.'
        rm -rf "$tmpdir"
        return 1
    end

    pushd "$tmpdir/paru-bin" >/dev/null

    makepkg -si

    set -l build_status $status

    popd >/dev/null
    rm -rf "$tmpdir"

    if test $build_status -ne 0
        fail 'paru installation failed.'
        return 1
    end

    okay 'paru installed.'
    return 0
end


if test $ENABLE_AUR -eq 1
    ensure_paru
end


# ------------------------------------------------------------
# OFFICIAL PACKAGE INSTALLER
# ------------------------------------------------------------

function install_official_group

    set -l label $argv[1]
    set -l candidates $argv[2..-1]
    set -l todo

    echo
    set_color --bold blue
    echo "== $label =="
    set_color normal

    for pkg in $candidates

        if pacman -Q $pkg >/dev/null 2>&1

            okay "$pkg already installed"
            set -ga ALREADY_INSTALLED $pkg

        else if pacman -Si $pkg >/dev/null 2>&1

            set -a todo $pkg

        else

            warn "$pkg is not currently in your configured Arch repositories"
            set -ga UNRESOLVED_OFFICIAL $pkg

        end
    end

    if test (count $todo) -eq 0
        okay 'Nothing to install in this group.'
        return 0
    end

    say 'Will install:'
    echo "    "(string join ' ' -- $todo)

    if test $DRY_RUN -eq 1
        return 0
    end

    if test $ASSUME_YES -eq 1
        sudo pacman -S --needed --noconfirm $todo
    else
        sudo pacman -S --needed $todo
    end

    or begin
        fail "Official package transaction failed: $label"
        set -ga FAILED_OFFICIAL $label
        return 1
    end

    okay "$label complete."
end


# ------------------------------------------------------------
# AUR PACKAGE INSTALLER
# ------------------------------------------------------------

function install_aur_group

    if test $ENABLE_AUR -eq 0
        return 0
    end

    if not command -q paru
        warn 'paru unavailable. Skipping AUR group.'
        return 1
    end

    set -l label $argv[1]
    set -l candidates $argv[2..-1]
    set -l todo

    echo
    set_color --bold magenta
    echo "== AUR: $label =="
    set_color normal

    for pkg in $candidates

        if pacman -Q $pkg >/dev/null 2>&1

            okay "$pkg already installed"
            set -ga ALREADY_INSTALLED $pkg

        else if paru -Si --aur $pkg >/dev/null 2>&1

            set -a todo $pkg

        else

            warn "$pkg not found in AUR"
            set -ga UNRESOLVED_AUR $pkg

        end
    end

    if test (count $todo) -eq 0
        okay 'Nothing to install in this AUR group.'
        return 0
    end

    warn 'AUR packages are third-party packages.'
    warn 'Review PKGBUILDs when paru asks.'

    say 'Will install:'
    echo "    "(string join ' ' -- $todo)

    if test $DRY_RUN -eq 1
        return 0
    end

    paru -S --needed --aur $todo

    if test $status -ne 0

        warn 'Batch AUR install failed.'
        warn 'Retrying packages individually so one broken PKGBUILD does not kill the entire stack.'

        for pkg in $todo

            paru -S --needed --aur $pkg

            if test $status -ne 0
                fail "AUR install failed: $pkg"
                set -ga FAILED_AUR $pkg
            end
        end
    end
end


# ============================================================
# PACKAGE SETS
# ============================================================


# ------------------------------------------------------------
# NETWORKING / PACKET ANALYSIS / PROTOCOLS
# ------------------------------------------------------------

set network_pkgs \
    nmap \
    masscan \
    wireshark-cli \
    wireshark-qt \
    tcpdump \
    termshark \
    bettercap \
    mitmproxy \
    ettercap \
    ngrep \
    netsniff-ng \
    socat \
    openbsd-netcat \
    arp-scan \
    hping \
    iperf3 \
    mtr \
    traceroute \
    whois \
    bind \
    ldns \
    inetutils \
    net-tools \
    ethtool \
    iw \
    wireless_tools \
    wavemon \
    macchanger \
    proxychains-ng \
    tor \
    torsocks \
    openvpn

install_official_group \
    'Networking and packet analysis' \
    $network_pkgs


# ------------------------------------------------------------
# WEB / HTTP / API SECURITY
# ------------------------------------------------------------

set web_pkgs \
    sqlmap \
    nikto \
    gobuster \
    ffuf \
    feroxbuster \
    wfuzz \
    dirb \
    dirsearch \
    wpscan \
    wapiti \
    whatweb \
    ssh-audit

install_official_group \
    'Web and API security' \
    $web_pkgs


# ------------------------------------------------------------
# PASSWORD / AUTHENTICATION AUDITING
# ------------------------------------------------------------

set password_pkgs \
    hashcat \
    john \
    hydra \
    medusa \
    crunch

install_official_group \
    'Password and authentication auditing' \
    $password_pkgs


# ------------------------------------------------------------
# WINDOWS / SMB / DIRECTORY SERVICE RESEARCH
# ------------------------------------------------------------

set directory_pkgs \
    impacket \
    smbclient \
    samba \
    freerdp \
    openldap

install_official_group \
    'SMB, Windows and directory protocols' \
    $directory_pkgs


# ------------------------------------------------------------
# WIRELESS SECURITY
# ------------------------------------------------------------

set wireless_pkgs \
    aircrack-ng \
    wifite \
    hcxtools \
    hcxdumptool \
    reaver \
    bully \
    kismet \
    mdk4

install_official_group \
    'Wireless security' \
    $wireless_pkgs


# ------------------------------------------------------------
# EXPLOIT DEVELOPMENT / REVERSE ENGINEERING
# ------------------------------------------------------------

set reversing_pkgs \
    metasploit \
    gdb \
    lldb \
    strace \
    ltrace \
    valgrind \
    ghidra \
    radare2 \
    r2ghidra \
    rizin \
    rz-ghidra \
    rz-cutter \
    pwndbg \
    checksec \
    ropgadget \
    ropper \
    capstone \
    keystone \
    unicorn \
    binutils \
    patchelf \
    elfutils \
    pax-utils \
    upx \
    nasm \
    yasm \
    ghex \
    hexyl

install_official_group \
    'Reverse engineering and exploit development' \
    $reversing_pkgs


# ------------------------------------------------------------
# FORENSICS / INCIDENT RESPONSE
# ------------------------------------------------------------

set forensics_pkgs \
    yara \
    python-yara \
    volatility3 \
    sleuthkit \
    testdisk \
    foremost \
    scalpel \
    bulk_extractor \
    binwalk \
    perl-image-exiftool \
    dc3dd \
    ddrescue \
    libewf \
    afflib \
    ssdeep \
    tlsh \
    clamav \
    lynis \
    rkhunter \
    chkrootkit \
    osquery

install_official_group \
    'Forensics and incident response' \
    $forensics_pkgs


# ------------------------------------------------------------
# FUZZING / SOFTWARE TESTING
# ------------------------------------------------------------

set fuzzing_pkgs \
    afl++ \
    afl-utils \
    honggfuzz \
    radamsa \
    zzuf

install_official_group \
    'Fuzzing and software testing' \
    $fuzzing_pkgs


# ------------------------------------------------------------
# CONTAINER / SUPPLY CHAIN / CLOUD SECURITY
# ------------------------------------------------------------

set supplychain_pkgs \
    trivy \
    syft \
    grype \
    gitleaks \
    trufflehog \
    semgrep \
    cosign \
    skopeo \
    buildah \
    podman \
    dive \
    kubectl \
    helm \
    k9s

install_official_group \
    'Supply chain, container and cloud security' \
    $supplychain_pkgs


# ------------------------------------------------------------
# MOBILE / ANDROID RESEARCH
# ------------------------------------------------------------

set mobile_pkgs \
    android-tools \
    apktool \
    jadx \
    smali \
    scrcpy \
    python-frida-tools

install_official_group \
    'Android and mobile analysis' \
    $mobile_pkgs


# ------------------------------------------------------------
# CRYPTO / ENCODING / FILE ANALYSIS
# ------------------------------------------------------------

set crypto_pkgs \
    openssl \
    age \
    gnupg \
    rhash \
    hashdeep \
    pngcheck \
    imagemagick

install_official_group \
    'Cryptography and file inspection' \
    $crypto_pkgs


# ============================================================
# AUR EXTRAS
#
# Deliberately separate from official Arch packages.
# ============================================================

set aur_web_pkgs \
    burpsuite \
    zaproxy-bin \
    seclists \
    exploitdb-git \
    testssl.sh-git

install_aur_group \
    'Web tooling and wordlists' \
    $aur_web_pkgs


set aur_osint_pkgs \
    theharvester \
    sherlock-project \
    recon-ng \
    metagoofil

install_aur_group \
    'OSINT tooling' \
    $aur_osint_pkgs


set aur_auth_pkgs \
    cewl \
    enum4linux-ng \
    responder \
    netexec \
    evil-winrm

install_aur_group \
    'Additional authentication and network tooling' \
    $aur_auth_pkgs


set aur_forensics_pkgs \
    autopsy \
    guymager

install_aur_group \
    'Additional forensic interfaces' \
    $aur_forensics_pkgs


# ============================================================
# OPTIONAL LAB ENVIRONMENT
# ============================================================

if test $ENABLE_LABS -eq 1

    set lab_pkgs \
        qemu-desktop \
        virt-manager \
        libvirt \
        edk2-ovmf \
        swtpm \
        dnsmasq \
        bridge-utils \
        docker \
        distrobox

    install_official_group \
        'Virtualization and security lab infrastructure' \
        $lab_pkgs

    echo
    warn 'Lab packages were installed, but no services were enabled.'
    warn 'Enable libvirtd, Docker, etc. yourself only if you actually need them.'

else
    say 'Lab bundle disabled. Use --with-labs to include it.'
end


# ============================================================
# OPTIONAL SDR / RADIO SECURITY TOOLING
# ============================================================

if test $ENABLE_RADIO -eq 1

    set radio_pkgs \
        rtl-sdr \
        hackrf \
        gnuradio \
        inspectrum \
        gqrx

    install_official_group \
        'SDR and radio analysis' \
        $radio_pkgs

else
    say 'SDR bundle disabled. Use --with-radio to include it.'
end


# ============================================================
# OPTIONAL AI SECURITY
#
# Momiji already includes python-pipx and npm in its repo
# manifest, so use isolated tooling instead of polluting the
# system Python environment.
# ============================================================

if test $ENABLE_AI -eq 1

    echo
    set_color --bold magenta
    echo '== AI security tooling =='
    set_color normal

    if command -q pipx

        set -l garak_present 0

        if command -q jq
            pipx list --json 2>/dev/null \
                | jq -e '.venvs.garak != null' \
                >/dev/null 2>&1

            if test $status -eq 0
                set garak_present 1
            end
        end

        if test $garak_present -eq 1

            okay 'garak already installed through pipx.'

        else if test $DRY_RUN -eq 1

            echo 'DRY RUN: pipx install garak'

        else

            say 'Installing garak with pipx...'
            pipx install garak

        end

    else

        warn 'pipx not available. Skipping garak.'

    end


    if command -q npm

        npm list \
            --global \
            --depth=0 \
            promptfoo \
            >/dev/null 2>&1

        if test $status -eq 0

            okay 'promptfoo already installed.'

        else if test $DRY_RUN -eq 1

            echo 'DRY RUN: npm install --global promptfoo'

        else

            say 'Installing promptfoo into the user-local npm prefix...'

            env NPM_CONFIG_PREFIX="$HOME/.local" \
                npm install --global promptfoo

        end

    else

        warn 'npm not available. Skipping promptfoo.'

    end

else
    say 'AI-security bundle disabled. Use --with-ai to include it.'
end


# ============================================================
# POST-INSTALL INVENTORY
# ============================================================

if test $DRY_RUN -eq 0

    say 'Recording final package state...'

    pacman -Qqe | sort \
        > "$STATE_DIR/explicit-after-$STAMP.txt"

    pacman -Qqm | sort \
        > "$STATE_DIR/foreign-after-$STAMP.txt"

end


# ------------------------------------------------------------
# WRITE UNRESOLVED PACKAGE REPORTS
# ------------------------------------------------------------

if test (count $UNRESOLVED_OFFICIAL) -gt 0

    printf '%s\n' $UNRESOLVED_OFFICIAL \
        | sort -u \
        > "$STATE_DIR/unresolved-official-$STAMP.txt"

end


if test (count $UNRESOLVED_AUR) -gt 0

    printf '%s\n' $UNRESOLVED_AUR \
        | sort -u \
        > "$STATE_DIR/unresolved-aur-$STAMP.txt"

end


if test (count $FAILED_AUR) -gt 0

    printf '%s\n' $FAILED_AUR \
        | sort -u \
        > "$STATE_DIR/failed-aur-$STAMP.txt"

end


# ============================================================
# SUMMARY
# ============================================================

echo
set_color --bold green
echo '============================================================'
echo '                    MOMIJI SECSTACK DONE'
echo '============================================================'
set_color normal
echo

echo "Already-installed packages skipped: "(count $ALREADY_INSTALLED)
echo "Unresolved official package names:  "(count $UNRESOLVED_OFFICIAL)
echo "Unresolved AUR package names:       "(count $UNRESOLVED_AUR)
echo "Failed official groups:             "(count $FAILED_OFFICIAL)
echo "Failed AUR packages:                "(count $FAILED_AUR)

echo
echo "Logs and package inventories:"
echo "  $STATE_DIR"

echo
echo 'Nothing in this script enabled:'
echo '  docker.service'
echo '  libvirtd.service'
echo '  tor.service'
echo '  postgresql.service'
echo '  clamav services'
echo

if getent group wireshark >/dev/null 2>&1
    echo 'Optional Wireshark note:'
    echo '  Arch may use the wireshark group for non-root packet capture.'
    echo '  This script intentionally did not add your user to it.'
    echo
end

set_color --bold magenta
echo 'Momiji remains Momiji.'
echo 'She just has considerably more lockpicks in the toolbox now. :3'
set_color normal
