#!/usr/bin/env bash
# record-script.sh — screen recording start/stop, tightly integrated with
# CaptureOverlay.qml. Called by the overlay's "Record" button (with
# --geometry/--record/audio flags) to start a recording, and either by the
# overlay's own startup check or by grimblast.sh (when it detects an active
# recording) to stop and save it — always with no extra flags in that case.
#
# Recorder choice is config-driven (Config.options.display.captureGPUrendering,
# once the GUI exists) rather than a fixed preference:
#   - captureGPUrendering = true  (default): gpu-screen-recorder for a
#     fullscreen selection, wf-recorder for a cropped one (GSR can't crop).
#   - captureGPUrendering = false: wf-recorder unconditionally, regardless
#     of geometry.
# Either way, if the desired recorder isn't installed, this falls back to
# whichever one is.

# Ensure pactl can connect to PipeWire/PulseAudio regardless of launch context
XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR
export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"

# ---------------------------------------------------------
# INLINE CACHE DIRECTORY SETUP (no external caching.sh)
# ---------------------------------------------------------
QS_CACHE_DIR="$HOME/.cache/quickshell"
CACHE_DIR="$QS_CACHE_DIR/recording"
mkdir -p "$CACHE_DIR"

# ---------------------------------------------------------
# CONFIG (Config.qml, via IPC)
#
# Each look-up is a separate `quickshell ipc call` subprocess, so fetches
# are deferred to the path that needs them: the stop path only reads
# SHOW_CAPTURED_NOTIFICATIONS; everything else is fetched in the start
# path below. Fetching everything up front would tax every stop press.
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

# ---------------------------------------------------------
# DEPENDENCY CHECK
# ---------------------------------------------------------
if ! command -v notify-send &> /dev/null; then
    echo "ERROR: notify-send is not installed. Cannot display missing dependencies."
    exit 1
fi

if ! command -v pactl &> /dev/null; then
    notify-send -u critical -a "Screen Recorder" "Missing Dependency" "pactl is required for audio routing. Please install it."
    exit 1
fi

# Parse arguments
RECORD_MODE=false
GEOMETRY=""
OUTPUT=""
TARGET=""
FULLSCREEN=false
DESK_VOL="1.0"
DESK_MUTE="false"
MIC_VOL="1.0"
MIC_MUTE="false"
MIC_DEVICE=""
PASSED_FPS=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --record) RECORD_MODE=true; shift ;;
        --geometry) GEOMETRY="$2"; shift 2 ;;
        --target) TARGET="$2"; shift 2 ;;
        --fullscreen) FULLSCREEN=true; shift ;;
        --desk-vol) DESK_VOL="$2"; shift 2 ;;
        --desk-mute) DESK_MUTE="$2"; shift 2 ;;
        --mic-vol) MIC_VOL="$2"; shift 2 ;;
        --mic-mute) MIC_MUTE="$2"; shift 2 ;;
        --mic-dev) MIC_DEVICE="$2"; shift 2 ;;
        --fps) PASSED_FPS="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [ "$TARGET" = "output" ] && command -v hyprctl &> /dev/null && command -v jq &> /dev/null; then
    OUTPUT=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name')
fi

# Auto-FPS detection lives in CaptureOverlay.qml's getRecordingFps() and is
# always passed in via --fps; this script never queries hyprctl for it.

