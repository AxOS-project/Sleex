----- Window Rules -----

hl.window_rule({
	match = { class = "^(blueberry.py)$" },
	float = true,
})

hl.window_rule({
	match = { title = [[^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$]] },
	float = true,
	keep_aspect_ratio = true,
	pin = true,
	move = "monitor_w * 0.73, monitor_h * 0.72",
	size = "monitor_w * 0.25, monitor_h * 0.25",
})

hl.window_rule({
	match = { class = "^(com.axos-project.axinstall)$" },
	float = true,
})

local center_dialogs = {
	"^(Open File)(.*)$",
	"^(Select a File)(.*)$",
	"^(Choose wallpaper)(.*)$",
	"^(Open Folder)(.*)$",
	"^(Save As)(.*)$",
	"^(Library)(.*)$",
	"^(File Upload)(.*)$",
	"^(Choose)$",
}
for _, pattern in ipairs(center_dialogs) do
	hl.window_rule({
		match = { title = pattern },
		float = true,
		center = true,
	})
end

local float_titles = {
	"^(Choose Files)$",
	"^(Save Image)$",
	"^(Save File)$",
	"^(Calculator)$",
	"^(BoxBuddy)$",
	"^(Popsicle)$",
	"^(Trayscale)$",
}
for _, title in ipairs(float_titles) do
	hl.window_rule({
		match = { title = title },
		float = true,
	})
end

local float_classes = {
	"^(cheese)$",
	"^(timeshift-gtk)$",
	"^(lstopo)$",
	"^(org.gnome.ColorProfileViewer)$",
	"^(qt5ct)$",
	"^(rustdesk)$",
	"^(org.kde.plasmawindowed)$",
	"^(kcm.networkmanagement)$",
}
for _, class in ipairs(float_classes) do
	hl.window_rule({
		match = { class = class },
		float = true,
	})
end

hl.window_rule({
	match = { class = "^(org.pulseaudio.pavucontrol)$" },
	float = true,
	center = true,
	size = "monitor_w * 0.45, monitor_h * 0.45",
})

local immediate_rules = {
	{ type = "title", pattern = [[.*\.exe]] },
	{ type = "title", pattern = [[.*minecraft.*]] },
	{ type = "class", pattern = [[^(steam_app).*]] },
}
for _, rule in ipairs(immediate_rules) do
	hl.window_rule({
		match = { [rule.type] = rule.pattern },
		immediate = true,
	})
end

hl.window_rule({
	match = { float = true },
	no_shadow = true,
})

----- Layer Rules -----

hl.layer_rule({
	match = { namespace = ".*" },
	xray = true,
})

local no_anim_namespaces = {
	"walker",
	"selection",
	"overview",
	"anyrun",
	"indicator.*",
	"osk",
	"hyprpicker",
	"noanim",
}
for _, ns in ipairs(no_anim_namespaces) do
	hl.layer_rule({
		match = { namespace = ns },
		no_anim = true,
	})
end

hl.layer_rule({
	match = { namespace = "gtk-layer-shell" },
	blur = true,
	ignore_alpha = 0,
})
hl.layer_rule({
	match = { namespace = "launcher" },
	blur = true,
	ignore_alpha = 0.5,
})
hl.layer_rule({
	match = { namespace = "notifications" },
	blur = true,
	ignore_alpha = 0.69,
})
hl.layer_rule({
	match = { namespace = "logout_dialog" },
	blur = true,
})

----- Quickshell Rules -----

