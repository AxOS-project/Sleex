import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceSingleColumn: true

        ContentSection {
            title: "Policies"
            icon: "policy"

            ContentSubsectionLabel {
                text: "AI"
            }
            ConfigSelectionArray {
                currentValue: Config.options.policies.ai
                onSelected: newValue => {
                    Config.options.policies.ai = newValue;
                }
                options: [
                    {
                        displayName: "No",
                        value: 0
                    },
                    {
                        displayName: "Yes",
                        value: 1
                    },
                    {
                        displayName: "Local only",
                        value: 2
                    }
                ]
            }
        }

        ContentSection {
            title: "Weather"
            icon: "cloud"

            ConfigSwitch {
                id: weatherSwitch
                text: "Enabled"
                checked: Config.options.dashboard.enableWeather
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.dashboard.enableWeather = checked
                StyledToolTip { text: "View weather forecasts directly in your dashboard.\nIt uses the https://open-meteo.com provider." }
            }

            ConfigSwitch {
                id: autoLocationSwitch
                visible: weatherSwitch.checked
                text: "Automatic Location"
                checked: Config.options.dashboard.autoWeatherLocation ?? true
                onClicked: checked = !checked;
                onCheckedChanged: {
                    Config.options.dashboard.autoWeatherLocation = checked;
                    Weather.updateWeather();
                }
                StyledToolTip { text: "IP-based approximate location." }
            }

            MaterialTextField {
                id: weatherLocation
                visible: weatherSwitch.checked && !autoLocationSwitch.checked
                Layout.fillWidth: true
                placeholderText: "Weather Location"
                text: Config.options.dashboard.weatherLocation
                wrapMode: TextEdit.Wrap
                onEditingFinished: {
                    Config.options.dashboard.weatherLocation = text;
                }
            }
        }

        ContentSection {
            title: "Music Player"
            icon: "music_note"

            ConfigSwitch {
                id: musicPlayerSwitch
                text: "Enabled"
                checked: Config.options.dashboard.enableMusicPlayer
                onClicked: checked = !checked;
                onCheckedChanged: {
                    Config.options.dashboard.enableMusicPlayer = checked;
                    if (!checked) {
                        showOnLockScreenSwitch.checked = false;
                        lyricsSwitch.checked = false;
                    }
                }
                StyledToolTip { text: "Show music player controls (playback, track info, lyrics)." }
            }

            ConfigSwitch {
                id: lyricsSwitch
                visible: musicPlayerSwitch.checked
                text: "Lyrics"
                checked: Config.options.dashboard.enableLyrics
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.dashboard.enableLyrics = checked
                StyledToolTip { text: "Fetch and display synced lyrics (LRCLIB provider)." }
            }

            ConfigSwitch {
                id: showOnLockScreenSwitch
                visible: musicPlayerSwitch.checked
                text: "Lockscreen integration"
                checked: Config.options.dashboard.showLyricsOnLockScreen
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.dashboard.showLyricsOnLockScreen = checked
                StyledToolTip { text: "Display the music player on the lock screen." }
            }

            ConfigSwitch {
                id: resizableWidgetSwitch
                visible: showOnLockScreenSwitch.checked
                text: "Resizable widget"
                checked: Config.options.dashboard.resizableLockScreenWidget ?? false
                onClicked: checked = !checked;
                onCheckedChanged: Config.options.dashboard.resizableLockScreenWidget = checked
                StyledToolTip { text: "Allow resizing the lock screen widget." }
            }
        }

        ContentSection {
            title: "Lyrics Settings"
            icon: "text_snippet"
            visible: musicPlayerSwitch.checked && lyricsSwitch.checked

            RowLayout {
                ConfigSpinBox {
                    text: "Dashboard widget font"
                    value: Math.round((Config.options.dashboard.dashboardLyricsFontScale ?? 1.0) * 10)
                    from: 5
                    to: 30
                    stepSize: 1
                    onValueChanged: {
                        Config.options.dashboard.dashboardLyricsFontScale = value / 10.0;
                    }
                    ToolTip {
                        text: "Scale the size of lyrics text in the dashboard widget (0.5x to 3.0x)."
                        visible: parent.hovered
                        delay: 500
                    }
                }
                Item { Layout.fillWidth: true }
            }

            RowLayout {
                visible: showOnLockScreenSwitch.checked
                ConfigSpinBox {
                    text: "Lockscreen widget font"
                    value: Math.round((Config.options.dashboard.lockscreenLyricsFontScale ?? 1.0) * 10)
                    from: 5
                    to: 30
                    stepSize: 1
                    onValueChanged: {
                        Config.options.dashboard.lockscreenLyricsFontScale = value / 10.0;
                    }
                    ToolTip {
                        text: "Scale the size of lyrics text on the lock screen (0.5x to 3.0x)."
                        visible: parent.hovered
                        delay: 500
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

        Item {
            implicitHeight: 24
        }
}
