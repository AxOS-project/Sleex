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

ContentPage {
    baseWidth: lightDarkButtonGroup.implicitWidth
    forceWidth: true

    // Lookup arrays for clean mapping
    readonly property var paletteKeys: ["auto", "scheme-content", "scheme-expressive", "scheme-fidelity", "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-tonal-spot"]
    readonly property var transitionKeys: ["fade", "scale"]

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
        
        StyledText {
            text: "Wallpaper Transition"
            color: Appearance.colors.colSubtext
        }

       StyledComboBox {
            id: transitionComboBox
            model: ["Fade", "Scale"]
            currentIndex: Math.max(0, transitionKeys.indexOf(Config.options.background.wallpaperTransition))
            
            onActivated: (index) => {
                const selectedValue = transitionKeys[index]
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
             from: 0.1
             to: 1.0
             value: Config.options.background.transitionDuration / 1000
        onMoved: {
            if (Config.loaded) {
                Config.options.background.transitionDuration = value * 1000
             }
         }
    }
    
        ConfigSwitch {
            id: staticColorsSwitch
            text: "Static colors"
            checked: Config.options.appearance.palette.useStaticColors
            
            onToggled: {
                Config.options.appearance.palette.useStaticColors = checked;
                if (!checked) {
                    Quickshell.execDetached(["sh", Directories.wallpaperSwitchScriptPath, "--noswitch", "--type", Config.options.appearance.palette.type])
                }
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
                model: ["#3584E4", "#2190A4", "#3A944A", "#C88800", "#ED5B00", "#E62D42", "#D56199", "#9141AC", "#6F8396"]
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
                            Quickshell.execDetached(["sh", Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", modelData])
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
            placeholderText: "Wallpaper path"
            text: Config.options.background.wallpaperSelectorPath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.background.wallpaperSelectorPath = text;
            }
        }
    }
}
