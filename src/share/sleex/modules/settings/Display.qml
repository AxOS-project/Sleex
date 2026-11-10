import SleexUiKit.Widgets
import qs.modules.common
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Hyprland
import Sleex.Services
import "displaySettings" as DS
import SleexUiKit.Appearance

ContentPage {
    id: root

    property int nlStartHour:   parseInt(Config.options.display.nightLightFrom ? Config.options.display.nightLightFrom.split(":")[0] : "20")
    property int nlStartMinute: parseInt(Config.options.display.nightLightFrom ? Config.options.display.nightLightFrom.split(":")[1] : "0")
    property int nlEndHour:     parseInt(Config.options.display.nightLightTo ? Config.options.display.nightLightTo.split(":")[0] : "7")
    property int nlEndMinute:   parseInt(Config.options.display.nightLightTo ? Config.options.display.nightLightTo.split(":")[1] : "0")

    property string nlEditingTarget: "start"

    function formatTime(hour, minute) {
        if (DateTime.is24Hour)
            return String(hour).padStart(2, '0') + ":" + String(minute).padStart(2, '0')
        return ((hour % 12) || 12) + ":" + String(minute).padStart(2, '0') + (hour >= 12 ? " PM" : " AM")
    }

    property string nlStartLabel: formatTime(nlStartHour, nlStartMinute)
    property string nlEndLabel:   formatTime(nlEndHour, nlEndMinute)

    ContentSection {
        title: qsTr("Displays & Arrangement")
        icon: "display_settings"

        DS.DisplaySettings {
            id: displaySettingsWidget
            Layout.fillWidth: true
        }
    }

    DS.MonitorControls {
        id: monitorControlsWidget
        Layout.fillWidth: true
        selectedMonitorName: displaySettingsWidget.selectedMonitorName
        pendingChanges: displaySettingsWidget.pendingChanges
    }

    ContentSection {
        title: qsTr("Brightness")
        icon: "brightness_medium"

        Repeater {
            model: Quickshell.screens

            delegate: ColumnLayout {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: (modelData.model && modelData.model.length > 0) ? modelData.model : modelData.name
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        text: "(" + modelData.name + ")"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                // Brightness Slider Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    StyledSlider {
                        id: bSlider
                        Layout.fillWidth: true
                        property var bMon: Brightness.getMonitorForScreen(modelData)
                        value: bMon ? bMon.brightness : 0.5
                        tooltipContent: Math.round(value * 100) + "%"
                        onMoved: {
                            if (bMon) bMon.setBrightness(value)
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        title: qsTr("Night Light")
        icon: "nightlight"

        ConfigSwitch {
            id: enableSwitch
            text: qsTr("Enable Night Light")
            checked: NightLight.active
            onClicked: {
                NightLight.toggle()
                Config.options.display.nightLightEnabled = NightLight.active
            }
        }

        ConfigSwitch {
            id: autoSwitch
            text: qsTr("Automatic Schedule")
            checked: Config.options.display.nightLightAuto
            onClicked: checked = !checked
            onCheckedChanged: {
                Config.options.display.nightLightAuto = checked
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: enableSwitch.checked || autoSwitch.checked

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: qsTr("Color Temperature")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledSlider {
                    id: nlSlider
                    Layout.fillWidth: true
                    from: 6500
                    to: 1000
                    value: Config.options.display.nightLightTemperature
                    tooltipContent: Math.round(value) + "K"
                    onMoved: Config.options.display.nightLightTemperature = value
                }
            }
        }

        // Schedule Controls (visible when auto schedule is checked)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: autoSwitch.checked

            StyledText {
                text: qsTr("Active Hours")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }

            RowLayout {
                spacing: 12

                RippleButton {
                    buttonRadius: Appearance.rounding.normal
                    height: 38
                    width: 130
                    colBackground: Appearance.colors.colLayer2
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: "schedule"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: root.nlStartLabel
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                        }
                    }
                    onClicked: {
                        root.nlEditingTarget = "start"
                        nlTimePicker.hour   = root.nlStartHour
                        nlTimePicker.minute = root.nlStartMinute
                        nlTimePickerPopup.open()
                    }
                }

                StyledText {
                    text: "→"
                    font.pixelSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colSubtext
                }

                RippleButton {
                    buttonRadius: Appearance.rounding.normal
                    height: 38
                    width: 130
                    colBackground: Appearance.colors.colLayer2
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: "schedule"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: root.nlEndLabel
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                        }
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
    }

    Item {
        implicitHeight: 24
    }

    // TimePicker Popup for Night Light schedule
    Popup {
        id: nlTimePickerPopup

        anchors.centerIn: Overlay.overlay

        width: 400
        height: 500
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        enter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 180
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.92
                    to: 1
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }

        exit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 140
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 1
                    to: 0.92
                    duration: 140
                    easing.type: Easing.InCubic
                }
            }
        }

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
