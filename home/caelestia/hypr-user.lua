-- Momiji user-owned Hyprland additions for Caelestia's Lua configuration.
-- Caelestia loads this file after its managed configuration.

local home = os.getenv("HOME")
local login_sound = home .. "/.local/share/momiji/sounds/login-chime.wav"

hl.on("hyprland.start", function()
    hl.exec_cmd(
        "test -r " .. string.format("%q", login_sound)
        .. " && pw-play " .. string.format("%q", login_sound)
    )
end)
