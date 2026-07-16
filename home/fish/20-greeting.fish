# Optional pony fortune in new interactive terminals. The custom Clock pony is
# optional. If it is not installed, ponysay falls back to its normal roster.
if status is-interactive; and command -q ponysay; and command -q fortune
    set -l clock ~/.local/share/momiji/ponies/clockwork-relativity.pony
    if test -r $clock; and test (random 0 1) -eq 0
        fortune -s | ponysay -f $clock
    else
        fortune -s | ponysay
    end
end
