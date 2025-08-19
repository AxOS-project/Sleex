import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        title: "Time and date"

        ColumnLayout {
            // Format
            ContentSubsectionLabel {
                text: "Time format"
            }
            StyledComboBox {
                id: timeFormatComboBox
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                model: [
                    "24h",
                    "12h AM/PM",
                    "24h alt",
                    "12h alt AM/PM"
                ]
                currentIndex: model.indexOf(
                    (() => {
                        switch (Config.options.time.format) {
                            case "hh:mm": return "24h";
                            case "h:mm AP": return "12h AM/PM";
                            case "HH:mm": return "24h alt";
                            case "h:mm ap alt": return "12h alt AM/PM";
                            default: return "24h";
                        }
                    })()
                )
                onCurrentIndexChanged: {
                    const valueMap = {
                        "24h": "hh:mm",
                        "12h AM/PM": "h:mm AP",
                        "24h alt": "hh:mm",
                        "12h alt AM/PM": "hh:mm"
                    }
                    const currentIndex = timeFormatComboBox.currentIndex
                    if (currentIndex === -1) return;
                    const selectedValue = valueMap[model[currentIndex]]
                    if (Config.options.time.format !== selectedValue) {
                        Config.options.time.format = selectedValue;
                    }
                }
            }

            ColumnLayout {
                // Format
                ContentSubsectionLabel {
                    text: "Date format"
                }
                StyledComboBox {
                    id: dateFormatComboBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    model: [
                        "ddd, MMM dd",
                        "DD/MM/YYYY",
                        "MM/DD/YYYY",
                        "YYYY-MM-DD",
                        "DDDD, DD/MM/YYYY",
                        "DDDD, DD/MM"
                    ]
                    currentIndex: model.indexOf(
                        (() => {
                            switch (Config.options.time.dateFormat) {
                                case "ddd, MMM dd": return "ddd, MMM dd";
                                case "dd/mm/yyyy": return "DD/MM/YYYY";
                                case "mm/dd/yyyy": return "MM/DD/YYYY";
                                case "yyyy-mm-dd": return "YYYY-MM-DD";
                                case "dddd, dd/mm/yyyy": return "DDDD, DD/MM/YYYY";
                                case "dddd, dd/mm": return "DDDD, DD/MM";
                                default: return "DDDD, DD/MM";
                            }
                        })()
                    )
                    onCurrentIndexChanged: {
                        const valueMap = {
                            "ddd, MMM dd": "ddd, MMM dd",
                            "DD/MM/YYYY": "dd/MM/yyyy",
                            "MM/DD/YYYY": "MM/dd/yyyy",
                            "YYYY-MM-DD": "yyyy-MM-dd",
                            "DDDD, DD/MM": "dddd, dd/MM",
                            "DDDD, DD/MM/YYYY": "dddd, dd/MM/yyyy"
                        }
                        const currentIndex = dateFormatComboBox.currentIndex
                        if (currentIndex === -1) return;
                        const selectedValue = valueMap[model[currentIndex]]
                        if (Config.options.time.dateFormat !== selectedValue) {
                            Config.options.time.dateFormat = selectedValue;
                        }
                    }
                }
            }

        }
    }

    ContentSection {
        title: "Audio"

        ConfigSwitch {
            text: "Earbang protection"
            checked: Config.options.audio.protection.enable
            onClicked: checked = !checked;
            onCheckedChanged: {
                Config.options.audio.protection.enable = checked;
            }
            StyledToolTip {
                content: "Prevents abrupt increments and restricts volume limit"
            }
        }
        ConfigSpinBox {
            text: "Earbang limit"
            value: Config.options.audio.protection.maxAllowed
            from: 0
            to: 100
            stepSize: 1
            onValueChanged: {
                Config.options.audio.protection.maxAllowed = value;
            }
            StyledToolTip {
                content: "Maximum volume level allowed by earbang protection"
            }
        }
    }

    ContentSection {
        title: "Battery"

        visible: UPower.displayDevice.isLaptopBattery

        ConfigSwitch {
            text: "Enable battery notification sounds"
            checked: Config.options.battery.sound
            onClicked: checked = !checked;
            onCheckedChanged: {
                Config.options.battery.sound = checked;
            }
        }
        ConfigRow {
            uniform: true
            ConfigSpinBox {
                text: "Low warning"
                value: Config.options.battery.low
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.low = value;
                }
            }
            ConfigSpinBox {
                text: "Critical warning"
                value: Config.options.battery.critical
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.critical = value;
                }
            }
        }
        ContentSubsectionLabel {
            text: "Power profile"
        }
        ConfigSelectionArray {
            currentValue: PowerProfiles.profile
            configOptionName: PowerProfiles.profile
            options: [
                {value: PowerProfile.Balanced, displayName: "Balanced"},
                {value: PowerProfile.Performance, displayName: "Performance"},
                {value: PowerProfile.PowerSaver, displayName: "Power Saver"}
            ]
            onSelected: (newValue) => {
                PowerProfiles.profile = newValue;
            }
        }
    }


    ContentSection {
        title: "AI"
        MaterialTextField {
            id: systemPromptField
            Layout.fillWidth: true
            placeholderText: "System prompt"
            text: Config.options.ai.systemPrompt
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.ai.systemPrompt = text;
            }
        }
    }
}
