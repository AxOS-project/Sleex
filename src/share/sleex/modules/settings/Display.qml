import qs.modules.common.widgets
import qs.modules.common
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Hyprland
import Sleex.Services
import "displaySettings" as DS

ContentPage {
    id: root

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

    forceWidth: true

    ContentSection {
        title: "Monitor arrangement"
        DS.DisplaySettings {
            Layout.fillWidth: true
            implicitHeight: 400
        }
    }

    ContentSection {
        title: "Brightness"
        StyledSlider {
            id: brightnessSlider
            value: root.brightnessMonitor?.brightness ?? 0.5
            tooltipContent: Math.round(value * 100) + "%"
            onMoved: Brightness.setMonitorBrightness(value)
        }
    }

    ContentSection {
        title: "Night light"

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
