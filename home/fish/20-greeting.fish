# Maple Nekokami terminal greeting.
# Overrides Caelestia's default without modifying upstream files.
# Installed with: fish scripts/momiji-maple.fish install

function fish_greeting
    status is-interactive; or return
    # Stay silent in redirected/non-terminal sessions.
    isatty stdout; or return
    if test "$TERM" = dumb
        return
    end

    set_color D4A017
    printf '\n%s\n' '  MOMIJI // Maple Nekokami'
    set_color 4F7A3A
    printf '%s\n\n' '  harvest / code / purr / repeat :3'
    set_color normal

    if command -q fastfetch
        # Use the installed default config, preserving the user module layout.
        # Stack the portrait above the information in narrow terminal splits.
        if set -q COLUMNS; and test "$COLUMNS" -lt 95
            command fastfetch --logo-position top
        else
            command fastfetch
        end
    end
end

# Preserve the existing optional pony fortune behavior.
if status is-interactive; and isatty stdout; and test "$TERM" != dumb
    if command -q ponysay; and command -q fortune
        set -l clock ~/.local/share/momiji/ponies/clockwork-relativity.pony
        if test -r $clock; and test (random 0 1) -eq 0
            fortune -s | ponysay -f $clock
        else
            fortune -s | ponysay
        end
    end
end
