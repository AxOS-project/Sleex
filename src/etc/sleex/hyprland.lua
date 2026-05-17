-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in file in `custom`
hl.dsp.exec_cmd("hyprctl dispatch submap global")
hl.dsp.submap("global")

-- Defaults
require("hyprland/env")
require("hyprland/execs")
require("hyprland/general")
require("hyprland/rules")
require("hyprland/colors")
require("hyprland/keybinds")

-- Custom
local home_dir = os.getenv("HOME")
local function safe_require_absolute(path)
    local absolute_path = path:gsub("^~", home_dir)
    
    local file_to_check = absolute_path .. ".lua"
    local file = io.open(file_to_check, "r")
    if file then
        file:close()
        
        dofile(file_to_check)
    end
end

safe_require_absolute("~/.config/hypr/custom/env")
safe_require_absolute("~/.config/hypr/custom/execs")
safe_require_absolute("~/.config/hypr/custom/genera")
safe_require_absolute("~/.config/hypr/custom/rules")
safe_require_absolute("~/.config/hypr/custom/keybinds")

safe_require_absolute("~/.config/hypr/monitors")

-- Applications bindings
safe_require_absolute("~/.config/hypr/apps")
