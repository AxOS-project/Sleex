import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceSingleColumn: true
    
    ContentSection {
        title: qsTr("Weather")
        icon: "cloud"

        ConfigSwitch {
            id: weatherSwitch
            text: qsTr("Enabled")
            checked: Config.options.dashboard.enableWeather
            onClicked: checked = !checked;
            onCheckedChanged: Config.options.dashboard.enableWeather = checked
            StyledToolTip { text: qsTr("View weather forecasts directly in your dashboard.\nIt uses the https://open-meteo.com provider.") }
        }
        
        ConfigSwitch {
            id: autoLocationSwitch
            visible: weatherSwitch.checked
            text: qsTr("Automatic Location")
            checked: Config.options.dashboard.autoWeatherLocation ?? true
            onClicked: checked = !checked;
            onCheckedChanged: {
                Config.options.dashboard.autoWeatherLocation = checked;
                Weather.updateWeather();
            }
            StyledToolTip { text: qsTr("IP-based approximate location.") }
        }
        
        MaterialTextField {
            id: weatherLocation
            visible: weatherSwitch.checked && !autoLocationSwitch.checked
            Layout.fillWidth: true
            placeholderText: qsTr("Weather Location")
            text: Config.options.dashboard.weatherLocation
            wrapMode: TextEdit.Wrap
            onEditingFinished: {
                Config.options.dashboard.weatherLocation = text;
            }
        }
    }
    
    ContentSection {
        title: qsTr("Media Player")
        icon: "music_note"

        ConfigSwitch {
            id: lyricsSwitch
            text: qsTr("Lyrics")
            checked: Config.options.dashboard.enableLyrics
            onClicked: checked = !checked;
            onCheckedChanged: Config.options.dashboard.enableLyrics = checked
            StyledToolTip { text: qsTr("Fetch and display synced lyrics (LRCLIB provider).") }
        }
    }
    
    Item {
        implicitHeight: 24
    }
}
