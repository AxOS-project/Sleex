hl.config({
    general {
        col.active_border = "#dfe3e739"
        col.inactive_border = "#8b919830"
    }

    misc {
        background_color = "#101417FF"
    }

    plugin {
        hyprbars {
            -- Honestly idk if it works like css, but well, why not
            bar_text_font = Rubik, Geist, AR One Sans, Reddit Sans, Inter, Roboto, Ubuntu, Noto Sans, sans-serif
            bar_height = 30
            bar_padding = 10
            bar_button_padding = 5
            bar_precedence_over_border = true
            bar_part_of_window = true

            bar_color = "#101417FF"
            col.text = "#dfe3e7FF"


            -- example buttons (R -> L)
            -- hyprbars-button = color, size, on-click
            hyprbars-button = "#dfe3e7", 13, 󰖭, hyprctl dispatch killactive
            hyprbars-button = "#dfe3e7", 13, 󰖯, hyprctl dispatch fullscreen 1
            hyprbars-button = "#dfe3e7", 13, 󰖰, hyprctl dispatch movetoworkspacesilent special
        }
    }
})

hl.window_rule({ match = { pin = true }, { colors = {"rgba(93cdf6AA)", "rgba(93cdf677)"} } })
