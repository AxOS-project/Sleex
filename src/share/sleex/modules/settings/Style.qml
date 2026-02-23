import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    baseWidth: lightDarkButtonGroup.implicitWidth
    forceWidth: true

    readonly property var paletteKeys: ["auto", "scheme-content", "scheme-expressive", "scheme-fidelity", "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-tonal-spot"]
    readonly property var transitionKeys: ["fade", "scale", "wipe"]
    readonly property var wipeOrientationKeys: ["wipe_left", "wipe", "wipe_up", "wipe_down"]

    readonly property bool isWipeSelected: {
        const t = Config.options.background.wallpaperTransition
        return t === "wipe" || t === "wipe_left" || t === "wipe_down" || t === "wipe_up"
    }

    ContentSection {
        title: "Colors"

        ButtonGroup {
            id: lightDarkButtonGroup
            Layout.fillWidth: true
            LightDarkPreferenceButton { dark: false }
            LightDarkPreferenceButton { dark: true }
        }

        StyledText {
            text: "Material Palette"
            color: Appearance.colors.colSubtext
        }

        StyledComboBox {
            id: paletteComboBox
            model: ["Auto", "Content", "Expressive", "Fidelity", "Fruit Salad", "Monochrome", "Neutral", "Rainbow", "Tonal Spot"]
            currentIndex: Math.max(0, paletteKeys.indexOf(Config.options.appearance.palette.type))

            onActivated: (index) => {
                const selectedValue = paletteKeys[index]
                if (Config.options.appearance.palette.type !== selectedValue) {
                    Config.options.appearance.palette.type = selectedValue
                    if (!Config.options.appearance.palette.useStaticColors) {
                        Quickshell.execDetached(["sh", Directories.wallpaperSwitchScriptPath, "--noswitch", "--type", selectedValue])
                    } else {
                        Quickshell.execDetached(["sh", Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", Config.options.appearance.palette.accentColorHex])
                    }
                }
            }
        }

       ConfigSwitch {
            id: staticColorsSwitch
            text: "Static colors"
            onClicked: checked = !checked;
            checked: Config.options.appearance.palette.useStaticColors
            onCheckedChanged: {
                Config.options.appearance.palette.useStaticColors = checked;
                if (!Config.options.appearance.palette.useStaticColors) Quickshell.execDetached(["sh", `${Directories.wallpaperSwitchScriptPath}`, `--noswitch`, "--type", `${Config.options.appearance.palette.type}`])
                // else Quickshell.execDetached(["sh", `${Directories.wallpaperSwitchScriptPath}`, "--noswitch", "--color", `${Config.options.appearance.palette.accentColorHex}`])
            }
            StyledToolTip {
                text: "Use a static accent color instead of extracting colors from wallpaper"   
            }
        }
        

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            visible: Config.options.appearance.palette.useStaticColors && Config.loaded

            Repeater {
                model: ["#3584E4", "#2190A4", "#3A944A", "#C88800", "#ED5B00", "#E62D42", "#D56199", "#9141AC", "#6F8396"] // Static colors
                delegate: Rectangle {
                    width: 30
                    height: 30
                    radius: Appearance.rounding.small
                    color: modelData
                    border.color: Appearance.colors.colPrimary
                    border.width: Config.options.appearance.palette.accentColorHex === modelData ? 2 : 0
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Config.options.appearance.palette.accentColorHex = modelData;
                            Quickshell.execDetached(["sh", `${Directories.wallpaperSwitchScriptPath}`, "--noswitch", "--color", `${modelData}`])
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        title: "Wallpaper"

        StyledText {
            text: "Transition Style"
            color: Appearance.colors.colSubtext
        }

        StyledComboBox {
            id: transitionComboBox
            model: ["Fade", "Scale", "Wipe"]
            currentIndex: {
                const t = Config.options.background.wallpaperTransition
                if (t === "wipe" || t === "wipe_left" || t === "wipe_down" || t === "wipe_up") return 2
                return Math.max(0, transitionKeys.indexOf(t))
            }

            onActivated: (index) => {
                let selectedValue
                if (index === 2) {
                    const current = Config.options.background.wallpaperTransition
                    selectedValue = wipeOrientationKeys.includes(current) ? current : "wipe"
                } else {
                    selectedValue = transitionKeys[index]
                }
                if (Config.options.background.wallpaperTransition !== selectedValue) {
                    Config.options.background.wallpaperTransition = selectedValue
                }
            }
        }

        StyledText {
            text: "Wipe Direction"
            color: Appearance.colors.colSubtext
            visible: isWipeSelected
        }

        StyledComboBox {
            id: wipeOrientationComboBox
            visible: isWipeSelected
            model: ["Left", "Right", "Up", "Down"]
            currentIndex: Math.max(0, wipeOrientationKeys.indexOf(Config.options.background.wallpaperTransition))

            onActivated: (index) => {
                const selectedValue = wipeOrientationKeys[index]
                if (Config.options.background.wallpaperTransition !== selectedValue) {
                    Config.options.background.wallpaperTransition = selectedValue
                }
            }
        }

        StyledText {
            text: "Animation Intensity"
            color: Appearance.colors.colSubtext
        }

        StyledSlider {
            id: animationSlider
            from: 0
            to: 1.0
            value: Config.options.background.transitionDuration / 1000

            onMoved: {
                if (Config.loaded) {
                    Config.options.background.transitionDuration = value * 1000
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            RippleButtonWithIcon {
                materialIcon: "wallpaper"
                StyledToolTip { text: "Pick wallpaper image on your system" }

                onClicked: {
                    Quickshell.execDetached(["sh", Directories.wallpaperSwitchScriptPath])
                }

                mainContentComponent: Component {
                    RowLayout {
                        spacing: 10
                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.small
                            text: "Choose file"
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        RowLayout {
                            spacing: 3
                            KeyboardKey { key: "Ctrl" }
                            KeyboardKey { key: "󰖳" }
                            StyledText { Layout.alignment: Qt.AlignVCenter; text: "+" }
                            KeyboardKey { key: "T" }
                        }
                    }
                }
            }
        }

        MaterialTextField {
            id: wallpaperPathField
            Layout.fillWidth: true
            placeholderText: "Wallpaper selector directory path"
            text: Config.options.background.wallpaperSelectorPath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.background.wallpaperSelectorPath = text
            }
        }

        Rectangle {
            id: imageContainer
            Layout.preferredHeight: 200
            Layout.preferredWidth: 360
            Layout.alignment: Qt.AlignHCenter
            radius: Appearance.rounding.medium
            color: "transparent"
            clip: true

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: Config.options.background.wallpaperPath || ""
                visible: source !== ""
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: 360
                        height: 200
                        radius: Appearance.rounding.normal
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: "No wallpaper set"
                color: Appearance.colors.colSubtext
                visible: !Config.options.background.wallpaperPath
            }

            MouseArea {
                id: clickArea
                hoverEnabled: true
                anchors.fill: parent
                onClicked: {
                    Quickshell.execDetached(["sh", Directories.wallpaperSwitchScriptPath])
                }
            }

            Rectangle {
                id: selectionOverlay
                anchors.fill: parent
                color: Appearance.colors.colScrim
                opacity: clickArea.containsMouse ? 0.8 : 0
                radius: Appearance.rounding.normal

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "edit"
                    iconSize: 42
                    opacity: clickArea.containsMouse ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }
            }
        }
    }

    Item {
        implicitHeight: 24
    }
}
