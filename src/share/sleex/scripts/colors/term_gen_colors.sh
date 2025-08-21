#!/usr/bin/env bash

# ---------------------------------------------------------
# Universal terminal emulator theme generation script
# Uses material_colors.scss and a template.
# ---------------------------------------------------------

# Terminal emulator
TERMINAL=("$1" "kitty" "zellij")

# Check if any argument has been forwarded to this script and if not, exit since it does not know which terminal to do it for:
if [[ -z "${1}" ]]; then
    echo "No argument has been given. Usage: $0 <terminal>. Exiting."
    exit 1
fi

# SCSS-file needed for the colors
SCSS_FILE="${XDG_STATE_HOME}/sleex/user/generated/material_colors.scss"

[[ ! -f "${SCSS_FILE}" ]] && { echo "SCSS file not found: ${SCSS_FILE}"; exit 1; }

# Read colors from SCSS-file.
declare -A COLORS
while IFS=": " read -r var value; do
    if [[ $var == \$* ]]; then
        key="${var#\$}"        # removes '$'
        value="${value%;}"     # removes ';'
        COLORS[$key]="$value"
    fi
done < <(grep -E '^\$[a-zA-Z0-9]+' "${SCSS_FILE}")

# "TERMINAL" = index array. So "!" would be bad
for terminal in "${TERMINAL[@]}"; do

    # declare template file and dir
    TEMPLATE_DIR="/usr/share/sleex/scripts/templates/term_emus"
    TEMPLATE_FILE="${TEMPLATE_DIR}/${terminal}.tpl"

    [[ ! -f "${TEMPLATE_FILE}" ]] && { echo "Template not found: ${TEMPLATE_FILE}"; exit 1; }

    # output file location
    OUTPUT_DIR="${XDG_CONFIG_HOME}/${terminal}"

    # You could also just simply define OUTPUT_FILE=${OUTPUT_DIR}/py-matyou-wal-${terminal}.conf (or just use whichever filetype ending you like).
    # I thought this would be a rather "unclean" approach, since people would want to have there file type ending aligned to their other themes I suppose.
    # Change it if you like, it would make this script universally usable for even more terminal emulators.
    # Different file type endings work simply for the reason, these terminal emulators
    # don't watch the file type endings but rather on the given content.
    # This means, the theme config file can have any file type ending (e.g. "conf")
    # as long as the content of this file remains correctly and correspondingly formatted!
    declare -A OUTPUT_FILE=(
        [wezterm]="${OUTPUT_DIR}/colors/py-matyou-wal-${terminal}.toml"
        [foot]="${OUTPUT_DIR}/py-matyou-wal-${terminal}.ini"
        [kitty]="${OUTPUT_DIR}/themes/py-matyou-wal-${terminal}.conf"
        [alacritty]="${OUTPUT_DIR}/py-matyou-wal-${terminal}.yml"
        [ghostty]="${OUTPUT_DIR}/themes/py-matyou-wal-${terminal}"
        [zellij]="${OUTPUT_DIR}/themes/py-matyou-wal-${terminal}.kdl"
    )

    # Check if file exists, if not then exit.
    # Replace placeholders in template and copy (and also replace existing theme file) to config dirs.
    mkdir -p "$(dirname "${OUTPUT_FILE[${terminal}]}")"
    cp "${TEMPLATE_FILE}" "${OUTPUT_FILE[${terminal}]}"

    case $terminal in
        # need to do an extra statement for foot because foot does not support 
        foot)
            for key in "${!COLORS[@]}"; do
                sed -i "s/{${key}}/${COLORS[$key]#\#}/g" "${OUTPUT_FILE[${terminal}]}"
            done
        ;;
        *)
            for key in "${!COLORS[@]}"; do
                sed -i "s/{${key}}/${COLORS[$key]}/g" "${OUTPUT_FILE[${terminal}]}"
            done
        ;;
    esac
    echo "Theme for ${terminal} has been created: ${OUTPUT_FILE[${terminal}}]}"
done

# ============================== #
#  +--------------------------+  #
#  | Force Color on Terminals |  #
#  +--------------------------+  #
# ============================== #


declare -A TERM COL

while IFS= read -r line; do
  if [[ $line =~ ^TERM\[([0-9]+)\]=#([0-9A-Fa-f]{6})$ ]]; then
    TERM["${BASH_REMATCH[1]}"]="#${BASH_REMATCH[2]}"
  elif [[ $line =~ ^COL\[([a-zA-Z0-9_]+)\]=#([0-9A-Fa-f]{6})$ ]]; then
    COL["${BASH_REMATCH[1]}"]="#${BASH_REMATCH[2]}"
  fi
done < <(
  awk '
    /^\$[a-zA-Z0-9_]+:/ {
      line=$0
      sub(/^[ \t]+/, "", line)
      key=$1; sub(/\:.*/, "", key)
      val=$2; gsub(/;.*$/, "", val); gsub(/^[ \t]+|[ \t]+$/, "", val)
      if (match(key, /^\$term([0-9]{1,2})$/, m)) {
        printf("TERM[%d]=#%s\n", m[1], gensub(/^#?([0-9A-Fa-f]{6}).*/, "\\1", "g", val))
      } else {
        gsub(/^\$/, "", key)
        printf("COL[%s]=#%s\n", key, gensub(/^#?([0-9A-Fa-f]{6}).*/, "\\1", "g", val))
      }
    }
  ' "${SCSS_FILE}"
)

send_to_tty() { printf "%b" "$2" > "$1" 2>/dev/null || true; }

seqs=()
for i in $(printf "%s\n" "${!TERM[@]}" | sort -n); do
  hex="${TERM[$i]#\#}"
  seqs+=($'\033]4;'"$i"';#'"$hex"$'\007')
done
if [ -n "${COL[background]:-}" ]; then hb="${COL[background]#\#}"; seqs+=($'\033]11;#'"$hb"$'\007'); fi
if [ -n "${COL[foreground]:-}" ]; then hf="${COL[foreground]#\#}"; seqs+=($'\033]10;#'"$hf"$'\007'); fi
if [ -n "${COL[cursor-color]:-}" ]; then hc="${COL[cursor-color]#\#}"; seqs+=($'\033]12;#'"$hc"$'\007')
elif [ -n "${COL[cursor]:-}" ]; then hc="${COL[cursor]#\#}"; seqs+=($'\033]12;#'"$hc"$'\007'); fi

for tty in /dev/pts/*; do
  if [[ -c "$tty" && -w "$tty" ]]; then
    for s in "${seqs[@]}"; do send_to_tty "$tty" "$s"; done
  fi
done

if [ -t 1 ]; then for s in "${seqs[@]}"; do printf "%b" "$s"; done; fi

