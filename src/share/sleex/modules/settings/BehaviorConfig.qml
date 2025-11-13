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
                ]
                currentIndex: model.indexOf(
                    (() => {
                        switch (Config.options.time.format) {
                            case "hh:mm": return "24h";
                            case "h:mm AP": return "12h AM/PM";
                            default: return "24h";
                        }
                    })()
                )
                onCurrentIndexChanged: {
                    const valueMap = {
                        "24h": "hh:mm",
                        "12h AM/PM": "h:mm AP",
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
        title: "Power"
        
        ContentSubsectionLabel {
        text: "Battery Alerts"
        }

        ConfigRow {
            visible: UPower.displayDevice.isLaptopBattery
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
                visible: UPower.displayDevice.isLaptopBattery
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
        text: "Timeout"
        }

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                text: "Illuminance"
                value: Config.options.timeout.illuminance / 1000
                from: 5
                to: 18000
                stepSize: 5
                onValueChanged: {
                    Config.options.timeout.illuminance = value * 1000;
                }
            }
            ConfigSpinBox {
                text: "System Lock"
                value: Config.options.timeout.lock / 1000
                from: 5
                to: 18000
                stepSize: 5
                onValueChanged: {
                    Config.options.timeout.lock = value * 1000;
                }
            }
        }

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                text: "Standby"
                value: Config.options.timeout.standby / 1000
                from: 5
                to: 18000
                stepSize: 5
                onValueChanged: {
                    Config.options.timeout.standby = value * 1000;
                }
            }
            
            ConfigSpinBox {
                text: "Suspension"
                value: Config.options.timeout.suspend / 1000
                from: 5
                to: 18000
                stepSize: 5
                onValueChanged: {
                    Config.options.timeout.suspend = value * 1000;
                }
            }
        }
        
        ConfigSwitch {
            id: root
            text: "Keep system awake"
            checked: Idle.inhibit

            onClicked: {
                checked = !checked
                Idle.toggleInhibit()
            }

            onCheckedChanged: {
                Idle.inhibit = checked
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
