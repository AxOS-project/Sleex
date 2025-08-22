#!/usr/bin/env bash

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:=$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:=$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:=$HOME/.local/state}"
export CONFIG_DIR="/usr/share/sleex"
export CACHE_DIR="$XDG_CACHE_HOME/sleex"
export STATE_DIR="$XDG_STATE_HOME/sleex"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR # declared and assigned seperately to avoid masking return values (shellcheck: SC2155)

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

colornames=$(cat "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f1)
colorstrings=$(cat "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_term() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$CONFIG_DIR"/scripts/terminal/sequences.txt ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$STATE_DIR"/user/generated/terminal
  cp "$CONFIG_DIR"/scripts/terminal/sequences.txt "$STATE_DIR"/user/generated/terminal/sequences.txt
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$STATE_DIR"/user/generated/terminal/sequences.txt
  done

  sed -i "s/\$alpha/$term_alpha/g" "$STATE_DIR/user/generated/terminal/sequences.txt"

  for file in /dev/pts/*; do
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
      {
      cat "$STATE_DIR"/user/generated/terminal/sequences.txt >"$file"
      } & disown || true
    fi
  done
}

apply_other_term() {
  theme_generator="/usr/share/sleex/scripts/colors/term_gen_colors.sh"
  case "$TERMINAL" in
      foot*)
          ${theme_generator} foot
          ;;
      wezterm*)
          ${theme_generator} wezterm
          ;;
      kitty*)
          ${theme_generator} kitty
          ;;
      alacritty*)
          ${theme_generator} alacritty
          ;;
      ghostty*)
          ${theme_generator} ghostty
          ;;
      zellij*)
          ${theme_generator} zellij
          ;;
      *)
          echo "Unsupported Terminal: $TERMINAL"
          echo "Currently supported options: foot*, wezterm*, kitty*, alacritty*, ghostty*, zellij* "
          echo "Arguments inside of \"TERMINAL\" (e.g. \"wezterm start --always-new-process\") are allowed, because the script just matches the command names for specified terminals. This is done, so the user can still use this Variable for different purposes and does not need to worry about colorgen not working anymore."
          return 1
          ;;
  esac
}

apply_qt() {
  sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"          # generate kvantum theme
  python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py" # apply config colors
}

apply_qt &
apply_term &
apply_other_term &