# ---------------------------------------------------------
# SMART TOGGLE: STOP RECORDING & CLEANUP VIRTUAL AUDIO
# ---------------------------------------------------------
if [ -f "$CACHE_DIR/rec_pid" ]; then
    # PREVENT OVERLAPPING EXECUTIONS
    if [ -f "$CACHE_DIR/processing.lock" ]; then exit 0; fi
    touch "$CACHE_DIR/processing.lock"

    REC_PID=$(cat "$CACHE_DIR/rec_pid")
    FINAL_FILE=$(cat "$CACHE_DIR/final_file")

    # Only config value the stop path needs.
    SHOW_CAPTURED_NOTIFICATIONS=$(get_config "onGetShowCapturedNotifications" "true")

    # 1. SEND STOP SIGNAL TO THE RECORDER
    [ "$REC_PID" != "0" ] && kill -SIGINT "$REC_PID" 2>/dev/null

    # 2. WAIT FOR THE RECORDER TO CLOSE GRACEFULLY AND FINALIZE THE MP4
    timeout=120
    while kill -0 "$REC_PID" 2>/dev/null && [ $timeout -gt 0 ]; do
        sleep 0.1
        timeout=$((timeout - 1))
    done

    # FORCE KILL IF STUCK
    [ "$REC_PID" != "0" ] && kill -9 "$REC_PID" 2>/dev/null

    # 3. DESTROY PIPEWIRE VIRTUAL AUDIO CABLES
    if [ -f "$CACHE_DIR/pw_modules" ]; then
        while read -r mod_id; do
            [ -n "$mod_id" ] && pactl unload-module "$mod_id" 2>/dev/null
        done < "$CACHE_DIR/pw_modules"
        rm -f "$CACHE_DIR/pw_modules"
    fi

    # 4. SEND FINAL NOTIFICATION
    if [ -f "$FINAL_FILE" ]; then
        if [ "$SHOW_CAPTURED_NOTIFICATIONS" = "true" ]; then
            FINAL_DIR=$(dirname "$FINAL_FILE")
            (
                ACTION=$(notify-send -a "Screen Recorder" -i "$FINAL_FILE" -A "default=Open Folder" "⏺ Recording Saved" "File: $(basename "$FINAL_FILE")\nFolder: $FINAL_DIR")
                if [ "$ACTION" = "default" ]; then
                    if command -v nautilus &> /dev/null; then
                        nautilus "$FINAL_DIR"
                    else
                        xdg-open "$FINAL_DIR"
                    fi
                fi
            ) &
        fi
    else
        LOG_TAIL=$(tail -n 3 "$CACHE_DIR/recorder.log" 2>/dev/null)
        notify-send -a "Screen Recorder" "❌ Error" "Failed to save the video file.\n${LOG_TAIL:-Check $CACHE_DIR/recorder.log for details.}"
    fi

    # 5. INSTANT UI CLEANUP
    rm -f "$CACHE_DIR/processing.lock"
    rm -f "$CACHE_DIR/rec_pid" "$CACHE_DIR/final_file"
    exit 0
fi

# No active recording. Only proceed if explicitly asked to start one.
if [ "$RECORD_MODE" != true ]; then
    exit 0
fi

# ---------------------------------------------------------
# CONFIG FETCH (start path only)
# ---------------------------------------------------------
PREFER_GPU=$(get_config "onGetCaptureGPURendering" "true")
REC_FPS=$(get_config "onGetScreenRecordingFPS" "60")

# Override config FPS when --fps was passed (CaptureOverlay always does this).
if [ -n "$PASSED_FPS" ]; then
    REC_FPS="$PASSED_FPS"
fi

# When "Automatic Bitrate" is on, the slider is hidden and its stored value is ignored.
AUTO_BITRATE=$(get_config "onGetAutoBitrate" "true")
if [ "$AUTO_BITRATE" = "true" ]; then
    REC_BITRATE=""
else
    REC_BITRATE=$(get_config "onGetScreenRecordingBitrate" "8000")
fi

# Same reasoning for the save folder: when "Custom screen recording save
# location" is off, the stored path is ignored in favor of the XDG default.
RECORDING_SAVE_DIR_ENABLED=$(get_config "onGetRecordingSaveDirEnabled" "false")
if [ "$RECORDING_SAVE_DIR_ENABLED" = "true" ]; then
    RECORDING_SAVE_DIR=$(get_config "onGetRecordingSaveDir" "")
else
    RECORDING_SAVE_DIR=""
fi

RECORD_DIR="${RECORDING_SAVE_DIR:-${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings}"
mkdir -p "$RECORD_DIR"

# ---------------------------------------------------------
# RECORDER RESOLUTION
# ---------------------------------------------------------
if [ "$PREFER_GPU" = "true" ] && ! command -v gpu-screen-recorder &> /dev/null; then
    notify-send -u critical -a "Screen Recorder" "Missing dependency: gpu-screen-recorder" "GPU rendering is preferred in settings but gpu-screen-recorder isn't installed. Falling back to wf-recorder if available."
fi

# Resolve desired recorder from config, falling back to whichever is installed.
if [ "$PREFER_GPU" = "false" ]; then
    DESIRED_RECORDER="wf-recorder"
else
    DESIRED_RECORDER="gpu-screen-recorder"
fi

if [ "$DESIRED_RECORDER" = "gpu-screen-recorder" ] && command -v gpu-screen-recorder &> /dev/null; then
    RECORDER="gpu-screen-recorder"
elif command -v wf-recorder &> /dev/null; then
    RECORDER="wf-recorder"
elif command -v gpu-screen-recorder &> /dev/null; then
    RECORDER="gpu-screen-recorder"
else
    RECORDER=""
fi

if [ -z "$RECORDER" ]; then
    notify-send -u critical -a "Screen Recorder" "No Recorder Found" "Install gpu-screen-recorder (preferred) or wf-recorder to enable recording."
    exit 1
