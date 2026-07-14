if status is-login; and test (tty) = /dev/tty1; and not set -q WAYLAND_DISPLAY
    exec Hyprland
end
