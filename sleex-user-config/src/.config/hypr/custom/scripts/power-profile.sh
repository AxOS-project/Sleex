#!/usr/bin/env bash

# Array of power profiles in the order they should cycle
profiles=("performance" "balanced" "power-saver")
icons=("cpu" "preferences-system-power" "battery-low")
#Modify the values to what you want the notification to show
friendly_names=("Turbo Mode" "Balanced Mode" "Eco Mode")

# Get current profile
cur=$(powerprofilesctl get)

# Find current profile index
idx=-1
for i in "${!profiles[@]}"; do
  if [[ "${profiles[$i]}" == "$cur" ]]; then
    idx=$i
    break
  fi
done

# If current profile not recognized, default to balanced
if [[ $idx -eq -1 ]]; then
  idx=1  # balanced
fi

# Calculate next profile index
next=$(( (idx + 1) % ${#profiles[@]} ))
new_profile="${profiles[$next]}"

# Apply the new profile
if powerprofilesctl set "$new_profile"; then
  # Send notification with icon
  notify-send -i "${icons[$next]}" "${friendly_names[$next]}"
else
  notify-send -i "dialog-error" "Failed to set power profile"
fi

