import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        title: "Shell style"

        ConfigSwitch {
            text: "Transparency"
            checked: Config.options.appearance.transparency
            onClicked: checked = !checked;
            StyledToolTip { text: "Enable the blur effect on the shell." }
            onCheckedChanged: Config.options.appearance.transparency = checked;
        }

        ConfigSpinBox {
            text: "Opacity"
            value: Config.options.appearance.opacity
            from: 0
            to: 100
            stepSize: 1
            onValueChanged: {
                Config.options.appearance.opacity = value;
            }
        }

    }

    ContentSection {
        title: "Bar"

        RowLayout {
            spacing: 10
            uniformCellSizes: true

            ConfigSwitch {
                text: "Show app name"
                checked: Config.options.bar.showTitle
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.showTitle = checked;
            }

            ConfigSwitch {
                text: "Show resources usage"
                checked: Config.options.bar.showRessources
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.showRessources = checked;
            }
        }

        RowLayout {
            spacing: 10
            uniformCellSizes: true

            ConfigSwitch {
                text: "Show Workspaces"
                checked: Config.options.bar.showWorkspaces
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.showWorkspaces = checked;
            }

            ConfigSwitch {
                text: "Show clock"
                checked: Config.options.bar.showClock
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.showClock = checked;
            }
        }

        RowLayout {
            spacing: 10
            uniformCellSizes: true

            ConfigSwitch {
                text: "Show system icons"
                checked: Config.options.bar.showTrayAndIcons
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.showTrayAndIcons = checked;
            }

            ConfigSwitch {
                text: "Enable bar background"
                checked: Config.options.bar.background
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.background = checked;
            }

        }

        ContentSubsection {
            title: "Workspaces"
            tooltip: "Tip: Hide icons for the\n classic Sleex experience"

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

        ConfigSpinBox {
            text: "Scale"
            value: Config.options.dashboard.dashboardScale * 100
            from: 0
            to: 200
            stepSize: 5
            onValueChanged: {
                Config.options.dashboard.dashboardScale = value / 100;
            }
        }

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

        ContentSubsection {
            title: "Optional features"
            tooltip: "Affects performances.\nWill make dashboard load slower"

            ConfigSwitch {
                text: "Todo list"
                checked: Config.options.dashboard.opt.enableTodo
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.dashboard.opt.enableTodo = checked;
            }
            ConfigSwitch {
                text: "Calendar tab"
                checked: Config.options.dashboard.opt.enableCalendar
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.dashboard.opt.enableCalendar = checked;
            }
            ConfigSwitch {
                text: "AI assistant"
                checked: Config.options.dashboard.opt.enableAIAssistant
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.dashboard.opt.enableAIAssistant = checked;
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


    ContentSection {
        title: "Background"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            ConfigRow {
                uniform: true

                ConfigSwitch {
                    text: "Show clock"
                    checked: Config.options.background.enableClock
                    onClicked: checked = !checked;
                    onCheckedChanged: Config.options.background.enableClock = checked;
                }

                ConfigSwitch {
                    text: "Fixed clock position"
                    checked: Config.options.background.fixedClockPosition
                    onClicked: checked = !checked;
                    onCheckedChanged: Config.options.background.fixedClockPosition = checked;
                }
            }

            ConfigRow {
                uniform: true

                ConfigSwitch {
                    text: "Show watermark"
                    checked: Config.options.background.showWatermark
                    onClicked: checked = !checked;
                    onCheckedChanged: Config.options.background.showWatermark = checked;
                }

                ConfigSwitch {
                    text: "Show quotes"
                    checked: Config.options.background.enableQuote
                    onClicked: checked = !checked
                    onCheckedChanged: {
                        Config.options.background.enableQuote = checked
                        Quotes.refresh();    
                    }
                }

            }

            ContentSubsection {
                title: "Clock mode"

                ConfigSelectionArray {
                    currentValue: Config.options.background.clockMode
                    configOptionName: "background.clockMode"
                    onSelected: (newValue) => {
                        Config.options.background.clockMode = newValue;
                    }
                    options: [
                        {"value": "dark", "displayName": "Dark"},
                        {"value": "light", "displayName": "Light"}
                    ]
                }
            }

            ContentSubsection {
                title: "Clock Font"

                StyledComboBox {
                    id: fontComboBox
                    model: Qt.fontFamilies()
                    currentIndex: model.indexOf(Config.options.background.clockFontFamily)

                    onCurrentIndexChanged: {
                        const selectedFont = model[currentIndex]
                        if (Config.options.background.clockFontFamily !== selectedFont) {
                            Config.options.background.clockFontFamily = selectedFont
                        }
                    }
                }
            }

            ContentSubsection {
                title: "Quote Source"
                tooltip: "The local quotes are stored in /usr/share/sleex/assets/quotes.json.\nThese quotes are made by the AxOS community and are tech related."

                ConfigSelectionArray {
                    currentValue: Config.options.background.quoteSource
                    configOptionName: "background.quoteSource"
                    onSelected: (newValue) => {
                        Config.options.background.quoteSource = newValue;
                        Quotes.refresh();
                    }
                    options: [
                        {"value": 1, "displayName": "Online"},
                        {"value": 0, "displayName": "Local"}
                    ]
                }
            }
        }
    }

    ContentSection {
        title: "Notifications"

        ConfigSelectionArray {
            currentValue: Config.options.notifications.position
            configOptionName: "notifications.position"
            onSelected: (newValue) => {
                Config.options.notifications.position = newValue;
            }
            options: [
                {"value": "top-left", "displayName": "Top Left"},
                {"value": "top-center", "displayName": "Top Center"},
                {"value": "top-right", "displayName": "Top Right"},
            ]
        }
    }

    ContentSection {
        title: "Lock Screen"

        ConfigSwitch {
            text: "Scrim background"
            checked: Config.options.lockscreen.enableScrim
            onClicked: checked = !checked;
            onCheckedChanged: Config.options.lockscreen.enableScrim = checked;
        }
    }

    ContentSection {
        title: "Calendar"

        ContentSubsection {
            title: "Advanced"
            tooltip: "Vdirsyncer is not configured by default.\nPlease refer to the documentation\n to set it up. Enable only after configuring it."
        }
        ConfigSwitch {
            text: "Use vdirsyncer"
            checked: Config.options.dashboard.calendar.useVdirsyncer
            onClicked: checked = !checked;
            onCheckedChanged: Config.options.dashboard.calendar.useVdirsyncer = checked;
        }

        ConfigSpinBox {
            text: "Sync interval (minutes)"
            value: Config.options.dashboard.calendar.syncInterval
            from: 1
            to: 1440 // 24 hours
            stepSize: 1
            onValueChanged: {
                Config.options.dashboard.calendar.syncInterval = value;
            }
        }
    }
}