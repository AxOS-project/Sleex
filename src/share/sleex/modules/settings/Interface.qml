import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    // forceWidth: true

    property string _selectedFaceImage: ""
    readonly property var dashboardAnimationKeys: ["left", "right", "up", "down"]

    FileDialog {
        id: sddmFaceDialog
        title: qsTr("Select profile picture")
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.bmp *.webp)"]
        onAccepted: {
            _selectedFaceImage = selectedFile.toString().replace("file://", "")
            copyProcess.command = ["bash", "-c",
                "pkexec cp \"" + _selectedFaceImage + "\" \"/usr/share/sddm/faces/$(id -un).face.icon\""
            ]
            copyProcess.running = true
        }
    }

    Process {
        id: copyProcess
        running: false
    }

    Process {
        id: initFaceProcess
        command: ["bash", "-c", "f=\"/usr/share/sddm/faces/$(id -un).face.icon\"; [ -f \"$f\" ] && echo \"$f\" || echo \"\""]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() !== "") {
                    _selectedFaceImage = line.trim()
                }
            }
        }
    }

    Component.onCompleted: initFaceProcess.running = true

    Process {
        id: removeProcess
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                _selectedFaceImage = ""
            }
        }
    }

    FileDialog {
        id: avatarPickerDialog
        title: qsTr("Select avatar image")
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.bmp *.webp)"]
        onAccepted: {
            Config.options.dashboard.avatarPath = selectedFile.toString().replace("file://", "")
            avatarPathField.text = Config.options.dashboard.avatarPath
        }
    }

    ContentSection {
        title: qsTr("Shell style")
        icon: "style"

        ConfigSwitch {
            text: qsTr("Transparency")
            checked: Config.options.appearance.transparency
            onClicked: checked = !checked;
            StyledToolTip { text: qsTr("Enable the blur effect on the shell.") }
            onCheckedChanged: Config.options.appearance.transparency = checked;
        }

        ConfigSpinBox {
            text: qsTr("Opacity")
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
        title: qsTr("Bar")
        icon: "toolbar"

        RowLayout {
            spacing: 10
            uniformCellSizes: true

            ConfigSwitch {
                text: qsTr("Show app name")
                checked: Config.options.bar.showTitle
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.showTitle = checked;
            }

            ConfigSwitch {
                text: qsTr("Show resources usage")
                checked: Config.options.bar.showRessources
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.showRessources = checked;
            }
        }

        RowLayout {
            spacing: 10
            uniformCellSizes: true

            ConfigSwitch {
                text: qsTr("Show Workspaces")
                checked: Config.options.bar.showWorkspaces
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.showWorkspaces = checked;
            }

            ConfigSwitch {
                text: qsTr("Show clock")
                checked: Config.options.bar.showClock
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.showClock = checked;
            }
        }

        RowLayout {
            spacing: 10
            uniformCellSizes: true

            ConfigSwitch {
                text: qsTr("Show system icons")
                checked: Config.options.bar.showTrayAndIcons
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.showTrayAndIcons = checked;
            }

            ConfigSwitch {
                text: qsTr("Enable bar background")
                checked: Config.options.bar.background
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.bar.background = checked;
            }

        }

        ContentSubsection {
            title: qsTr("Workspaces")
            tooltip: qsTr("Tip: Hide icons for the\nclassic Sleex experience")

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: qsTr("Show app icons")
                    onClicked: checked = !checked;
                    checked: Config.options.bar.workspaces.showAppIcons
                    onCheckedChanged: {
                        Config.options.bar.workspaces.showAppIcons = checked;
                    }
                }
                ConfigSwitch {
                    text: qsTr("Use Material icons")
                    onClicked: checked = !checked;
                    checked: Config.options.bar.workspaces.useMaterialIcons
                    onCheckedChanged: {
                        Config.options.bar.workspaces.useMaterialIcons = checked;
                    }
                }
            }
            ConfigSwitch {
                text: qsTr("Always show numbers")
                onClicked: checked = !checked;
                checked: Config.options.bar.workspaces.alwaysShowNumbers
                onCheckedChanged: {
                    Config.options.bar.workspaces.alwaysShowNumbers = checked;
                }
            }
            ConfigSpinBox {
                text: qsTr("Workspaces shown")
                value: Config.options.bar.workspaces.shown
                from: 1
                to: 30
                stepSize: 1
                onValueChanged: {
                    Config.options.bar.workspaces.shown = value;
                }
            }
            ConfigSpinBox {
                text: qsTr("Number show delay when pressing Super (ms)")
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
        title: qsTr("Dashboard")
        icon: "dashboard"

        ConfigSpinBox {
            text: qsTr("Scale")
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
            placeholderText: qsTr("Github username")
            text: Config.options.dashboard.ghUsername
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.dashboard.ghUsername = text;
            }
        }

        MaterialTextField {
            id: userDesc
            Layout.fillWidth: true
            placeholderText: qsTr("User description")
            text: Config.options.dashboard.userDesc
            onTextChanged: {
                Config.options.dashboard.userDesc = text;
            }
        }

        // Avatar path field with Browse button (merged from doc 1)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialTextField {
                id: avatarPathField
                Layout.fillWidth: true
                placeholderText: qsTr("Avatar image path")
                text: Config.options.dashboard.avatarPath
                onEditingFinished: {
                    Config.options.dashboard.avatarPath = text;
                }
            }

            RippleButtonWithIcon {
                materialIcon: "image"
                materialIconFill: false
                mainText: "Browse"
                onClicked: avatarPickerDialog.open()
            }
        }

        ContentSubsection {
            title: qsTr("Optional features")
            tooltip: qsTr("May affect performance.\nThe dashboard may load more slowly.")

            ConfigSwitch {
                text: qsTr("Todo list")
                checked: Config.options.dashboard.opt.enableTodo
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.dashboard.opt.enableTodo = checked;
            }
            ConfigSwitch {
                text: qsTr("Calendar tab")
                checked: Config.options.dashboard.opt.enableCalendar
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.dashboard.opt.enableCalendar = checked;
            }
        }

        StyledText {
            text: qsTr("Animation Direction")
            color: Appearance.colors.colSubtext
        }

        StyledComboBox {
            id: dashboardAnimationComboBox
            model: ["Right", "Left", "Down", "Up"]
            currentIndex: Math.max(0, dashboardAnimationKeys.indexOf(Config.options.dashboard.animationDirection))

            onActivated: (index) => {
                const selectedValue = dashboardAnimationKeys[index]
                if (Config.options.dashboard.animationDirection !== selectedValue) {
                    Config.options.dashboard.animationDirection = selectedValue
                }
            }
        }

        StyledText {
            text: qsTr("Animation Intensity")
            color: Appearance.colors.colSubtext
        }

        StyledSlider {
            id: dashboardAnimationSlider
            from: 0
            to: 1
            value: Config.options.dashboard.animationDuration / 1500

            onMoved: {
                if (Config.loaded) {
                    Config.options.dashboard.animationDuration = value * 1500
                }
            }
        }
    }

    ContentSection {
        title: qsTr("Dock")
        icon: "dock"

        ConfigRow {
            uniform: true

            ConfigSwitch {
                text: qsTr("Enabled")
                onClicked: checked = !checked;
                checked: Config.options.dock.enabled
                onCheckedChanged: {
                    Config.options.dock.enabled = checked;
                }
            }
            ConfigSpinBox {
                text: qsTr("Height")
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
                text: qsTr("Hover to reveal")
                onClicked: checked = !checked;
                checked: Config.options.dock.hoverToReveal
                onCheckedChanged: {
                    Config.options.dock.hoverToReveal = checked;
                }
            }
            ConfigSwitch {
                text: qsTr("Pinned on startup")
                onClicked: checked = !checked
                checked: Config.options.dock.pinnedOnStartup
                onCheckedChanged: {
                    Config.options.dock.pinnedOnStartup = checked;
                }
            }

        }

        ConfigSpinBox {
            text: qsTr("Hover region height")
            value: Config.options.dock.hoverRegionHeight
            onValueChanged: {
                Config.options.dock.hoverRegionHeight = value
            }
        }

    }


    ContentSection {
        title: qsTr("Background")
        icon: "wallpaper"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            ConfigRow {
                uniform: true

                ConfigSwitch {
                    text: qsTr("Show clock")
                    checked: Config.options.background.enableClock
                    onClicked: checked = !checked;
                    onCheckedChanged: Config.options.background.enableClock = checked;
                }

                ConfigSwitch {
                    text: qsTr("Fixed clock position")
                    checked: Config.options.background.fixedClockPosition
                    onClicked: checked = !checked;
                    onCheckedChanged: Config.options.background.fixedClockPosition = checked;
                }
            }

            ConfigRow {
                uniform: true

                ConfigSwitch {
                    text: qsTr("Show watermark")
                    checked: Config.options.background.showWatermark
                    onClicked: checked = !checked;
                    onCheckedChanged: Config.options.background.showWatermark = checked;
                }

                ConfigSwitch {
                    text: qsTr("Show quotes")
                    checked: Config.options.background.enableQuote
                    onClicked: checked = !checked
                    onCheckedChanged: {
                        Config.options.background.enableQuote = checked
                        Quotes.refresh();
                    }
                }

            }

            ConfigSwitch {
                text: qsTr("Show desktop icons")
                checked: Config.options.background.showDesktopIcons
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.background.showDesktopIcons = checked;
            }

            ContentSubsection {
                title: qsTr("Clock mode")

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
                title: qsTr("Clock Font")

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
                title: qsTr("Quote Source")
                tooltip: qsTr("The local quotes are stored in /usr/share/sleex/assets/quotes.json.\nThese quotes are made by the AxOS community and are tech related.")

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
        title: qsTr("Notifications")
        icon: "notifications"

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

        ConfigSwitch {
            visible: UPower.displayDevice.isLaptopBattery
            text: qsTr("Battery overlay warnings")
            checked: Config.options.battery.overlayEnabled
            onClicked: checked = !checked;
            onCheckedChanged: {
                Config.options.battery.overlayEnabled = checked;
            }
        }
    }

    ContentSection {
        title: qsTr("Lock Screen")
        icon: "lock"

        ConfigSwitch {
            text: qsTr("Scrim background")
            checked: Config.options.lockscreen.enableScrim
            onClicked: checked = !checked;
            onCheckedChanged: Config.options.lockscreen.enableScrim = checked;
        }

        ConfigSwitch {
            id: mediaShowOnLockScreenSwitch
            text: qsTr("Player integration")
            checked: Config.options.lockscreen.showLyricsOnLockScreen
            onClicked: checked = !checked;
            onCheckedChanged: Config.options.lockscreen.showLyricsOnLockScreen = checked
            StyledToolTip { text: qsTr("Show the media player widget on the lock screen.") }
        }

        ConfigSwitch {
            visible: mediaShowOnLockScreenSwitch.checked
            text: qsTr("Resizable widget")
            checked: Config.options.lockscreen.resizableLockScreenWidget ?? false
            onClicked: checked = !checked;
            onCheckedChanged: Config.options.lockscreen.resizableLockScreenWidget = checked
            StyledToolTip { text: qsTr("Allow resizing & repositioning of the media player widget.") }
        }
    }

    ContentSection {
        title: qsTr("Login Screen")
        icon: "key"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                id: faceImageLabel
                Layout.fillWidth: true
                text: _selectedFaceImage !== "" ? qsTr("Custom picture set") : qsTr("No picture selected")
                elide: Text.ElideMiddle
                color: palette.windowText
            }

            RowLayout {
                spacing: 8

                RippleButtonWithIcon {
                    materialIcon: "folder_open"
                    materialIconFill: false
                    mainText: "Browse"
                    onClicked: sddmFaceDialog.open()
                }

                RippleButtonWithIcon {
                    visible: _selectedFaceImage !== ""
                    materialIcon: "delete"
                    materialIconFill: false
                    mainText: "Remove"
                    onClicked: {
                        removeProcess.command = [
                            "pkexec", "rm", "-f",
                            "/usr/share/sddm/faces/" + _selectedFaceImage.split("/").pop()
                        ]
                        removeProcess.running = true
                    }
                }
            }
        }
    }

    ContentSection {
        title: qsTr("Calendar")
        icon: "event"

        ContentSubsection {
            title: qsTr("Advanced")
            tooltip: qsTr("Vdirsyncer is not configured by default.\nPlease refer to the documentation\nto set it up. Enable it only after configuration.")
        }
        ConfigSwitch {
            text: qsTr("Use vdirsyncer")
            checked: Config.options.dashboard.calendar.useVdirsyncer
            onClicked: checked = !checked;
            onCheckedChanged: Config.options.dashboard.calendar.useVdirsyncer = checked;
        }

        ConfigSpinBox {
            text: qsTr("Sync interval (minutes)")
            value: Config.options.dashboard.calendar.syncInterval
            from: 1
            to: 1440 // 24 hours
            stepSize: 1
            onValueChanged: {
                Config.options.dashboard.calendar.syncInterval = value;
            }
        }
    }

    Item {
        implicitHeight: 24
    }
}
