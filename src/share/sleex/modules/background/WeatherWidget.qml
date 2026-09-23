pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
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

    ClippingRectangle {
        id: card
        width: 270
        height: 120
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0

        StyledRectangularShadow {
            target: card
            z: -2
            visible: true
        }
        
        RowLayout {
            anchors.fill: parent

            Rectangle {
                width: card.height
                height: width
                color: Appearance.colors.colPrimary
                Layout.alignment: Qt.AlignVCenter
                clip: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.materialSymbolForCode(Weather.weatherCode)
                        iconSize: 42
                        color: Appearance.colors.colOnPrimary
                    }

                    StyledText {
                        text: Weather.temperature || "--°"
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 8
                color: "transparent"
            
                ColumnLayout {
                    spacing: 8
                    anchors.margins: 12
                    Layout.fillWidth: true

                    StyledText {
                        text: Weather.locationName || "--"
                        font.pixelSize: 20
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer0
                    }   
                    
                    StyledText {
                        text: Weather.condition || "--"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.7
                    }

                    Item {
                        Layout.fillHeight: true
                        height: 20
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        spacing: 16
                        opacity: 0.4

                        RowLayout {
                            spacing: 2
                            MaterialSymbol {
                                text: "water_drop"
                                font.pixelSize: 12
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                text: Weather.humidity ? `${Weather.humidity}%` : "--%"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer0
                            }
                        }

                        RowLayout {
                            spacing: 2
                            MaterialSymbol {
                                text: "air"
                                font.pixelSize: 12
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                text: Weather.windSpeed ? `${Weather.windSpeed} km/h` : "-- km/h"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer0
                            }
                        }
                    }
                }
            }
        }
    }
}
