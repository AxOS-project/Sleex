import qs.modules.common.widgets
import qs.services
import Quickshell
import Quickshell.Hyprland
import "displaySettings" as DS

ContentPage {
    id: root
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)

    forceWidth: true

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

        ContentSubsectionLabel {
            text: "This is not finished yet."
        }
        
        ConfigRow {

            ConfigSwitch {
                text: "Enable"
                checked: false
                onClicked: checked = !checked;
                onCheckedChanged: checked = checked;
            }
            ConfigSwitch {
                text: "Automatic toggle"
                checked: false
                onClicked: checked = !checked
                onCheckedChanged: checked = checked;
            }
        }

        

        ContentSubsectionLabel {
            text: "Night light temperature"
        }

        StyledSlider {
            id: nlSlider
            from: 6500
            to: 1000
            value: 5500
            tooltipContent: Math.round(value) + "K"
            onValueChanged: {
            }
        }
    }

}