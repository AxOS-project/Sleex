import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true
    ContentSection {
        title: "Policies"
        ContentSubsectionLabel {
            text: "AI"
        }
        ConfigSelectionArray {
            currentValue: Config.options.policies.ai
            onSelected: newValue => {
                Config.options.policies.ai = newValue;
            }
            options: [
                {
                    displayName: "No",
                    value: 0
                },
                {
                    displayName: "Yes",
                    value: 1
                },
                {
                    displayName: "Local only",
                    value: 2
                }
            ]
        }
    }
    
    ContentSection {
        title: "Weather"
        ConfigSwitch {
            id: weatherSwitch
            text: "Enabled"
            checked: Config.options.dashboard.enableWeather
            onClicked: checked = !checked;
            onCheckedChanged: Config.options.dashboard.enableWeather = checked
            StyledToolTip { text: "View weather forecasts directly in your dashboard.\nIt uses the https://open-meteo.com provider." }
        }
        
        ConfigSwitch {
            id: autoLocationSwitch
            visible: weatherSwitch.checked
            text: "Automatic Location"
            checked: Config.options.dashboard.autoWeatherLocation ?? true
            onClicked: checked = !checked;
            onCheckedChanged: {
                Config.options.dashboard.autoWeatherLocation = checked;
                Weather.updateWeather();
            }
            StyledToolTip { text: "IP-based approximate location." }
        }
        
        MaterialTextField {
            id: weatherLocation
            visible: weatherSwitch.checked && !autoLocationSwitch.checked
            Layout.fillWidth: true
            placeholderText: "Weather Location"
            text: Config.options.dashboard.weatherLocation
            wrapMode: TextEdit.Wrap
            onEditingFinished: {
                Config.options.dashboard.weatherLocation = text;
            }
        }
    }
    
    Item {
        implicitHeight: 24
    }
}
