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

        // StyledText {
        //     text: "Material palette"
        //     color: Appearance.colors.colSubtext
        // }

        // ConfigSelectionArray {
        //     currentValue: Config.options.appearance.palette.type
        //     configOptionName: "appearance.palette.type"
        //     onSelected: (newValue) => {
        //         Config.options.appearance.palette.type = newValue;
        //         Hyprland.dispatch(`exec ${Directories.wallpaperSwitchScriptPath} --noswitch --type ${newValue}`)
        //     }
        //     options: [
        //         {"value": "auto", "displayName": "Auto"},
        //         {"value": "scheme-content", "displayName": "Content"},
        //         {"value": "scheme-expressive", "displayName": "Expressive"},
        //         {"value": "scheme-fidelity", "displayName": "Fidelity"},
        //         {"value": "scheme-fruit-salad", "displayName": "Fruit Salad"},
        //         {"value": "scheme-monochrome", "displayName": "Monochrome"},
        //         {"value": "scheme-neutral", "displayName": "Neutral"},
        //         {"value": "scheme-rainbow", "displayName": "Rainbow"},
        //         {"value": "scheme-tonal-spot", "displayName": "Tonal Spot"}
        //     ]
        // }

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
                    Quickshell.execDetached(["sh", `${Directories.wallpaperSwitchScriptPath}`, "--noswitch", "--type", `${selectedValue}`])
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
                StyledToolTip { content: "Pick wallpaper image on your system" }

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
