------- Shell Dispatcher -------

hl.bind("SUPER_L", hl.dsp.global("quickshell:searchToggleRelease"), { desc = "Shell: Toggle search" })
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true, release = true })

hl.bind("SUPER+V", hl.dsp.global("quickshell:overviewClipboardToggle"), { desc = "Clipboard history >> clipboard" })
hl.bind("SUPER+semicolon", hl.dsp.global("quickshell:overviewEmojiToggle"), { desc = "Emoji >> clipboard" })
hl.bind("SUPER+D", hl.dsp.global("quickshell:dashboardToggle"), { desc = "Toggle dashboard" })
hl.bind("SUPER+F1", hl.dsp.global("quickshell:cheatsheetToggle"), { desc = "Toggle cheatsheet" })
hl.bind("CTRL+ALT+Delete", hl.dsp.global("quickshell:sessionToggle"), { desc = "Toggle session menu" })
hl.bind("SUPER+T", hl.dsp.global("quickshell:wppselectorToggle"), { desc = "Toggle wallpaper selector" })

------- Notifications & Quick System Scripts -------

hl.bind(
	"SUPER+ALT+F12",
	hl.dsp.exec_cmd(
		'notify-send \'Test notification\' "Here\'s a really long message to test truncation and wrapping\\nYou can middle click or flick this notification to dismiss it!" -a \'Shell\' -A "Test1=I got it!" -A "Test2=Another action" -t 5000'
	)
)
hl.bind(
	"SUPER+ALT+Equal",
	hl.dsp.exec_cmd('notify-send "Urgent notification" "Ah hell no" -u critical -a \'Hyprland keybind\'')
)

-- System volume & brightness
hl.bind(
	"SUPER+XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"),
	{ locked = true, desc = "Mute the mic" }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, desc = "Mute the sink" }
)
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true, desc = "Increase the volume" }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true, desc = "Decrease the volume" }
)
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("qs -p /usr/share/sleex/ ipc call brightness increment"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("qs -p /usr/share/sleex/ ipc call brightness decrement"),
	{ locked = true, repeating = true }
)

------- Stuff -------

hl.bind("SUPER", hl.dsp.exec_cmd("true"), { desc = "Open app launcher" })
hl.bind("CTRL+SUPER+T", hl.dsp.exec_cmd("/usr/share/sleex/scripts/colors/switchwall.sh"), { desc = "Change wallpaper" })

hl.bind(
	"SUPER+SHIFT+T",
	hl.dsp.exec_cmd('grim -g "$(slurp $SLURP_ARGS)" "tmp.png" && tesseract "tmp.png" - | wl-copy && rm "tmp.png"'),
	{ desc = "Screen snip to text >> clipboard" }
)
hl.bind("SUPER+SHIFT+X", hl.dsp.exec_cmd("hyprpicker -a"), { desc = "Pick color (Hex) >> clipboard" })
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true, desc = "Screenshot >> clipboard" })
hl.bind(
	"CTRL+Print",
	hl.dsp.exec_cmd(
		"mkdir -p ~/Pictures/Screenshots && /usr/share/sleex/scripts/grimblast.sh copysave screen ~/Pictures/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"
	),
	{ locked = true, desc = "Screenshot >> clipboard & file" }
)
hl.bind("SUPER+SHIFT+ALT+S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'), { desc = "Screen snip >> edit" })
hl.bind(
	"SUPER+SHIFT+S",
	hl.dsp.exec_cmd("/usr/share/sleex/scripts/grimblast.sh --freeze copy area"),
	{ desc = "Screen snip" }
)

-- Recording scripts
hl.bind(
	"SUPER+ALT+R",
	hl.dsp.exec_cmd("/usr/share/sleex/scripts/record-script.sh"),
	{ desc = "Record region (no sound)" }
)
hl.bind(
	"CTRL+ALT+R",
	hl.dsp.exec_cmd("/usr/share/sleex/scripts/record-script.sh --fullscreen"),
	{ desc = "Record screen (no sound)" }
)
hl.bind(
	"SUPER+SHIFT+ALT+R",
	hl.dsp.exec_cmd("/usr/share/sleex/scripts/record-script.sh --fullscreen-sound"),
	{ desc = "Record screen (with sound)" }
)

------- Session Control -------

hl.bind("SUPER+L", hl.dsp.global("quickshell:lockScreen"), { desc = "Lock session" })
hl.bind("SUPER+End", hl.dsp.exec_cmd("pkill qs && qs -p /usr/share/sleex/shell.qml"), { desc = "Restart Shell" })
hl.bind("SUPER+CTRL+End", hl.dsp.exec_cmd("qs -p /usr/share/sleex/shell.qml"), { desc = "Start Shell" })

------- Window Management -------

hl.bind("SUPER+Left", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER+Right", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER+Up", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER+Down", hl.dsp.window.move({ direction = "down" }))

hl.bind("SUPER+Q", hl.dsp.window.kill(), { desc = "Close an app" })
hl.bind("SUPER+SHIFT+ALT+Q", hl.dsp.exec_cmd("hyprctl kill"), { desc = "Pick and kill a window" })

hl.bind("SUPER+ALT+Space", hl.dsp.window.float(), { desc = "Toggle floating" })
hl.bind("SUPER+F", hl.dsp.window.fullscreen())

hl.bind("SUPER+mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER+mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("SUPER+J", hl.dsp.layout("togglesplit"), { desc = "Toggle split" })

------- Workspace -------

for i = 1, 10 do
	local code_num = (i % 10) + 9 -- Maps 1-10 to keycodes 10-19 (1-9 and 0)
	hl.bind(
		"SUPER+code:" .. code_num,
		hl.dsp.focus({ workspace = i, follow = false }),
		{ desc = "Switch to workspace " .. i }
	)
	hl.bind(
		"SUPER+CTRL+code:" .. code_num,
		hl.dsp.window.move({ workspace = i, follow = false }),
		{ desc = "Move window to workspace " .. i }
	)
end

hl.bind("CTRL+SUPER+Right", hl.dsp.focus({ direction = "right" }))
hl.bind("CTRL+SUPER+Left", hl.dsp.focus({ direction = "left" }))

hl.bind("SUPER+mouse_up", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER+mouse_down", hl.dsp.focus({ direction = "left" }))

hl.bind("SUPER+Page_Down", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER+Page_Up", hl.dsp.focus({ direction = "left" }))

hl.bind("CTRL+SUPER+SHIFT+Right", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("CTRL+SUPER+SHIFT+Left", hl.dsp.window.move({ workspace = "e-1" }))

hl.bind("SUPER+SHIFT+mouse_down", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind("SUPER+SHIFT+mouse_up", hl.dsp.window.move({ workspace = "e+1" }))

------- Media Controls -------

hl.bind(
	"XF86AudioNext",
	hl.dsp.exec_cmd(
		'playerctl next || playerctl position `bc <<< "100 * $(playerctl metadata mpris:length) / 1000000 / 100"`'
	),
	{ locked = true, desc = "Next track" }
)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, desc = "Previous track" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Media play/pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })