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

            ContentSubsectionLabel {
                text: "Weather"
            }
            ConfigSwitch {
                id: weatherSwitch
                text: "Enabled"
                checked: Config.options.dashboard.enableWeather
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.dashboard.enableWeather = checked
                StyledToolTip { text: "The weather module uses your approximate location based on your local IP. It uses the https://wttr.in provider." }
            }

            MaterialTextField {
                id: weatherLocation
                Layout.fillWidth: true
                placeholderText: "Weather Location"
                text: Config.options.dashboard.weatherLocation
                wrapMode: TextEdit.Wrap

                onEditingFinished: {
                    // Only replace spaces with dashes when the user is done typing
                    Config.options.dashboard.weatherLocation = text.replace(/ /g, "-");
                }
            }
        }
}
