-- Optional lid sounds for Caelestia's Lua Hyprland configuration.
-- Merge this into ~/.config/caelestia/hypr-user.lua only after checking:
--   hyprctl devices
-- Confirm the exact switch name and whether `on` means closed on this laptop.

local home = os.getenv("HOME")
local sounds = home .. "/.local/share/momiji/sounds/"

local function play(name)
    return hl.dsp.exec_cmd(
        "pw-play " .. string.format("%q", sounds .. name)
    )
end

-- Common mapping. Reverse these two lines if hardware reports the opposite.
hl.bind("switch:on:Lid Switch", play("purr-close.wav"), { locked = true })
hl.bind("switch:off:Lid Switch", play("nya-open.wav"), { locked = true })
