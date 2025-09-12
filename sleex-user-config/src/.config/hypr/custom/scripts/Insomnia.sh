#!/bin/bash

# Get all connected monitors and check if any external monitor is connected
connected_monitors=$(hyprctl monitors -j)
external_monitor_connected=$(echo "$connected_monitors" | jq -r '.[] | select(.name != "eDP-1") | .name' | head -n1)

if [ -n "$external_monitor_connected" ]; then
    # External monitor is connected - toggle eDP-1 display
    is_enabled=$(echo "$connected_monitors" | jq -r '.[] | select(.name == "eDP-1") | .disabled')

    if [ "$is_enabled" = "false" ]; then
        # If display is enabled, disable it
        hyprctl keyword monitor "eDP-1,disable"
        brightnessctl -sd asus::kbd_backlight set 0
        python /usr/share/sleex/scripts/wayland-idle-inhibitor.py
    else
        # If display is disabled, enable it
        hyprctl keyword monitor "eDP-1,preferred,auto,1"
        brightnessctl -rd asus::kbd_backlight
        pkill wayland-idle
    fi
else
    # No external monitor detected - toggle DPMS instead
    dpms_status=$(echo "$connected_monitors" | jq -r '.[] | select(.name == "eDP-1") | .dpmsStatus')

    if [ "$dpms_status" = "true" ]; then
        # If DPMS is on, turn it off (wake display)
        hyprctl dispatch dpms off eDP-1
        brightnessctl -sd asus::kbd_backlight set 0
        python /usr/share/sleex/scripts/wayland-idle-inhibitor.py
    else
        # If DPMS is off, turn it on (sleep display)
        hyprctl dispatch dpms on eDP-1
        brightnessctl -rd asus::kbd_backlight
        pkill wayland-idle
    fi
fi
