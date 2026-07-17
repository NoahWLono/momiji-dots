-- Momiji user-owned Hyprland additions for Caelestia's Lua configuration.
-- Caelestia loads this file after its managed configuration.

local home = os.getenv("HOME")
local login_sound = home .. "/.local/share/momiji/sounds/login-chime.wav"

hl.on("hyprland.start", function()
    -- Polkit authentication agent for GUI privilege prompts (udiskie
    -- mounts, pkexec). Starting an already-active unit is a no-op. If
    -- Caelestia ever registers its own agent first, the duplicate
    -- registration fails harmlessly in the user journal.
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

    hl.exec_cmd(
        "test -r " .. string.format("%q", login_sound)
        .. " && pw-play " .. string.format("%q", login_sound)
    )
end)