fi

# ---------------------------------------------------------
# CROPPED-REGION OVERRIDE
# ---------------------------------------------------------
IS_CROPPED=false
if [ -n "$GEOMETRY" ] && [ "$FULLSCREEN" != true ]; then
    IS_CROPPED=true
fi

if [ "$IS_CROPPED" = true ] && [ "$RECORDER" != "wf-recorder" ]; then
    if command -v wf-recorder &> /dev/null; then
        RECORDER="wf-recorder"
    else
        notify-send -u critical -a "Screen Recorder" "Cropped Recording Unavailable" "gpu-screen-recorder can't record a custom region — install wf-recorder for that. Recording the full monitor instead."
        GEOMETRY=""
    fi
fi

time=$(date +'%Y-%m-%d-%H%M%S')
VID_FILENAME="$RECORD_DIR/Recording_$time.mp4"

# Clear out any old module IDs and recorder log
echo -n "" > "$CACHE_DIR/pw_modules"
rm -f "$CACHE_DIR/recorder.log"

DESK_SINK=$(pactl get-default-sink 2>/dev/null)
[ -n "$DESK_SINK" ] && DESK_DEV="${DESK_SINK}.monitor" || DESK_DEV=""

[ -n "$MIC_DEVICE" ] && [ "$MIC_DEVICE" != "null" ] && MIC_DEV="$MIC_DEVICE" || MIC_DEV=$(pactl get-default-source 2>/dev/null)
MIC_DEV="${MIC_DEV:-default}"

DESK_ACTIVE=false
MIC_ACTIVE=false

# --- DESKTOP AUDIO VIRTUAL ROUTING ---
if [ "$DESK_MUTE" != "true" ] && [ -n "$DESK_DEV" ]; then
    D_SINK_ID=$(pactl load-module module-null-sink sink_name=qs_virt_desk sink_properties=device.description="QS_Virtual_Desk")
    D_LOOP_ID=$(pactl load-module module-loopback source="$DESK_DEV" sink=qs_virt_desk)

    D_VOL_INT=$(awk "BEGIN {print int(${DESK_VOL//,/.} * 65536)}")
    pactl set-sink-volume qs_virt_desk "$D_VOL_INT"

    echo "$D_SINK_ID" >> "$CACHE_DIR/pw_modules"
    echo "$D_LOOP_ID" >> "$CACHE_DIR/pw_modules"
    DESK_ACTIVE=true
fi

# --- MICROPHONE VIRTUAL ROUTING ---
if [ "$MIC_MUTE" != "true" ] && [ -n "$MIC_DEV" ]; then
    M_SINK_ID=$(pactl load-module module-null-sink sink_name=qs_virt_mic sink_properties=device.description="QS_Virtual_Mic")
    M_LOOP_ID=$(pactl load-module module-loopback source="$MIC_DEV" sink=qs_virt_mic)


    M_VOL_INT=$(awk "BEGIN {print int(${MIC_VOL//,/.} * 65536)}")
    pactl set-sink-volume qs_virt_mic "$M_VOL_INT"

    echo "$M_SINK_ID" >> "$CACHE_DIR/pw_modules"
    echo "$M_LOOP_ID" >> "$CACHE_DIR/pw_modules"
    MIC_ACTIVE=true
fi

if [ "$RECORDER" = "gpu-screen-recorder" ]; then
    AUDIO_MIX=""
    [ "$DESK_ACTIVE" = true ] && AUDIO_MIX="${AUDIO_MIX}qs_virt_desk.monitor|"
    [ "$MIC_ACTIVE" = true ] && AUDIO_MIX="${AUDIO_MIX}qs_virt_mic.monitor|"
    AUDIO_MIX=${AUDIO_MIX%|}

    MONITOR="$OUTPUT"
    if [ -z "$MONITOR" ] && command -v hyprctl &> /dev/null && command -v jq &> /dev/null; then
        MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name')
    fi

    GSR_ARGS=(-w "${MONITOR:-screen}" -c "mp4" -f "$REC_FPS" -ac "aac")
    [ -n "$REC_BITRATE" ] && GSR_ARGS+=(-bm cbr -q "$REC_BITRATE")
    [ -n "$AUDIO_MIX" ] && GSR_ARGS+=(-a "$AUDIO_MIX")

    gpu-screen-recorder "${GSR_ARGS[@]}" -o "$VID_FILENAME" > "$CACHE_DIR/recorder.log" 2>&1 &
    REC_PID=$!

    sleep 0.6
    if ! kill -0 $REC_PID 2>/dev/null; then
        echo "--- direct monitor capture failed, falling back to portal ---" >> "$CACHE_DIR/recorder.log"
        GSR_ARGS_PORTAL=(-w "portal" -c "mp4" -f "$REC_FPS" -ac "aac")
        [ -n "$REC_BITRATE" ] && GSR_ARGS_PORTAL+=(-bm cbr -q "$REC_BITRATE")
        [ -n "$AUDIO_MIX" ] && GSR_ARGS_PORTAL+=(-a "$AUDIO_MIX")
        gpu-screen-recorder "${GSR_ARGS_PORTAL[@]}" -o "$VID_FILENAME" >> "$CACHE_DIR/recorder.log" 2>&1 &
        REC_PID=$!
    fi
