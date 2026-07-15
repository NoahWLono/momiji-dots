# Pony fortune on new terminals. Coin flip between Clockwork Relativity
# and the canon cast once his .pony exists; silently no-ops until
# ponysay and fortune are installed, so it is safe to deploy early.
if status is-interactive; and command -q ponysay; and command -q fortune
    set -l clock ~/momiji-dots/rice/ponies/clockwork-relativity.pony
    if test -e $clock; and test (random 0 1) -eq 0
        fortune -s | ponysay -f $clock
    else
        fortune -s | ponysay
    end
end
