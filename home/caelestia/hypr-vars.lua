-- Caelestia user variables. This file is loaded after its defaults.
-- Current upstream already defaults to Firefox, but keeping it explicit makes
-- the intended browser deterministic across reinstalls.
return {
    browser = "firefox",

    -- To use a custom cursor, install the theme under ~/.local/share/icons,
    -- then uncomment and replace the value below.
    -- cursorTheme = "PawThemeName",
    -- cursorSize = 24,
}
