import qs.modules.common.widgets
import qs.modules.common
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Hyprland
import "displaySettings" as DS

ContentPage {
    id: root
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)

    forceWidth: true

    Rectangle {
        Layout.fillWidth: true
        height: warnChildren.height + 40
        color: "#40FF9800"
        radius: 6

        RowLayout {
            id: warnChildren
            anchors.fill: parent
            anchors.margins: 10

            Label {
                text: "🚧"
                font.pixelSize: 16 // Slightly smaller icon
                Layout.alignment: Qt.AlignVCenter
                rightPadding: 6
            }

            Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: "<b>WORK IN PROGRESS:</b> This module is incomplete. Use at your own risk.</code>"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                color: "white"
            }
        }
    }


    ContentSection {
        title: "Monitors placement"

        ContentSubsectionLabel {
            text: "This is not finished yet."
        }

        DS.DisplaySettings {
            id: displaySettings
            implicitHeight: 300
        }
    }

    ContentSection {
        title: "brightness"

        StyledSlider {
            id: brightnessSlider
            value: root.brightnessMonitor?.brightness ?? 0.5
            tooltipContent: Math.round(value * 100) + "%"
            onValueChanged: {
                Brightness.setMonitorBrightness(value)
            }
        }
    }

    ContentSection {
        title: "Night light"
        
        ConfigRow {

            ConfigSwitch {
                text: "Enable"
                checked: NightLight.active
                onClicked: checked = !checked;
                onCheckedChanged: {
                    NightLight.toggle()
                }
            }
            ConfigSwitch {
                id: autoSwitch
                text: "Automatic toggle"
                checked: Config.options.display.nightLightAuto
                onClicked: checked = !checked;

                onCheckedChanged: {
                    Config.options.display.nightLightAuto = checked
                }
            }
        }

        StyledSlider {
            id: nlSlider
            from: 6500
            to: 1000
            value: Config.options.display.nightLightTemperature
            tooltipContent: Math.round(value) + "K"

            onValueChanged: {
                Config.options.display.nightLightTemperature = value
            }
        }
    }
}