else
    AUDIO_SRC=""
    if [ "$DESK_ACTIVE" = true ] && [ "$MIC_ACTIVE" = true ]; then
        F_SINK_ID=$(pactl load-module module-null-sink sink_name=qs_virt_final sink_properties=device.description="QS_Virtual_Final")
        F_LOOP1_ID=$(pactl load-module module-loopback source=qs_virt_desk.monitor sink=qs_virt_final)
        F_LOOP2_ID=$(pactl load-module module-loopback source=qs_virt_mic.monitor sink=qs_virt_final)
        { echo "$F_SINK_ID"; echo "$F_LOOP1_ID"; echo "$F_LOOP2_ID"; } >> "$CACHE_DIR/pw_modules"
        AUDIO_SRC="qs_virt_final.monitor"
    elif [ "$DESK_ACTIVE" = true ]; then
        AUDIO_SRC="qs_virt_desk.monitor"
    elif [ "$MIC_ACTIVE" = true ]; then
        AUDIO_SRC="qs_virt_mic.monitor"
    fi

    WFR_ARGS=(--pixel-format yuv420p -F "scale=out_range=full" -f "$VID_FILENAME" -r "$REC_FPS")
    # REC_BITRATE is in kbps. wf-recorder has no dedicated --bitrate flag --
    # its "-b" is actually --bframes (max B-frames), a completely unrelated
    # setting, which is why bitrate never took effect no matter what was
    # passed to it. Bitrate has to go through the generic codec-param
    # passthrough (-p), using ffmpeg's own "b" (bit_rate) codec option, which
    # understands the "k" suffix natively.
    #
    # wf-recorder ALSO unconditionally sets its own default crf=20, and
    # libx264 always prefers CRF over bitrate when both are present -- so
    # setting "b" alone still gets silently overridden by CRF-mode quality
    # encoding. crf=-1 is ffmpeg's own sentinel for "no CRF", and is required
    # here to actually enable rate control.
    #
    # ABR alone ("b" without VBV limits) undershoots the set bitrate on
    # low-complexity scenes — a 50000k target can deliver as little as
    # 6-20 Mbps, which reads as "the slider is capped" even though the
    # encoder just isn't being forced to spend the bits. Adding maxrate +
    # bufsize switches libx264 to CBR (VBV) mode, which actually pins the
    # output bitrate to the slider's value.
    # Wf-recorder's source frames are full-range RGB (the compositor hands
    # them over unchanged), but the yuv420p conversion it does internally
    # uses swscale defaults — which assume limited-range input and lift
    # blacks to 16. Every video therefore comes out flat:
    #    source black 36 → 47, source white 238 → 220
    # "scale=out_range=full" keeps the mapping in full range, so colors are
    # bit-identical to the screen and the container is tagged color_range=pc.
    if [ -n "$REC_BITRATE" ]; then
        WFR_ARGS+=(-p "crf=-1" -p "b=${REC_BITRATE}k" -p "maxrate=${REC_BITRATE}k" -p "bufsize=${REC_BITRATE}k")
    fi
    if [ -n "$OUTPUT" ]; then
        WFR_ARGS+=(-o "$OUTPUT")
    elif [ -n "$GEOMETRY" ]; then
        WFR_ARGS+=(-g "$GEOMETRY")
    fi
    [ -n "$AUDIO_SRC" ] && WFR_ARGS+=(--audio="$AUDIO_SRC")

    wf-recorder "${WFR_ARGS[@]}" > "$CACHE_DIR/recorder.log" 2>&1 &
    REC_PID=$!
fi

echo "$REC_PID" > "$CACHE_DIR/rec_pid"
echo "$VID_FILENAME" > "$CACHE_DIR/final_file"

notify-send -a "Screen Recorder" "⏺ Recording Started ($RECORDER)" "Press your screenshot shortcut again to stop."
exit 0
