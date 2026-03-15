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
                    Config.options.display.nightLightEnabled = checked
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

    Item {
        implicitHeight: 24
    }
}
