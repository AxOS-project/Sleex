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
    id: clockWidget

    required property real screenWidth
    required property real screenHeight
    property real clockSizeMultiplier: Config.options.background.clockSizeMultiplier
    required property color textColor
    required property int textHorizontalAlignment

    signal clockPositionChanged(real newX, real newY)
    signal fixedPositionToggled()

    visible: Config.options.background.enableClock ?? true

    x: (Config.options.background.clockX || (screenWidth / 2)) - implicitWidth / 2
    y: (Config.options.background.clockY || (screenHeight / 2)) - implicitHeight / 2
    draggable: true

    function commitPosition() {
        Config.options.background.clockX = clockWidget.x + clockWidget.implicitWidth / 2
        Config.options.background.clockY = clockWidget.y + clockWidget.implicitHeight / 2
    }

    implicitWidth: clockColumn.implicitWidth
    implicitHeight: clockColumn.implicitHeight
    
    ColumnLayout {
        id: clockColumn
        anchors.centerIn: parent
        spacing: -5

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: clockWidget.textHorizontalAlignment
            font.family: Config.options.background.clockFontFamily ?? "Sans Serif"
            font.pixelSize: 95 * Config.options.background.clockSizeMultiplier
            color: Config.options.background.textColor ?? textColor
            style: Text.Raised
            styleColor: Appearance.colors.colShadow
            text: DateTime.time
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: clockWidget.textHorizontalAlignment
            font.family: Config.options.background.clockFontFamily ?? "Sans Serif"
            font.pixelSize: 25 * Config.options.background.clockSizeMultiplier
            color: Config.options.background.textColor ?? textColor
            style: Text.Raised
            styleColor: Appearance.colors.colShadow
            text: DateTime.date
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y < 0) 
                Config.options.background.clockSizeMultiplier = Math.max(0.3, Config.options.background.clockSizeMultiplier - 0.1)
            else if (event.angleDelta.y > 0) 
                Config.options.background.clockSizeMultiplier = Math.min(7, Config.options.background.clockSizeMultiplier + 0.1)
        }
    }
}