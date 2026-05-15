-- Bar, wallpaper
-- hl.dsp.exec_cmd("swww-daemon")
hl.dsp.exec_cmd("qs -p /usr/share/sleex &")

-- Core components (authentication, lock screen, notification daemon)
hl.dsp.exec_cmd("dbus-update-activation-environment --all")
hl.dsp.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP") -- Some fix idk

-- Audio
hl.dsp.exec_cmd("easyeffects --gapplication-service")

-- Clipboard: history
-- hl.dsp.exec_cmd("wl-paste --watch cliphist store &")
hl.dsp.exec_cmd("wl-paste --type text --watch cliphist store")
hl.dsp.exec_cmd("wl-paste --type image --watch cliphist store")

-- Cursor
hl.dsp.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
