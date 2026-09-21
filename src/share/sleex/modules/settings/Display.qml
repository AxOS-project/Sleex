import SleexUiKit.Widgets
import qs.modules.common
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell.Hyprland
import Sleex.Services
import "displaySettings" as DS
import SleexUiKit.Appearance

ContentPage {
    id: root

    // The old UI kit had a per-section `fullWidth` opt-in for the page's
    // two-column masonry layout; the current SleexUiKit ContentPage has no
    // such support, so the capture sections (which were designed to span
    // the full page width) would get squeezed into half-width columns on
    // wide settings windows. Keeping the page in single-column mode makes
    // every section span the full width, matching the original design.
    forceSingleColumn: true

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)

    property int nlStartHour:   parseInt(Config.options.display.nightLightFrom?.split(":")[0] ?? "20")
    property int nlStartMinute: parseInt(Config.options.display.nightLightFrom?.split(":")[1] ?? "0")
    property int nlEndHour:     parseInt(Config.options.display.nightLightTo?.split(":")[0]   ?? "7")
    property int nlEndMinute:   parseInt(Config.options.display.nightLightTo?.split(":")[1]   ?? "0")

    property string nlEditingTarget: "start"

    // Helper — only recomputes when hour/minute args actually change
    function formatTime(hour, minute) {
        if (DateTime.is24Hour)
            return String(hour).padStart(2, '0') + ":" + String(minute).padStart(2, '0')
        return ((hour % 12) || 12) + ":" + String(minute).padStart(2, '0') + (hour >= 12 ? " PM" : " AM")
    }

    property string nlStartLabel: formatTime(nlStartHour, nlStartMinute)
    property string nlEndLabel:   formatTime(nlEndHour,   nlEndMinute)

    // forceWidth: true

    ContentSection {
        title: "Monitor arrangement"
        icon: "display_settings"

        DS.DisplaySettings {
            Layout.fillWidth: true
            implicitHeight: 400
        }
    }

    ContentSection {
        title: "Brightness"
        icon: "brightness_medium"

        StyledSlider {
            id: brightnessSlider
            value: root.brightnessMonitor?.brightness ?? 0.5
            tooltipContent: Math.round(value * 100) + "%"
            onMoved: Brightness.setMonitorBrightness(value)
        }
    }

    ContentSection {
        title: "Night light"
        icon: "nightlight"

        ConfigSwitch {
            id: enableSwitch
            text: "Enable"
            checked: NightLight.active
            onClicked: {
                NightLight.toggle()
                Config.options.display.nightLightEnabled = NightLight.active
            }
        }

        ConfigSwitch {
            id: autoSwitch
            text: "Automatic toggle"
            checked: Config.options.display.nightLightAuto
            onClicked: checked = !checked
            onCheckedChanged: {
                Config.options.display.nightLightAuto = checked
            }
        }

        Item { implicitHeight: 8 }

        StyledText {
            text: qsTr("Intensity")
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onSurfaceVariant
            visible: enableSwitch.checked || autoSwitch.checked
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        StyledSlider {
            id: nlSlider
            from: 6500
            to: 1000
            value: Config.options.display.nightLightTemperature
            tooltipContent: Math.round(value) + "K"
            visible: enableSwitch.checked || autoSwitch.checked
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            onMoved: Config.options.display.nightLightTemperature = value
        }

        Item { implicitHeight: 4; visible: autoSwitch.checked }

        StyledText {
            text: qsTr("Schedule")
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onSurfaceVariant
            visible: autoSwitch.checked
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        Item { implicitHeight: 4; visible: autoSwitch.checked }

        Row {
            spacing: 12
            visible: autoSwitch.checked
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            RippleButton {
                buttonRadius: Appearance.rounding.normal
                height: 36
                width: 120
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: root.nlStartLabel
                    color: Appearance.colors.colOnPrimary
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                }
                onClicked: {
                    root.nlEditingTarget = "start"
                    nlTimePicker.hour   = root.nlStartHour
                    nlTimePicker.minute = root.nlStartMinute
                    nlTimePickerPopup.open()
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "→"
                font.pixelSize: Appearance.font.pixelSize.larger
                color: Appearance.m3colors.m3onSurfaceVariant
            }

            RippleButton {
                buttonRadius: Appearance.rounding.normal
                height: 36
                width: 120
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: root.nlEndLabel
                    color: Appearance.colors.colOnPrimary
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                }
                onClicked: {
                    root.nlEditingTarget = "end"
                    nlTimePicker.hour   = root.nlEndHour
                    nlTimePicker.minute = root.nlEndMinute
                    nlTimePickerPopup.open()
                }
            }
        }
    }

    ContentSection {
        id: captureSection
        title: "Capture Settings"
        icon: "photo_camera"

        property bool gsrAvailable: true

        Process {
            id: gsrCheckProcess
            command: ["bash", "-c", "command -v gpu-screen-recorder >/dev/null 2>&1 && echo yes || echo no"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    captureSection.gsrAvailable = this.text.includes("yes")
                }
            }
        }

        ConfigSwitch {
            text: "Freeze display on capture"
            checked: Config.options.display.freezeOnCapture
            onClicked: checked = !checked
            StyledToolTip { text: "Holds the screen's current content in place for the duration of the capture overlay, for both screenshots and recordings." }
            onCheckedChanged: Config.options.display.freezeOnCapture = checked
        }

        Item { implicitHeight: 12 }

        ConfigSwitch {
            text: "Snap to windows on hover"
            checked: Config.options.display.snapToWindows
            onClicked: checked = !checked
            StyledToolTip { text: "While selecting a region, hovering over a window snaps the selection rectangle to that window's bounds." }
            onCheckedChanged: Config.options.display.snapToWindows = checked
        }

        Item { implicitHeight: 12 }

        ConfigSwitch {
            text: "Show captured notifications"
            checked: Config.options.display.showCapturedNotifications
            onClicked: checked = !checked
            StyledToolTip { text: "Shows a notification when a screenshot or recording finishes saving. Error notifications always show regardless of this setting." }
            onCheckedChanged: Config.options.display.showCapturedNotifications = checked
        }
        Item { implicitHeight: 16 }

        ContentSubsection {
            title: "Screenshots"

            ConfigSwitch {
                text: "Copy to Clipboard"
                checked: Config.options.display.screenshotCopyToClipboard
                onClicked: checked = !checked
                StyledToolTip { text: "When enabled, screenshots are copied to the clipboard in addition to being saved. When disabled, they're only saved to the chosen location." }
                onCheckedChanged: Config.options.display.screenshotCopyToClipboard = checked
            }

            Item { implicitHeight: 12 }

            ConfigSwitch {
                id: screenshotCompressionSwitch
                text: "Screenshot Compression"
                checked: Config.options.display.screenshotCompressionEnabled
                onClicked: checked = !checked
                StyledToolTip { text: "When disabled, a default compression level is used. When enabled, adjust it manually below. Screenshots are lossless PNG either way — this trades encode time for file size, not image quality." }
                onCheckedChanged: Config.options.display.screenshotCompressionEnabled = checked
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: screenshotCompressionSwitch.checked

                Item { implicitHeight: 8 }

                StyledSlider {
                    id: screenshotQualitySlider
                    from: 0
                    to: 9
                    value: Config.options.display.screenshotQuality
                    tooltipContent: Math.round(value)
                    onMoved: Config.options.display.screenshotQuality = Math.round(value)
                }
            }

            Item { implicitHeight: 12 }

            ConfigSwitch {
                id: screenshotSaveDirSwitch
                text: "Custom screenshot save location"
                checked: Config.options.display.screenshotSaveDirEnabled
                onClicked: checked = !checked
                StyledToolTip { text: "When disabled, screenshots save to the default location. When enabled, choose a custom folder below." }
                onCheckedChanged: Config.options.display.screenshotSaveDirEnabled = checked
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: screenshotSaveDirSwitch.checked

                Item { implicitHeight: 8 }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialTextField {
                        id: screenshotDirField
                        Layout.fillWidth: true
                        placeholderText: "Default (~/Pictures/Screenshots)"
                        text: Config.options.display.screenshotSaveDir
                        onEditingFinished: {
                            Config.options.display.screenshotSaveDir = text;
                        }
                    }

                    RippleButtonWithIcon {
                        materialIcon: "folder_open"
                        materialIconFill: false
                        mainText: "Browse"
                        onClicked: screenshotDirPickerDialog.open()
                    }
                }
            }
        }

        Item { implicitHeight: 16 }

        ContentSubsection {
            title: "Screen Recordings"

            // ----- Group: Hardware Acceleration -----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ConfigSwitch {
                    id: gpuRenderSwitch
                    text: "Hardware Acceleration"
                    checked: Config.options.display.captureGPUrendering
                    onClicked: {
                        if (!checked && !captureSection.gsrAvailable) {
                            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Screen Recorder",
                                "Missing dependency: gpu-screen-recorder", "Install gpu-screen-recorder to enable hardware acceleration."])
                            return
                        }
                        checked = !checked
                    }
                    StyledToolTip {
                        text: gpuRenderSwitch.checked
                            ? "Fullscreen recordings use the GPU encoder for best performance. A selected region always uses wf-recorder instead, since the GPU encoder can't crop to a custom area."
                            : "All recordings use wf-recorder, regardless of the selected region."
                    }
                    onCheckedChanged: Config.options.display.captureGPUrendering = checked
                }
            }

            Item { implicitHeight: 12 }

            // ----- Group: Automatic FPS -----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ConfigSwitch {
                    id: autoFpsSwitch
                    text: "Automatic FPS"
                    checked: Config.options.display.autoFps
                    onClicked: checked = !checked
                    StyledToolTip {
                        text: "When enabled, the recording frame rate will match your monitor’s native refresh rate. When disabled, you can set a custom rate below."
                    }
                    onCheckedChanged: Config.options.display.autoFps = checked
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !autoFpsSwitch.checked
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    StyledText {
                        text: qsTr("Recording frame rate")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors.m3onSurfaceVariant
                        Layout.fillWidth: true
                    }

                    StyledSlider {
                        id: fpsSlider
                        Layout.fillWidth: true
                        from: 15
                        to: 144
                        value: Config.options.display.screenRecordingFPS
                        tooltipContent: Math.round(value) + " fps"
                        onMoved: Config.options.display.screenRecordingFPS = Math.round(value)
                    }
                }
            }

            Item { implicitHeight: 12 }

            // ----- Group: Automatic Bitrate -----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ConfigSwitch {
                    id: autoBitrateSwitch
                    text: "Automatic Bitrate"
                    checked: Config.options.display.autoBitrate
                    onClicked: checked = !checked
                    StyledToolTip { text: "When enabled, the recorder automatically picks the optimal bitrate. When disabled, set it manually below." }
                    onCheckedChanged: Config.options.display.autoBitrate = checked
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !autoBitrateSwitch.checked
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    StyledText {
                        text: qsTr("Recording bitrate")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors.m3onSurfaceVariant
                        Layout.fillWidth: true
                    }

                    StyledSlider {
                        id: bitrateSlider
                        Layout.fillWidth: true
                        from: 500
                        to: 50000
                        value: Config.options.display.screenRecordingBitrate
                        tooltipContent: Math.round(value) + " kbps"
                        onMoved: Config.options.display.screenRecordingBitrate = Math.round(value)
                    }
                }
            }

            Item { implicitHeight: 12 }

            // ----- Group: Custom save location (recordings) -----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ConfigSwitch {
                    id: recordingSaveDirSwitch
                    text: "Custom screen recording save location"
                    checked: Config.options.display.recordingSaveDirEnabled
                    onClicked: checked = !checked
                    StyledToolTip { text: "When disabled, recordings save to the default location. When enabled, choose a custom folder below." }
                    onCheckedChanged: Config.options.display.recordingSaveDirEnabled = checked
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: recordingSaveDirSwitch.checked
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        MaterialTextField {
                            id: recordingDirField
                            Layout.fillWidth: true
                            placeholderText: "Default (~/Videos/Recordings)"
                            text: Config.options.display.recordingSaveDir
                            onEditingFinished: {
                                Config.options.display.recordingSaveDir = text;
                            }
                        }

                        RippleButtonWithIcon {
                            materialIcon: "folder_open"
                            materialIconFill: false
                            mainText: "Browse"
                            onClicked: recordingDirPickerDialog.open()
                        }
                    }
                }
            }
        }
    }

    FolderDialog {
        id: screenshotDirPickerDialog
        title: "Choose screenshot save folder"
        onAccepted: {
            Config.options.display.screenshotSaveDir = selectedFolder.toString().replace("file://", "")
            screenshotDirField.text = Config.options.display.screenshotSaveDir
        }
    }

    FolderDialog {
        id: recordingDirPickerDialog
        title: "Choose recording save folder"
        onAccepted: {
            Config.options.display.recordingSaveDir = selectedFolder.toString().replace("file://", "")
            recordingDirField.text = Config.options.display.recordingSaveDir
        }
    }

    Item {
        implicitHeight: 24
    }

    Popup {
        id: nlTimePickerPopup

        anchors.centerIn: Overlay.overlay

        width: 400
        height: 500
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Appearance.rounding.large
            color: Appearance.m3colors.m3background
        }

        contentItem: Item {
            anchors.fill: parent

            StyledText {
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.nlEditingTarget === "start"
                    ? qsTr("Night light start time")
                    : qsTr("Night light end time")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: Appearance.m3colors.m3onBackground
                horizontalAlignment: Text.AlignHCenter
            }

            TimePicker {
                id: nlTimePicker
                anchors.centerIn: parent
                is24h: DateTime.is24Hour
                hour: 20
                minute: 0
            }

            RippleButton {
                buttonRadius: Appearance.rounding.normal
                height: 40
                width: 110
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                colBackground: Appearance.m3colors.m3surfaceVariant
                colBackgroundHover: Appearance.m3colors.m3surfaceVariant
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Cancel")
                    color: Appearance.m3colors.m3onSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                }
                onClicked: nlTimePickerPopup.close()
            }

            RippleButton {
                buttonRadius: Appearance.rounding.normal
                height: 40
                width: 110
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Done")
                    color: Appearance.colors.colOnPrimary
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                }
                onClicked: {
                    if (root.nlEditingTarget === "start") {
                        root.nlStartHour   = nlTimePicker.hour
                        root.nlStartMinute = nlTimePicker.minute
                        Config.options.display.nightLightFrom =
                            String(nlTimePicker.hour).padStart(2, '0') + ":" + String(nlTimePicker.minute).padStart(2, '0')
                    } else {
                        root.nlEndHour   = nlTimePicker.hour
                        root.nlEndMinute = nlTimePicker.minute
                        Config.options.display.nightLightTo =
                            String(nlTimePicker.hour).padStart(2, '0') + ":" + String(nlTimePicker.minute).padStart(2, '0')
                    }
                    nlTimePickerPopup.close()
                }
            }
        }
    }
}
