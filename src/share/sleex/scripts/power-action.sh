#!/bin/sh
## Portable session power action: suspend, poweroff, reboot, hibernate.
##
## `loginctl suspend/poweroff/reboot/hibernate` are an elogind-only
## extension - real systemd's loginctl has never had those verbs, only
## systemctl does (confirmed against systemd's own src/login/loginctl.c).
## So neither systemctl alone nor loginctl alone is portable here.
##
## Uses systemctl when it's actually systemd (unchanged behavior there),
## otherwise calls login1's own D-Bus Manager methods directly via
## dbus-send - the one thing both systemd-logind and elogind actually
## implement identically.

action="$1"

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    exec systemctl "$action"
fi

case "$action" in
    suspend)   method=Suspend ;;
    poweroff)  method=PowerOff ;;
    reboot)    method=Reboot ;;
    hibernate) method=Hibernate ;;
    *)
        echo "power-action: unknown action '$action'" >&2
        exit 1
        ;;
esac

exec dbus-send --system --print-reply \
    --dest=org.freedesktop.login1 \
    /org/freedesktop/login1 \
    "org.freedesktop.login1.Manager.$method" \
    boolean:true
