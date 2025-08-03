import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        title: "Time"

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
        }
    }

    ContentSection {
        title: "Date"

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
                    "DD/MM/YYYY",
                    "MM/DD/YYYY",
                    "YYYY-MM-DD",
                    "DDDD, DD/MM/YYYY",
                    "DDDD, DD/MM",
                    "ddd, MMM dd "
                ]
                currentIndex: model.indexOf(
                    (() => {
                        switch (Config.options.time.dateFormat) {
                            case "dddd, dd/MM": return "DDDD, DD/MM";
                            case "dddd, dd/MM/yyyy": return "DDDD, DD/MM/YYYY";
                            case "mm/dd/yyyy": return "MM/DD/YYYY";
                            case "yyyy-mm-dd": return "YYYY-MM-DD";
                            case "ddd, MMM dd ": return "ddd, MMM dd ";
                            default: return "ddd, MMM dd";
                        }
                    })()
                )
                onCurrentIndexChanged: {
                    const valueMap = {
                        "DD/MM/YYYY": "dddd, dd/MM/yyyy",
                        "MM/DD/YYYY": "mm/dd/yyyy",
                        "YYYY-MM-DD": "yyyy-mm-dd",
                        "DDDD, DD/MM": "dddd, dd/MM",
                        "DDDD, DD/MM/YYYY": "dddd, dd/MM/yyyy",
                        "ddd, MMM dd ": "ddd, MMM dd "
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


    ContentSection {
        title: "Audio"
        ConfigSwitch {
            text: "Earbang protection"
            checked: Config.options.audio.protection.enable
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

    ContentSection {
        title: "Bar"

        ContentSubsection {
            title: "Workspaces"
            tooltip: "Tip: Hide icons and always show numbers for\nthe classic Sleex experience"

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: 'Show app icons'
                    onClicked: checked = !checked;
                    checked: Config.options.bar.workspaces.showAppIcons
                    onCheckedChanged: {
                        Config.options.bar.workspaces.showAppIcons = checked;
                    }
                }
                ConfigSwitch {
                    text: 'Always show numbers'
                    onClicked: checked = !checked;
                    checked: Config.options.bar.workspaces.alwaysShowNumbers
                    onCheckedChanged: {
                        Config.options.bar.workspaces.alwaysShowNumbers = checked;
                    }
                }
            }
            ConfigSpinBox {
                text: "Workspaces shown"
                value: Config.options.bar.workspaces.shown
                from: 1
                to: 30
                stepSize: 1
                onValueChanged: {
                    Config.options.bar.workspaces.shown = value;
                }
            }
            ConfigSpinBox {
                text: "Number show delay when pressing Super (ms)"
                value: Config.options.bar.workspaces.showNumberDelay
                from: 0
                to: 1000
                stepSize: 50
                onValueChanged: {
                    Config.options.bar.workspaces.showNumberDelay = value;
                }
            }
        }
    }

    ContentSection {
        title: "Dashboard"

        MaterialTextField {
            id: ghUsername
            Layout.fillWidth: true
            placeholderText: "Github username"
            text: Config.options.dashboard.ghUsername
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.dashboard.ghUsername = text;
            }
        }

        MaterialTextField {
            id: avatarPath
            Layout.fillWidth: true
            placeholderText: "Avatar path"
            text: Config.options.dashboard.avatarPath
            onTextChanged: {
                Config.options.dashboard.avatarPath = text;
            }
        }

        MaterialTextField {
            id: userDesc
            Layout.fillWidth: true
            placeholderText: "User description"
            text: Config.options.dashboard.userDesc
            onTextChanged: {
                Config.options.dashboard.userDesc = text;
            }
        }


    }

    ContentSection {
        title: "Battery"

        ConfigSwitch {
            text: "Enable battery notification sounds"
            checked: Config.options.battery.sound !== false
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
    }

    ContentSection {
        title: "Dock"

        ConfigRow {
            uniform: true

            ConfigSwitch {
                text: "Enabled"
                onClicked: checked = !checked;
                checked: Config.options.dock.enabled
                onCheckedChanged: {
                    Config.options.dock.enabled = checked;
                }
            }
            ConfigSpinBox {
                text: "Height"
                value: Config.options.dock.height
                stepSize: 5
                onValueChanged: {
                    Config.options.dock.height = value
                }
            }
        }

        ConfigRow {
            uniform: true
            ConfigSwitch {
                text: "Hover to reveal"
                onClicked: checked = !checked;
                checked: Config.options.dock.hoverToReveal
                onCheckedChanged: {
                    Config.options.dock.hoverToReveal = checked;
                }
            }
            ConfigSwitch {
                text: "Pinned on startup"
                onClicked: checked = !checked
                checked: Config.options.dock.pinnedOnStartup
                onCheckedChanged: {
                    Config.options.dock.pinnedOnStartup = checked;
                }
            }

        }

        ConfigSpinBox {
            text: "Hover region height"
            value: Config.options.dock.hoverRegionHeight
            onValueChanged: {
                Config.options.dock.hoverRegionHeight = value
            }
        }

    }
}