pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import SleexUiKit.Widgets
import qs.services
import SleexUiKit.Functions
import SleexUiKit.Appearance

Item {
    id: root

    required property real screenWidth
    required property real screenHeight
    required property real widgetX
    required property real widgetY
    required property bool fixedPosition

    signal positionChanged(real newX, real newY)
    signal fixedPositionToggled()

    visible: Config.options.background.enableWeatherWidget ?? true

    property real startX: 0
    property real startY: 0

    anchors {
        left: parent.left
        top: parent.top
        leftMargin: widgetX - implicitWidth / 2
        topMargin: widgetY - implicitHeight / 2
    }

    implicitWidth: card.width
    implicitHeight: card.height

    DragHandler {
        enabled: !root.fixedPosition
        id: dragHandler
        cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onActiveChanged: {
            if (active) {
                startX = widgetX
                startY = widgetY
            } else {
                Config.options.background.weatherX = widgetX
                Config.options.background.weatherY = widgetY
            }
        }

        onTranslationChanged: {
            let newX = startX + translation.x
            let newY = startY + translation.y
            let halfWidth = implicitWidth / 2
            let halfHeight = implicitHeight / 2

            newX = Math.max(halfWidth, Math.min(screenWidth - halfWidth, newX))
            newY = Math.max(halfHeight, Math.min(screenHeight - halfHeight, newY))

            positionChanged(newX, newY)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        cursorShape: Qt.ArrowCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                fixedPositionToggled()
            }
        }
    }
    
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
        border.color: !root.fixedPosition ? "red" : "transparent"
        border.width: !root.fixedPosition ? 3 : 0

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
