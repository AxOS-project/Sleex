hl.on("hyprland.start", function () 
    -- Bar, wallpaper
    -- hl.dsp.exec_cmd("swww-daemon")
    hl.exec_cmd("qs -p /usr/share/sleex &")

    -- Core components (authentication, lock screen, notification daemon)
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Audio
    hl.exec_cmd("easyeffects --gapplication-service")

    -- Clipboard: history
    -- hl.exec_cmd("wl-paste --watch cliphist store &")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)