#!/usr/bin/env bash

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="/usr/share/sleex"
CACHE_DIR="$XDG_CACHE_HOME/sleex"
STATE_DIR="$XDG_STATE_HOME/sleex"
DB_CONFIG="$XDG_CONFIG_HOME/sleex/sleex_settings.db"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MATUGEN_DIR="$XDG_CONFIG_HOME/matugen"
terminalscheme="$CONFIG_DIR/scripts/terminal/scheme-base.json"
THUMBNAIL_DIR="/tmp/sleex_thumbnails"

handle_kde_material_you_colors() {
    local kde_scheme_variant=""
    case "$type_flag" in
        scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot)
            kde_scheme_variant="$type_flag"
            ;;
        *)
            kde_scheme_variant="scheme-tonal-spot"
            ;;
    esac
    "$XDG_CONFIG_HOME"/matugen/templates/kde/kde-material-you-colors-wrapper.sh --scheme-variant "$kde_scheme_variant"
}

pre_process() {
    local mode_flag="$1"
    if [[ "$mode_flag" == "dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    elif [[ "$mode_flag" == "light" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
    fi

    if [ ! -d "$CACHE_DIR"/user/generated ]; then
        mkdir -p "$CACHE_DIR"/user/generated
    fi
}

post_process() {
    local screen_width="$1"
    local screen_height="$2"
    local wallpaper_path="$3"

    handle_kde_material_you_colors &
    sh "$SCRIPT_DIR/material-code-set-color.sh" &
}

check_and_prompt_upscale() {
    local img="$1"
    min_width_desired="$(hyprctl monitors -j | jq '([.[].width] | max)' | xargs)"
    min_height_desired="$(hyprctl monitors -j | jq '([.[].height] | max)' | xargs)"

    if command -v identify &>/dev/null && [ -f "$img" ]; then
        local img_width img_height
        if is_video "$img"; then
            img_width=$min_width_desired
            img_height=$min_height_desired
        else
            img_width=$(identify -format "%w" "$img" 2>/dev/null)
            img_height=$(identify -format "%h" "$img" 2>/dev/null)
        fi
        if [[ "$img_width" -lt "$min_width_desired" || "$img_height" -lt "$min_height_desired" ]]; then
            action=$(notify-send "Upscale?" \
                "Image resolution (${img_width}x${img_height}) is lower than screen resolution (${min_width_desired}x${min_height_desired})" \
                -A "open_upscayl=Open Upscayl"\
                -a "Wallpaper switcher")
            if [[ "$action" == "open_upscayl" ]]; then
                if command -v upscayl &>/dev/null; then
                    nohup upscayl > /dev/null 2>&1 &
                fi
            fi
        fi
    fi
}

is_video() {
    local extension="${1##*.}"
    [[ "$extension" == "mp4" || "$extension" == "mkv" || "$extension" == "webm" ]] && return 0 || return 1 [cite: 4, 5]
}

update_wallpaper_config() {
    local wallpaper_path="$1"

    if [[ -f "$DB_CONFIG" ]]; then
        sqlite3 "$DB_CONFIG" "UPDATE sleex_settings SET config_json = json_set(config_json, '$.wallpaperPath', '$wallpaper_path') WHERE module='background';" [cite: 11]
        qs -p /usr/share/sleex/ ipc call background forceWallpaperReload "$wallpaper_path" [cite: 21, 53]
        qs -p /usr/share/sleex/settings.qml ipc call settings reloadWallpaper "$wallpaper_path"
    fi
}

switch() {
    local imgpath="$1"
    local mode_flag="$2"
    local type_flag="$3"
    local color_flag="$4"
    local color="$5"
    local actual_wallpaper_path="$imgpath"

    read scale screenx screeny screensizey < <(hyprctl monitors -j | jq '.[] | select(.focused) | .scale, .x, .y, .height' | xargs)
    cursorposx=$(hyprctl cursorpos -j | jq '.x' 2>/dev/null) || cursorposx=960
    cursorposx=$(bc <<< "scale=0; ($cursorposx - $screenx) * $scale / 1")
    cursorposy=$(hyprctl cursorpos -j | jq '.y' 2>/dev/null) || cursorposy=540
    cursorposy=$(bc <<< "scale=0; ($cursorposy - $screeny) * $scale / 1")
    cursorposy_inverted=$((screensizey - cursorposy))

    if [[ "$color_flag" == "1" ]]; then
        matugen_args=(color hex "$color")
        generate_colors_material_args=(--color "$color")
    else
        if [[ -z "$imgpath" ]]; then
            echo 'Aborted'
            exit 0
        fi

        check_and_prompt_upscale "$imgpath" &

        if is_video "$imgpath"; then
            mkdir -p "$THUMBNAIL_DIR"
            if ! command -v ffmpeg &> /dev/null; then
                exit 0
            fi

            thumbnail="$THUMBNAIL_DIR/$(basename "$imgpath").jpg"
            ffmpeg -y -i "$imgpath" -vframes 1 "$thumbnail" 2>/dev/null

            if [ -f "$thumbnail" ]; then
                imgpath="$thumbnail"
                matugen_args=(image "$imgpath")
                generate_colors_material_args=(--path "$imgpath")
                update_wallpaper_config "$actual_wallpaper_path"
            else
                exit 1
            fi
        else
            matugen_args=(image "$imgpath")
            generate_colors_material_args=(--path "$imgpath")
            update_wallpaper_config "$actual_wallpaper_path"
        fi
    fi

    if [[ -z "$mode_flag" ]]; then
        current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$current_mode" == "prefer-dark" ]]; then
            mode_flag="dark"
        else
            mode_flag="light"
        fi
    fi

    [[ -n "$mode_flag" ]] && matugen_args+=(--mode "$mode_flag") && generate_colors_material_args+=(--mode "$mode_flag")
    [[ -n "$type_flag" ]] && matugen_args+=(--type "$type_flag") && generate_colors_material_args+=(--scheme "$type_flag")
    generate_colors_material_args+=(--termscheme "$terminalscheme" --blend_bg_fg)
    generate_colors_material_args+=(--cache "$STATE_DIR/user/generated/color.txt")

    pre_process "$mode_flag"

    matugen "${matugen_args[@]}"
    python3 "$SCRIPT_DIR/generate_colors_material.py" "${generate_colors_material_args[@]}" \
        > "$STATE_DIR"/user/generated/material_colors.scss
    "$SCRIPT_DIR"/applycolor.sh

    max_width_desired="$(hyprctl monitors -j | jq '([.[].width] | min)' | xargs)"
    max_height_desired="$(hyprctl monitors -j | jq '([.[].height] | min)' | xargs)"
    post_process "$max_width_desired" "$max_height_desired" "$actual_wallpaper_path"
}

main() {
    local imgpath=""
    local mode_flag=""
    local type_flag=""
    local color_flag=""
    local color=""
    local noswitch_flag=""

    get_type_from_config() {
        local val=$(sqlite3 "$DB_CONFIG" "SELECT json_extract(config_json, '$.palette.type') FROM sleex_settings WHERE module='appearance';" 2>/dev/null)
        echo "${val:-auto}"
    }

    detect_scheme_type_from_image() {
        local img="$1"
        "$SCRIPT_DIR"/scheme_for_image.py "$img" 2>/dev/null | tr -d '\n'
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                mode_flag="$2"
                shift 2
                ;;
            --type)
                type_flag="$2"
                shift 2
                ;;
            --color)
                color_flag="1"
                if [[ "$2" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
                    color="$2"
                    shift 2
                else
                    color=$(hyprpicker --no-fancy)
                    shift
                fi
                ;;
            --image)
                imgpath="$2"
                shift 2
                ;;
            --noswitch)
                noswitch_flag="1"
                imgpath=$(sqlite3 "$DB_CONFIG" "SELECT json_extract(config_json, '$.wallpaperPath') FROM sleex_settings WHERE module='background';" 2>/dev/null)
                shift
                ;;
            *)
                if [[ -z "$imgpath" ]]; then
                    imgpath="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$type_flag" ]]; then
        type_flag="$(get_type_from_config)"
    fi

    if [[ -z "$imgpath" && -z "$color_flag" && -z "$noswitch_flag" ]]; then
        cd "$HOME/.sleex/wallpapers" 2>/dev/null || cd "$(xdg-user-dir PICTURES)" || return 1
        imgpath="$(kdialog --getopenfilename . --title 'Choose wallpaper')"
    fi

    if [[ "$type_flag" == "auto" ]]; then
        if [[ -n "$imgpath" && -f "$imgpath" ]]; then
            detected_type="$(detect_scheme_type_from_image "$imgpath")"
            type_flag="${detected_type:-scheme-tonal-spot}"
        else
            type_flag="scheme-tonal-spot"
        fi
    fi

    switch "$imgpath" "$mode_flag" "$type_flag" "$color_flag" "$color"
}

main "$@"