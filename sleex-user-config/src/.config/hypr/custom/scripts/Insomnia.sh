#!/usr/bin/env bash
set -euo pipefail

# toggle-display-mode.sh
# - Activates: keyboard backlight -> 0, start idle-inhibitor, then:
#     * if external monitor present: disable eDP-1 and run a watcher which will re-enable eDP-1 if external monitor disappears
#     * if no external monitor: toggle DPMS for eDP-1
# - Deactivates: restore backlight, stop inhibitor, re-enable eDP-1, stop watcher
#
# Files used:
#   /tmp/wayland-idle.pid              -> PID of the idle-inhibitor process (mode ON)
#   /tmp/edp-watcher.pid               -> PID of the background watcher (only when eDP-1 disabled)
#   /tmp/kbd_backlight_saved_value     -> saved keyboard backlight value (to restore)
#
# Adjust EINK and KBD_DEVICE to match your hardware if needed.

EINK="eDP-1" # Change this to the internal display if not eDP-1
INHIBITOR_SCRIPT="/usr/share/sleex/scripts/wayland-idle-inhibitor.py"
KBD_DEVICE="asus::kbd_backlight" #Change this to the keyboard backlight you wish to toggle
INHIBITOR_PIDFILE="/tmp/wayland-idle.pid"
WATCHER_PIDFILE="/tmp/edp-watcher.pid"
BL_SAVE="/tmp/kbd_backlight_saved_value"

# helpers
command_exists() { command -v "$1" >/dev/null 2>&1; }

for cmd in hyprctl jq brightnessctl python pkill nohup; do
  if ! command_exists "$cmd"; then
    echo "Required command not found: $cmd" >&2
    exit 2
  fi
done

json_monitors() {
  hyprctl monitors -j 2>/dev/null || echo "[]"
}

get_external_monitor_name() {
  json_monitors | jq -r --arg edp "$EINK" '[.[] | select(.name != $edp) | .name] | .[0] // ""'
}

get_edp_disabled() {
  # returns "true" or "false" or empty
  json_monitors | jq -r --arg edp "$EINK" '(.[] | select(.name==$edp) | .disabled) // ""'
}

get_edp_dpms_status() {
  json_monitors | jq -r --arg edp "$EINK" '(.[] | select(.name==$edp) | .dpmsStatus) // ""'
}

save_kbd_brightness() {
  if val=$(brightnessctl -d "$KBD_DEVICE" g 2>/dev/null || true); then
    printf '%s' "$val" > "$BL_SAVE"
  else
    rm -f "$BL_SAVE" 2>/dev/null || true
  fi
}

restore_kbd_brightness() {
  if [ -f "$BL_SAVE" ]; then
    val=$(cat "$BL_SAVE")
    brightnessctl -d "$KBD_DEVICE" set "$val" 2>/dev/null || brightnessctl -rd "$KBD_DEVICE" 2>/dev/null || true
    rm -f "$BL_SAVE" || true
  else
    # fallback restore
    brightnessctl -rd "$KBD_DEVICE" 2>/dev/null || true
  fi
}

start_inhibitor() {
  # start and save pid
  if [ -f "$INHIBITOR_SCRIPT" ]; then
    nohup python "$INHIBITOR_SCRIPT" >/dev/null 2>&1 &
    echo $! > "$INHIBITOR_PIDFILE"
  else
    echo "Inhibitor script not found at $INHIBITOR_SCRIPT" >&2
  fi
}

stop_inhibitor() {
  if [ -f "$INHIBITOR_PIDFILE" ]; then
    pid=$(cat "$INHIBITOR_PIDFILE" 2>/dev/null || true)
    if [ -n "$pid" ] && kill "$pid" 2>/dev/null; then
      :
    fi
    rm -f "$INHIBITOR_PIDFILE" || true
  fi
  # best-effort fallback
  pkill -f wayland-idle || true
}

