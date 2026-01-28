#!/bin/bash

sleep 2

monitors=$(hyprctl monitors -j | jq -r '.[].name')

cd "$(dirname "$0")"

for mon in $monitors; do
    hyprctl dispatch focusmonitor "$mon"
    quickshell -p ./Notification.qml &
    sleep 1
done

for mon in $monitors; do
    hyprctl dispatch focusmonitor "$mon"
    break
done