local function shell_quote(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function get_settings_db_path()
	local config_home = os.getenv("XDG_CONFIG_HOME")
	if not config_home or config_home == "" then
		config_home = (os.getenv("HOME") or "") .. "/.config"
	end
	return config_home .. "/sleex/sleex_settings.db"
end

local function is_shell_transparency_enabled()
	local db_path = get_settings_db_path()
	local f = io.open(db_path, "r")
	if not f then
		return false
	end
	f:close()

	local cmd = "sqlite3 -readonly -batch -noheader -list "
		.. shell_quote(db_path)
		.. " \"SELECT json_extract(config_json, '$.transparency') FROM sleex_settings WHERE module = 'appearance';\" 2>/dev/null"
	local pipe = io.popen(cmd, "r")
	if not pipe then
		return false
	end
	local out = pipe:read("*a") or ""
	pipe:close()

	local val = out:match("^%s*(.-)%s*$")
	return val == "1" or val == "true"
end

local quickshell_blur_rule = hl.layer_rule({
	name = "quickshell-blur",
	match = { namespace = "quickshell:.*" },
	blur = true,
	blur_popups = true,
	ignore_alpha = 0.2,
})

local quickshell_noblur_rule = hl.layer_rule({
	name = "quickshell-noblur",
	match = { namespace = "quickshell:.*" },
	blur = false,
	blur_popups = false,
	ignore_alpha = 1.0,
})

hl.layer_rule({
	match = { namespace = "quickshell:bar" },
	animation = "slide",
})
-- The critical battery countdown border shares the top layer with the bar.
-- A higher order renders lower, so this keeps the border underneath the bar
-- and the island, which then always cover the screen edges they share.
hl.layer_rule({
	match = { namespace = "quickshell:criticalaction" },
	order = 1,
})
hl.layer_rule({
	match = { namespace = "quickshell:cheatsheet" },
	animation = "slide bottom",
})
hl.layer_rule({
	match = { namespace = "quickshell:dock" },
	animation = "slide bottom",
})
hl.layer_rule({
	match = { namespace = "quickshell:lockWindowPusher" },
	no_anim = true,
})
hl.layer_rule({
	match = { namespace = "quickshell:notificationPopup" },
	animation = "fade",
})
hl.layer_rule({
	match = { namespace = "quickshell:overlay" },
	no_anim = true,
	ignore_alpha = 1.0,
})
hl.layer_rule({
	match = { namespace = "quickshell:overview" },
	animation = "slide top",
})
hl.layer_rule({
	match = { namespace = "quickshell:osk" },
	animation = "slide bottom",
})
hl.layer_rule({
	match = { namespace = "quickshell:polkit" },
	no_anim = true,
})
hl.layer_rule({
	match = { namespace = "quickshell:popup" },
	xray = false,
	ignore_alpha = 1.0,
})
hl.layer_rule({
	match = { namespace = "quickshell:reloadPopup" },
	animation = "slide",
})
hl.layer_rule({
	match = { namespace = "quickshell:regionSelector" },
	no_anim = true,
})
hl.layer_rule({
	match = { namespace = "quickshell:screenshot" },
	no_anim = true,
})
local quickshell_session_rule = hl.layer_rule({
	name = "quickshell-session-blur",
	match = { namespace = "quickshell:session" },
	blur = true,
	ignore_alpha = 0,
})
hl.layer_rule({
	match = { namespace = "quickshell:dashboard" },
	animation = "slide bottom",
})
hl.layer_rule({
	match = { namespace = "quickshell:wallpaperSelector" },
	animation = "slide top",
})
hl.layer_rule({
	match = { namespace = "quickshell:batterywarning" },
	blur = false,
	ignore_alpha = 1.0,
	no_anim = true,
})

function sleex_set_quickshell_blur(shell_blur_enabled)
	local hl_blur_enabled = hl.get_config("decoration.blur.enabled") ~= false
	local active = (shell_blur_enabled == true) and hl_blur_enabled
	quickshell_blur_rule:set_enabled(active)
	quickshell_noblur_rule:set_enabled(not active)
	quickshell_session_rule:set_enabled(hl_blur_enabled)
	if hl.exec_scheduled_prop_refresh_immediately then
		hl.exec_scheduled_prop_refresh_immediately()
	end
end

function sleex_sync_quickshell_blur()
	sleex_set_quickshell_blur(is_shell_transparency_enabled())
end

sleex_sync_quickshell_blur()
hl.on("hyprland.start", sleex_sync_quickshell_blur)
hl.on("config.reloaded", sleex_sync_quickshell_blur)
