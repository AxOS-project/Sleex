#!/bin/bash

KBD=$(ls /sys/class/leds | grep -i kbd_backlight | head -n1)

if [ -n "$KBD" ]; then
   
    brightnessctl -sd "$KBD" set 0
fi
