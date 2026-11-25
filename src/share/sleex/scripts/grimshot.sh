#!/bin/sh

default_extention="png"
directory="$HOME/Pictures/Screenshots"
mkdir -p "$directory"

copy_only() {
    name="$(date +"%d-%m-%Y_%H:%M:%S").$default_extention"
    output="/tmp/$name"

    grim "$output"
    wl-copy < "$output"

    notify-send "Grimshot" "Screenshot has been made using:\n<b>Copy only mode</b>"
    exit 0
}

normalScreenshot() {
    output="$directory/$name"

    sleep 0.7
    grim "$output"
    wl-copy < "$output"

    notify-send "Grimshot" "Screenshot <i>$name</i> has been made and copied to clipboard"
}

if [ "$1" = "--copy_only" ]; then
    copy_only
fi

today_default="$(date +"%d-%m-%Y_%H:%M:%S").$default_extention"
choice=$(printf "%s\nCustom name\nCopy only" "$today_default" | fuzzel --dmenu -p "Grimshot: ")

case "$choice" in
    "$today_default") name="$today_default" ;;
    "Custom name") name="$(fuzzel --dmenu -p "Screenshot name: ").$default_extention" ;;
    "Copy only") sleep 0.7 && copy_only ;;
    *) exit 0 ;;
esac

normalScreenshot
