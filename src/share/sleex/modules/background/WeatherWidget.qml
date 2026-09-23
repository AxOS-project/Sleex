pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import SleexUiKit.Widgets
import qs.services
import SleexUiKit.Functions
import SleexUiKit.Appearance
import "../common/widgets/widgetCanvas"

AbstractWidget {
    id: root

    required property real screenWidth
    required property real screenHeight

    signal positionChanged(real newX, real newY)
    signal fixedPositionToggled()

    visible: Config.options.background.enableWeatherWidget ?? true

    x: (Config.options.background.weatherX || (screenWidth / 2)) - implicitWidth / 2
    y: (Config.options.background.weatherY || (screenHeight / 2)) - implicitHeight / 2
    draggable: true

    function commitPosition() {
        Config.options.background.weatherX = root.x + root.implicitWidth / 2
        Config.options.background.weatherY = root.y + root.implicitHeight / 2
    }

    implicitWidth: card.width
    implicitHeight: card.height    
    function materialSymbolForCode(code) {
        const c = parseInt(code);
        if (isNaN(c)) return "cloud";
        if (c === 0)    return "sunny";
        if (c <= 2)     return "partly_cloudy_day";
        if (c === 3)    return "cloud";
        if (c <= 48)    return "foggy";
        if (c <= 57)    return "rainy";
        if (c <= 67)    return "rainy";
        if (c <= 77)    return "weather_snowy";
        if (c <= 82)    return "rainy";
        if (c <= 86)    return "weather_snowy";
        if (c <= 99)    return "thunderstorm";
        return "cloud";
    }

    Rectangle {
        id: card
        width: 320
        height: 140
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0

        StyledRectangularShadow {
            target: card
            z: -2
            visible: true
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16
            
            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                
                StyledText {
                    text: Weather.temperature || "--°"
                    font.pixelSize: 42
                    font.weight: Font.Bold
                    color: Appearance.colors.colPrimary
                }
                
                StyledText {
                    text: Weather.condition || "--"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
                
                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        iconSize: 14
                        text: "location_on"
                        color: Appearance.colors.colPrimary
                        opacity: 0.7
                    }
                    StyledText {
                        text: Weather.locationName || "--"
                        font.pixelSize: 14
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }
            }
            
            Rectangle {
                width: 64
                height: 64
                radius: 32
                color: Appearance.colors.colPrimary
                Layout.alignment: Qt.AlignVCenter
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.materialSymbolForCode(Weather.weatherCode)
                    iconSize: 32
                    color: Appearance.colors.colOnPrimary
                }
            }
        }
    }
}
