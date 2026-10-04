#!/usr/bin/env bash
# grimblast.sh — screenshot capture, QR scanning, grimblast-style instant
# targeting (active window / output), and the entry point that signals
# CaptureOverlay.qml (loaded persistently with the rest of the shell) to
# open for interactive selection, via `quickshell ipc call`.
#
# Recording is handled entirely by record-script.sh — this file never
# touches gpu-screen-recorder/wf-recorder directly, it only launches
# record-script.sh (from the QML) or defers to it when a recording toggle
# needs to be stopped from this script's own entry point.

XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR
export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# ---------------------------------------------------------
# CONFIG (Config.qml, via IPC — same reasoning as record-script.sh)
# ---------------------------------------------------------
SHELL_QML_PATH="/usr/share/sleex/shell.qml"

get_config() {
    local func="$1" default="$2"
    local val
    val=$(quickshell ipc -p "$SHELL_QML_PATH" call config "$func" 2>/dev/null)
    if [ -n "$val" ]; then
        echo "$val"
    else
        echo "$default"
    fi
}

# The screenshot-specific config values (compression, save dir, clipboard,
# notifications) are only relevant to Phase 1 (actual pixel capture) below,
# so they're fetched right before that block — each one is a separate
# `quickshell ipc call` subprocess, and the other paths don't need them.

# ---------------------------------------------------------
# INLINE CACHE DIRECTORY SETUP (no external caching.sh)
# ---------------------------------------------------------
QS_CACHE_DIR="$HOME/.cache/quickshell"
QS_STATE_DIR="$HOME/.local/state/quickshell"
QS_RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/quickshell"

QS_CACHE_SCREENSHOT="$QS_CACHE_DIR/screenshot"
QS_STATE_SCREENSHOT="$QS_STATE_DIR/screenshot"
QS_RUN_SCREENSHOT="$QS_RUN_DIR/screenshot"

# Recording lives in its own cache namespace, owned by record-script.sh, but
# this script still needs to *read* rec_pid to know whether to defer to it.
QS_CACHE_RECORDING="$QS_CACHE_DIR/recording"

mkdir -p "$QS_CACHE_SCREENSHOT" "$QS_STATE_SCREENSHOT" "$QS_RUN_SCREENSHOT"

# ---------------------------------------------------------
# DEPENDENCY CHECK
# ---------------------------------------------------------
if ! command -v notify-send &> /dev/null; then
    echo "ERROR: notify-send is not installed. Cannot display missing dependencies."
    exit 1
fi

# zbarimg is deliberately NOT in the required list here: it's only needed
# for the QR scanner feature, so instead of blocking every screenshot at
# startup when it's missing, the --scan-qr path checks for it on demand.
REQUIRED_CMDS=("grim" "swappy" "wl-copy" "pactl" "quickshell" "python3" "jq" "hyprctl")
MISSING_CMDS=()

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_CMDS+=("$cmd")
    fi
done

if [ ${#MISSING_CMDS[@]} -ne 0 ]; then
    notify-send -u critical -a "Screenshot System" "Missing Dependencies" "Cannot start. Please install:\n${MISSING_CMDS[*]}"
    exit 1
fi
# ---------------------------------------------------------

# Parse arguments
EDIT_MODE=false
FULL_MODE=false
SCAN_QR_MODE=false
INSTANT_RECORD=false
GEOMETRY=""
OUTPUT=""
TARGET=""
OUTPUT_FILE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --edit) EDIT_MODE=true; shift ;;
        --full) FULL_MODE=true; shift ;;
        --scan-qr) SCAN_QR_MODE=true; shift ;;
        --record) INSTANT_RECORD=true; shift ;;
        --geometry) GEOMETRY="$2"; shift 2 ;;
        --target) TARGET="$2"; shift 2 ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ---------------------------------------------------------
# INSTANT RECORD TOGGLE (bypasses the overlay entirely, regardless of
# whether it's otherwise enabled — a dedicated "quick record" shortcut
# for its own keybind, separate from the interactive selection flow)
# ---------------------------------------------------------
if [ "$INSTANT_RECORD" = true ]; then
    bash "$SCRIPT_DIR/record-script.sh" --fullscreen --record
    exit 0
fi

# ---------------------------------------------------------
# TARGET RESOLUTION (grimblast-style instant capture, no QML overlay)
# ---------------------------------------------------------
# --target active : capture just the focused window's geometry
# --target output : capture just the focused monitor
if [ "$TARGET" = "active" ]; then
    FOCUSED=$(hyprctl activewindow -j 2>/dev/null)
    GEOMETRY=$(echo "$FOCUSED" | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null)
elif [ "$TARGET" = "output" ]; then
    OUTPUT=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name')
    FULL_MODE=true
fi

