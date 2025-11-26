import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.functions

ContentPage {
    baseWidth: lightDarkButtonGroup.implicitWidth
    forceWidth: true

    ContentSection {
        title: "Colors & Wallpaper"

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
            model: [
                "Auto",
                "Content",
                "Expressive",
                "Fidelity",
                "Fruit Salad",
                "Monochrome",
                "Neutral",
                "Rainbow",
                "Tonal Spot"
            ]
            currentIndex: model.indexOf(
                (() => {
                    switch (Config.options.appearance.palette.type) {
                        case "auto": return "Auto";
                        case "scheme-content": return "Content";
                        case "scheme-expressive": return "Expressive";
                        case "scheme-fidelity": return "Fidelity";
                        case "scheme-fruit-salad": return "Fruit Salad";
                        case "scheme-monochrome": return "Monochrome";
                        case "scheme-neutral": return "Neutral";
                        case "scheme-rainbow": return "Rainbow";
                        case "scheme-tonal-spot": return "Tonal Spot";
                        default: return "Auto";
                    }
                })()
            )
            onCurrentIndexChanged: {
                const valueMap = {
                    "Auto": "auto",
                    "Content": "scheme-content",
                    "Expressive": "scheme-expressive",
                    "Fidelity": "scheme-fidelity",
                    "Fruit Salad": "scheme-fruit-salad",
                    "Monochrome": "scheme-monochrome",
                    "Neutral": "scheme-neutral",
                    "Rainbow": "scheme-rainbow",
                    "Tonal Spot": "scheme-tonal-spot"
                }
                const selectedValue = valueMap[model[currentIndex]]
                if (Config.options.appearance.palette.type !== selectedValue) {
                    Config.options.appearance.palette.type = selectedValue
                    if (!Config.options.appearance.palette.useStaticColors) Quickshell.execDetached(["sh", `${Directories.wallpaperSwitchScriptPath}`, "--noswitch", "--type", `${selectedValue}`])
                    else Quickshell.execDetached(["sh", `${Directories.wallpaperSwitchScriptPath}`, "--noswitch", "--color", `${Config.options.appearance.palette.accentColorHex}`])
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

        StyledText {
            text: "Wallpaper"
            color: Appearance.colors.colSubtext
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            RippleButtonWithIcon {
                materialIcon: "wallpaper"
                StyledToolTip { text: "Pick wallpaper image on your system" }

                onClicked: {
                    Quickshell.execDetached(["sh", `${Directories.wallpaperSwitchScriptPath}`])
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
            id: ghUsername
            Layout.fillWidth: true
            placeholderText: "Wallpaper path"
            text: Config.options.background.wallpaperSelectorPath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.background.wallpaperSelectorPath = text;
            }
        }
    }

}
