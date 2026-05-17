hl.config({
	-- Keyboard: Add a layout and uncomment kb_options for Win+Space switching shortcut
	["input.kb_layout"] = "us",
	-- kb_options = grp:win_space_toggle
	["input.numlock_by_default"] = true,
	["input.repeat_delay"] = 250,
	["input.repeat_rate"] = 35,
	["input.special_fallthrough"] = true,
	["input.follow_mouse"] = 1,

	-- Input -> Touchpad Block
	["input.touchpad.natural_scroll"] = true,
	["input.touchpad.disable_while_typing"] = true,
	["input.touchpad.clickfinger_behavior"] = true,
	["input.touchpad.scroll_factor"] = 0.5,

	-- Binds Block
	["binds.scroll_event_delay"] = 0,

	-- Gestures Block
	["gestures.workspace_swipe_distance"] = 700,
	["gestures.workspace_swipe_cancel_ratio"] = 0.2,
	["gestures.workspace_swipe_min_speed_to_force"] = 5,
	["gestures.workspace_swipe_direction_lock"] = true,
	["gestures.workspace_swipe_direction_lock_threshold"] = 10,
	["gestures.workspace_swipe_create_new"] = true,

	-- General Block
	["general.gaps_in"] = 2,
	["general.gaps_out"] = 4,
	["general.gaps_workspaces"] = 50,
	["general.border_size"] = 1,
	["general.col.active_border"] = "rgba(0DB7D4FF)",
	["general.col.inactive_border"] = "rgba(31313600)",
	["general.resize_on_border"] = true,
	["general.no_focus_fallback"] = true,
	["general.layout"] = "dwindle",
	["general.allow_tearing"] = true,

	-- Dwindle Layout Block
	["dwindle.preserve_split"] = true,
	["dwindle.smart_split"] = false,
	["dwindle.smart_resizing"] = false,

	-- Decoration Block
	["decoration.rounding"] = 7,
	["decoration.dim_inactive"] = false,
	["decoration.dim_strength"] = 0.1,
	["decoration.dim_special"] = 0,

	-- Decoration -> Blur Block
	["decoration.blur.enabled"] = true,
	["decoration.blur.xray"] = true,
	["decoration.blur.special"] = false,
	["decoration.blur.new_optimizations"] = true,
	["decoration.blur.size"] = 5,
	["decoration.blur.passes"] = 4,
	["decoration.blur.brightness"] = 1,
	["decoration.blur.noise"] = 0.01,
	["decoration.blur.contrast"] = 1,
	["decoration.blur.popups"] = true,
	["decoration.blur.popups_ignorealpha"] = 0.6,

	-- Animations Toggle
	["animations.enabled"] = true,

	-- Misc Block
	["misc.vrr"] = 1,
	["misc.animate_manual_resizes"] = false,
	["misc.animate_mouse_windowdragging"] = false,
	["misc.enable_swallow"] = false,
	["misc.swallow_regex"] = "(foot|kitty|allacritty|Alacritty)",
	["misc.disable_hyprland_logo"] = true,
	["misc.force_default_wallpaper"] = 0,
	["misc.on_focus_under_fullscreen"] = 2,
	["misc.allow_session_lock_restore"] = true,
	["misc.initial_workspace_tracking"] = false,
	["misc.disable_xdg_env_checks"] = true,
	["misc.session_lock_xray"] = true,

	-- Debug Block
	["debug.vfr"] = true,

	-- Ecosystem Block
	["ecosystem.no_update_news"] = true,
	["ecosystem.no_donation_nag"] = true,
})

------ Gestures Tracking ------
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "vertical", action = "fullscreen" })

------ Animation Curves (Bezier) ------
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("md3_standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.curve("md3_decel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("md3_accel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
hl.curve("crazyshot", { type = "bezier", points = { { 0.1, 1.5 }, { 0.76, 0.92 } } })
hl.curve("hyprnostretch", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1, 0.07 } } })
hl.curve("easeInOutCirc", { type = "bezier", points = { { 0.85, 0 }, { 0.15, 1 } } })
hl.curve("easeOutCirc", { type = "bezier", points = { { 0, 0.55 }, { 0.45, 1 } } })
hl.curve("easeOutExpo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("softAcDecel", { type = "bezier", points = { { 0.26, 0.26 }, { 0.15, 1 } } })
hl.curve("md2", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })

------ Animation Configurations ------
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "md3_accel", style = "popin 60%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.6, bezier = "menu_accel" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 4.5, bezier = "menu_accel" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slidevert" })