# ---------------------------------------------------------
# INSTANT QR SCANNING EXECUTION
# ---------------------------------------------------------
if [ "$SCAN_QR_MODE" = true ]; then
    RES_FILE="$QS_RUN_SCREENSHOT/qr_result"
    rm -f "$RES_FILE"

    if ! command -v zbarimg &> /dev/null; then
        echo -e "0,0,0,0|||ERROR: zbarimg is not installed. Please install it." > "$RES_FILE"
        exit 1
    fi

    TMP_IMG="$QS_RUN_SCREENSHOT/qr_temp_$$.png"
    grim -g "$GEOMETRY" "$TMP_IMG"

    XML_OUT=$(zbarimg --xml -q "$TMP_IMG" 2>/dev/null)
    export XML_OUT

    if [ -n "$XML_OUT" ]; then
        python3 << 'EOF' > "$RES_FILE"
import os, re, sys
import xml.etree.ElementTree as ET

raw_xml = os.environ.get("XML_OUT", "")
if not raw_xml.strip():
    print("0,0,0,0|||ERROR: Empty output from zbarimg")
    sys.exit(0)

try:
    xml_clean = re.sub(r"\sxmlns=['\"][^'\"]+['\"]", '', raw_xml)
    tree = ET.fromstring(xml_clean)

    found_any = False
    for elem in tree.iter():
        if elem.tag.endswith('symbol'):
            found_any = True
            data_text = ''
            min_x, min_y, max_x, max_y = float('inf'), float('inf'), -float('inf'), -float('inf')

            for child in elem:
                if child.tag.endswith('data'):
                    data_text = child.text if child.text else ''
                elif child.tag.endswith('polygon'):
                    pts_str = child.get('points', '')
                    if pts_str:
                        pt_pairs = pts_str.replace('+', '').split(' ')
                        for pair in pt_pairs:
                            if ',' in pair:
                                try:
                                    x_str, y_str = pair.split(',')
                                    x, y = int(x_str), int(y_str)
                                    min_x = min(min_x, x)
                                    max_x = max(max_x, x)
                                    min_y = min(min_y, y)
                                    max_y = max(max_y, y)
                                except ValueError:
                                    pass

            if min_x == float('inf'): min_x, min_y, max_x, max_y = 0, 0, 0, 0
            w, h = max_x - min_x, max_y - min_y
            encoded = data_text.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '')
            print(f"{int(min_x)},{int(min_y)},{int(w)},{int(h)}|||{encoded}")

    if not found_any: print("0,0,0,0|||NOT_FOUND")
except Exception as e:
    print(f"0,0,0,0|||ERROR: XML Parse failure: {e}")
EOF
    else
        echo -e "0,0,0,0|||NOT_FOUND" > "$RES_FILE"
    fi

    rm -f "$TMP_IMG"
    exit 0
fi

