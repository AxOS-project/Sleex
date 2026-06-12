-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in files in `custom`
require("helpers")

-- Default configurations --
require("hyprland.colors")
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.keybinds")

-- Custom configurations --
safe_load("~/.config/sleex/custom/env")
safe_load("~/.config/sleex/custom/execs")
safe_load("~/.config/sleex/custom/general")
safe_load("~/.config/sleex/custom/rules")
safe_load("~/.config/sleex/custom/keybinds")

safe_load("~/.config/sleex/monitors")
safe_load("~/.config/sleex/apps")