start_watcher() {
  # Only start watcher if not already running
  if [ -f "$WATCHER_PIDFILE" ]; then
    pid=$(cat "$WATCHER_PIDFILE" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      return 0
    else
      rm -f "$WATCHER_PIDFILE" || true
    fi
  fi

  # watcher checks hyprctl every 1s; if no external monitor -> re-enable eDP and stop mode
  nohup bash -c '
    WATCH_SLEEP=1
    EINK="'"$EINK"'"
    INHIBITOR_PIDFILE="'"$INHIBITOR_PIDFILE"'"
    WATCHER_PIDFILE="'"$WATCHER_PIDFILE"'"
    BL_SAVE="'"$BL_SAVE"'"
    KBD_DEVICE="'"$KBD_DEVICE"'"

    while true; do
      MONS=$(hyprctl monitors -j 2>/dev/null || echo "[]")
      # any external monitors?
      EXTERNAL=$(echo "$MONS" | jq -r --arg edp "$EINK" "[.[] | select(.name != \$edp) | .name] | length")
      if [ "$EXTERNAL" = "0" ]; then
        # re-enable eDP-1 (if disabled), restore backlight, stop inhibitor, remove pidfiles and exit
        hyprctl keyword monitor "'"$EINK"',preferred,auto,1" >/dev/null 2>&1 || true
        if [ -f "$BL_SAVE" ]; then
          val=$(cat "$BL_SAVE")
          brightnessctl -d "$KBD_DEVICE" set "$val" 2>/dev/null || brightnessctl -rd "$KBD_DEVICE" 2>/dev/null || true
          rm -f "$BL_SAVE" || true
        else
          brightnessctl -rd "$KBD_DEVICE" 2>/dev/null || true
        fi

        # stop inhibitor
        if [ -f "$INHIBITOR_PIDFILE" ]; then
          pid=$(cat "$INHIBITOR_PIDFILE" 2>/dev/null || true)
          if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
          fi
          rm -f "$INHIBITOR_PIDFILE" || true
        fi
        pkill -f wayland-idle || true

        # cleanup watcher pid and exit
        [ -f "$WATCHER_PIDFILE" ] && rm -f "$WATCHER_PIDFILE" || true
        exit 0
      fi
      sleep "$WATCH_SLEEP"
    done
  ' >/dev/null 2>&1 &

  echo $! > "$WATCHER_PIDFILE"
}

stop_watcher() {
  if [ -f "$WATCHER_PIDFILE" ]; then
    pid=$(cat "$WATCHER_PIDFILE" 2>/dev/null || true)
    if [ -n "$pid" ] && kill "$pid" 2>/dev/null; then
      :
    fi
    rm -f "$WATCHER_PIDFILE" || true
  fi
}

activate_mode() {
  # save and then turn kbd backlight to 0
  save_kbd_brightness
  brightnessctl -d "$KBD_DEVICE" set 0 2>/dev/null || true

  start_inhibitor

  external=$(get_external_monitor_name)
  if [ -n "$external" ]; then
    echo "External monitor detected ($external) — disabling $EINK."
    hyprctl keyword monitor "$EINK,disable" || echo "Failed to disable $EINK" >&2
    # start watcher to re-enable eDP if external disappears
    start_watcher
  else
    # No external -> toggle DPMS for eDP-1
    raw_dpms=$(get_edp_dpms_status)
    dpms=$(printf "%s" "$raw_dpms" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n')
    if [ "$dpms" = "true" ] || [ "$dpms" = "on" ] || [ "$dpms" = "enabled" ] || [ "$dpms" = "1" ]; then
      echo "DPMS currently ON for $EINK -> turning DPMS OFF (wake)."
      hyprctl dispatch dpms off "$EINK" || true
    else
      echo "DPMS currently OFF for $EINK -> turning DPMS ON (sleep)."
      hyprctl dispatch dpms on "$EINK" || true
    fi
  fi
}

deactivate_mode() {
  # Stop watcher first (if any)
  stop_watcher

  # Ensure eDP enabled
  hyprctl keyword monitor "$EINK,preferred,auto,1" || true

  # Put DPMS ON to sleep the display when no external connected (we do this best-effort)
  # (We choose to put DPMS ON so the screen is consistent with 'off' mode.)
  hyprctl dispatch dpms on "$EINK" || true

  # restore kbd brightness
  restore_kbd_brightness

  # stop inhibitor
  stop_inhibitor
}

# Determine current mode by checking inhibitor pidfile (simple state)
if [ -f "$INHIBITOR_PIDFILE" ]; then
  # If pid exists but process dead -> clean and treat as off
  pid=$(cat "$INHIBITOR_PIDFILE" 2>/dev/null || true)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    # active -> deactivate
    deactivate_mode
    exit 0
  else
    # stale pidfile
    rm -f "$INHIBITOR_PIDFILE" || true
    # also clean stale watcher if present and process dead
    if [ -f "$WATCHER_PIDFILE" ]; then
      wpid=$(cat "$WATCHER_PIDFILE" 2>/dev/null || true)
      if [ -n "$wpid" ] && kill -0 "$wpid" 2>/dev/null; then
        :
      else
        rm -f "$WATCHER_PIDFILE" || true
      fi
    fi
    # treat as OFF (fallthrough to activation)
  fi
fi

# If we reach here -> mode is OFF -> activate
activate_mode
exit 0