# ---------------------------------------------------------
# PHASE 1: Screenshot Capture
# ---------------------------------------------------------
if [ "$FULL_MODE" = true ] || [ -n "$GEOMETRY" ]; then

    # grim has no real "quality" concept for PNG (lossless format) — the
    # closest analog is compression level 0-9 (0 = fastest/largest,
    # 9 = slowest/smallest, pixel content is identical either way).
    # When the "Screenshot Compression" switch is off, the slider is hidden
    # in the GUI and its stored value is ignored entirely in favor of this
    # fixed default, rather than silently applying whatever was last set.
    SCREENSHOT_COMPRESSION_ENABLED=$(get_config "onGetScreenshotCompressionEnabled" "false")
    if [ "$SCREENSHOT_COMPRESSION_ENABLED" = "true" ]; then
        SCREENSHOT_COMPRESSION=$(get_config "onGetScreenshotQuality" "6")
    else
        SCREENSHOT_COMPRESSION="6"
    fi

    # Same reasoning for the save folder: when "Adjustable screenshot save
    # location" is off, the folder field is hidden and ignored in favor of
    # the default XDG path, even if a custom path was previously configured.
    SCREENSHOT_SAVE_DIR_ENABLED=$(get_config "onGetScreenshotSaveDirEnabled" "false")
    if [ "$SCREENSHOT_SAVE_DIR_ENABLED" = "true" ]; then
        SCREENSHOT_SAVE_DIR=$(get_config "onGetScreenshotSaveDir" "")
    else
        SCREENSHOT_SAVE_DIR=""
    fi

    SHOW_CAPTURED_NOTIFICATIONS=$(get_config "onGetShowCapturedNotifications" "true")

    SAVE_DIR="${SCREENSHOT_SAVE_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots}"
    mkdir -p "$SAVE_DIR"

    time=$(date +'%Y-%m-%d-%H%M%S')
    FILENAME="$SAVE_DIR/Screenshot_$time.png"

    # Override with explicit output file if provided
    if [ -n "$OUTPUT_FILE" ]; then
        FILENAME="$OUTPUT_FILE"
    fi

    GRIM_ARGS=(-l "$SCREENSHOT_COMPRESSION")
    if [ -n "$OUTPUT" ]; then
        GRIM_ARGS+=(-o "$OUTPUT")
    elif [ -n "$GEOMETRY" ]; then
        GRIM_ARGS+=(-g "$GEOMETRY")
    fi
    GRIM_ARGS+=(-)

    # Freeze handling: when "Freeze display on capture" is enabled, the
    # overlay-open invocation already started hyprpicker -z, so the composited
    # output this script captures while it's still running is the exact frozen
    # frame the user saw in the overlay preview. The capture MUST happen
    # before that freeze is torn down — the QML avoids killing hyprpicker in
    # the capture path (see hideOverlay in CaptureOverlay.qml) precisely so
    # grim can grab the frozen frame. The freeze is only released here, once
    # grim has EOF'd.
    FREEZE_ON_CAPTURE=$(get_config "onGetFreezeOnCapture" "false")

    # Settle delay: second-layer guard against the overlay itself getting
    # baked into the screenshot. CaptureOverlay.qml already waits for the
    # compositor to unmap its surface before it ever invokes this script
    # (for --full/--target direct calls there's no overlay to wait on at
    # all), so this only needs to cover residual compositor-frame timing,
    # not a full settle delay of its own — kept short to avoid stacking
    # latency on top of the QML-side wait for every screenshot.
    sleep 0.05

    if [ "$EDIT_MODE" = true ]; then
        # Capture to a temp file first so the freeze can be released as
        # soon as grim EOFs — swappy's editor session must not run on a
        # frozen desktop. (swappy handles its own clipboard-copy-on-save
        # independently via wl-copy if installed — not controlled by
        # SCREENSHOT_COPY_CLIPBOARD.)
        EDIT_TMP="$QS_RUN_SCREENSHOT/edit_tmp_$$.png"
        grim "${GRIM_ARGS[@]}" > "$EDIT_TMP"

        # The frozen frame has been captured — release the freeze now, before
        # any editor or notification runs, so the desktop re-animates.
        if [ "$FREEZE_ON_CAPTURE" = "true" ]; then
            pkill -f hyprpicker 2>/dev/null
        fi

        swappy -f "$EDIT_TMP" -o "$FILENAME"
        rm -f "$EDIT_TMP"
    else
        # Clipboard copy is only relevant to the direct (non-editor) path.
        SCREENSHOT_COPY_CLIPBOARD=$(get_config "onGetScreenshotCopyToClipboard" "true")
        if [ "$SCREENSHOT_COPY_CLIPBOARD" = "true" ]; then
            grim "${GRIM_ARGS[@]}" | tee "$FILENAME" | wl-copy
        else
            grim "${GRIM_ARGS[@]}" > "$FILENAME"
        fi

        # The frozen frame has been captured — release the freeze now, before
        # any notification runs, so the desktop re-animates.
        if [ "$FREEZE_ON_CAPTURE" = "true" ]; then
            pkill -f hyprpicker 2>/dev/null
        fi
    fi

    if [ -s "$FILENAME" ]; then
        if [ "$SHOW_CAPTURED_NOTIFICATIONS" = "true" ]; then
            (
                ACTION=$(notify-send -a "Screenshot" -i "$FILENAME" -A "default=Open Folder" "Screenshot Saved" "File: $(basename "$FILENAME")\nFolder: $(dirname "$FILENAME")")
                if [ "$ACTION" = "default" ]; then
                    if command -v nautilus &> /dev/null; then
                        nautilus "$(dirname "$FILENAME")"
                    else
                        xdg-open "$(dirname "$FILENAME")"
                    fi
                fi
            ) &
        fi
    fi
    exit 0
fi

# ---------------------------------------------------------
# PHASE 2: UI Trigger (already loaded with the shell — just signal it)
# ---------------------------------------------------------
# Defer to record-script.sh's stop/save toggle if a recording is active, so
# pressing the same screenshot keybind still stops an in-progress recording
# instead of reopening the selection overlay.
if [ -f "$QS_CACHE_RECORDING/rec_pid" ]; then
    bash "$SCRIPT_DIR/record-script.sh"
    exit 0
fi

# The overlay is always available; --full/--target still bypass it explicitly.

# Freeze the display for the duration of the overlay, if enabled. The
# overlay's own closeOverlay() already unconditionally pkills hyprpicker
# on close (harmless no-op if it isn't running), so only the start side
# needs handling here.
FREEZE_ON_CAPTURE=$(get_config "onGetFreezeOnCapture" "false")
if [ "$FREEZE_ON_CAPTURE" = "true" ] && command -v hyprpicker &> /dev/null; then
    hyprpicker -r -z &
    disown
fi

if [ "$EDIT_MODE" = true ]; then
    quickshell ipc -p /usr/share/sleex/shell.qml call screenshot onOpenEdit
else
    quickshell ipc -p /usr/share/sleex/shell.qml call screenshot onOpen
fi
exit 0
