# Maple Nekokami terminal greeting.
# Overrides Caelestia's default fish_greeting without modifying upstream files.

function fish_greeting
    # Maple palette:
    # harvest gold, autumn auburn, agricultural green

    set_color D4A017
    echo "   /\\_/\\      Maple Nekokami"
    echo "  ( o.o )     Momiji terminal shrine"
    echo "   > ^ <      neko mode: active"
    echo

    set_color 9A3F24
    echo '#   #  ###  ####  #     #####       #   # ##### #   #  ###  #   #  ###  #   # #####'
    echo '## ## #   # #   # #     #           ##  # #     #  #  #   # #  #  #   # ## ##   #  '
    echo '# # # ##### ####  #     ####        # # # ####  ###   #   # ###   ##### # # #   #  '
    echo '#   # #   # #     #     #           #  ## #     #  #  #   # #  #  #   # #   #   #  '
    echo '#   # #   # #     ##### #####       #   # ##### #   #  ###  #   # #   # #   # #####'
    echo

    set_color 4F7A3A
    echo '                  harvest • code • purr • repeat :3'
    set_color normal
    echo

    if command -q fastfetch
        fastfetch \
            --config "$HOME/momiji-dots/rice/fastfetch/config-maple.jsonc" \
            --key-padding-left 5
    end
end

# Optional pony fortune in new interactive terminals.
# The custom Clock pony is optional. If it is unavailable, ponysay uses
# its normal roster instead.

if status is-interactive; and command -q ponysay; and command -q fortune
    set -l clock ~/.local/share/momiji/ponies/clockwork-relativity.pony

    if test -r $clock; and test (random 0 1) -eq 0
        fortune -s | ponysay -f $clock
    else
        fortune -s | ponysay
    end
end
