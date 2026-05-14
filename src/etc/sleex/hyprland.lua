-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in file in `custom`
hl.dsp.exec_cmd("hyprctl dispatch submap global"),
hl.dsp.submap("global")

-- Defaults
require("/etc/sleex/hyprland/env.lua")
require("/etc/sleex/hyprland/execs.lua")
require("/etc/sleex/hyprland/general.lua")
require("/etc/sleex/hyprland/rules.lua")
require("/etc/sleex/hyprland/colors.lua")
require("/etc/sleex/hyprland/keybinds.lua")

-- Custom 
require("~/.config/hypr/custom/env.lua")
require("~/.config/hypr/custom/execs.lua")
require("~/.config/hypr/custom/general.lua")
require("~/.config/hypr/custom/rules.lua")
require("~/.config/hypr/custom/keybinds.lua")

require("~/.config/hypr/monitors.lua")

-- Applications bindings
require("~/.config/hypr/apps.lua")