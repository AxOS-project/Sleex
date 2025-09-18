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
                    { displayName: "No", value: 0 },
                    { displayName: "Yes", value: 1 },
                    { displayName: "Local only", value: 2 }
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

                StyledToolTip {
                    content: "The weather module uses your approximate location based on your local IP. It uses the https://wttr.in provider."
                }
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

        ContentSection {
            title: "DNS"


            MaterialTextField {
                id: customDNS
                Layout.fillWidth: true
                placeholderText: "DNS Server"
                text: Config.options.dashboard.customDNS
                wrapMode: TextEdit.Wrap

                onEditingFinished: {
                    // Save the value
                    Config.options.dashboard.customDNS = text

                    // Run the Python script
                    Quickshell.execDetached(["python", "/usr/share/sleex/scripts/set-dns.py"])

                }
            }

        }
}
