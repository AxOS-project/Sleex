#!/bin/bash

# Read timeouts from Sleex settings JSON
SCREEN_BRIGHTNESS=$(jq -r '.timeout.screendim' ~/.sleex/settings.json)
BACKLIGHT=$(jq -r '.timeout.backlight' ~/.sleex/settings.json)
LOCK=$(jq -r '.timeout.lock' ~/.sleex/settings.json)
SCREEN_ACTIVITY=$(jq -r '.timeout.screenoff' ~/.sleex/settings.json)
SUSPEND=$(jq -r '.timeout.suspend' ~/.sleex/settings.json)

# Create a temporary hypridle config
cat <<EOF > /tmp/hypridle.conf
general {
    lock_cmd = qs -p /usr/share/sleex ipc call lock lock
    before_sleep_cmd = qs -p /usr/share/sleex ipc call lock lock    # lock before suspend.
    after_sleep_cmd = hyprctl dispatch dpms on  # to avoid having to press a key twice to turn on the display.
}

listener {
    timeout = $SCREEN_BRIGHTNESS              # Adjustable in Sleex settings.
    on-timeout = brightnessctl -s set 10      # set monitor backlight to minimum, avoid 0 on OLED monitor.
    on-resume = brightnessctl -r              # monitor backlight restore.
}

# turn off keyboard backlight if present (auto-detect device)
listener {
    timeout = $BACKLIGHT    # Adjustable in Sleex settings.
    on-timeout = KBD=$(ls /sys/class/leds | grep -i kbd_backlight | head -n1) && \
                 [ -n "$KBD" ] && brightnessctl -sd "$KBD" set 0
    on-resume  = KBD=$(ls /sys/class/leds | grep -i kbd_backlight | head -n1) && \
                 [ -n "$KBD" ] && brightnessctl -rd "$KBD"
}

listener {
    timeout = $LOCK                                            # Adjustable in Sleex settings.
    on-timeout = qs -p /usr/share/sleex ipc call lock lock     # lock screen when timeout has passed
}

listener {
    timeout = $SCREEN_ACTIVITY                                   # Adjustable in Sleex settings.
    on-timeout = hyprctl dispatch dpms off                       # screen off when timeout has passed
    on-resume = hyprctl dispatch dpms on && brightnessctl -r     # screen on when activity is detected after timeout has fired.
 }

listener {
    timeout = $SUSPEND                 # Adjustable in Sleex settings.
    on-timeout = systemctl suspend     # suspend pc
}
EOF

# Start hypridle with generated config
hypridle -c /tmp/hypridle.conf
