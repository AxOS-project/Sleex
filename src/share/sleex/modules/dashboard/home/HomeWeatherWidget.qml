import qs.modules.common
import qs.services
import qs.modules.dashboard.weather
import QtQuick
import SleexUiKit.Appearance

Rectangle {
    id: root
    property bool connected: false
    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.normal

    Loader {
        active: !Config.options.dashboard.enableWeather
        anchors.fill: parent
        sourceComponent: WeatherOff {
            anchors.fill: parent
        }
    }

    Loader {
        active: Config.options.dashboard.enableWeather && root.connected
        anchors.fill: parent
        sourceComponent: Weather {
            anchors.fill: parent
        }
    }

    Loader {
        active: Config.options.dashboard.enableWeather && !root.connected
        anchors.fill: parent
        sourceComponent: WeatherNoNet {
            anchors.fill: parent
        }
    }
}
