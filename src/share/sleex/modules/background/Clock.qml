pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions

Item {
    id: clockWidget

    required property real screenWidth
    required property real screenHeight
    required property real clockX
    required property real clockY
    required property real clockSizeMultiplier
    required property bool fixedClockPosition
    required property color textColor
    required property int textHorizontalAlignment

    signal clockPositionChanged(real newX, real newY)
    signal fixedPositionToggled()

    visible: Config.options.background.enableClock ?? true

    property real startClockX: 0
    property real startClockY: 0

    anchors {
        left: parent.left
        top: parent.top
        leftMargin: clockX - implicitWidth / 2
        topMargin: clockY - implicitHeight / 2
    }

    implicitWidth: clockColumn.implicitWidth
    implicitHeight: clockColumn.implicitHeight

    DragHandler {
        enabled: !clockWidget.fixedClockPosition
        id: dragHandler
        cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onActiveChanged: {
            if (active) {
                startClockX = clockX
                startClockY = clockY
            } else {
                Config.options.background.clockX = clockX
                Config.options.background.clockY = clockY
            }
        }

        onTranslationChanged: {
            let newX = startClockX + translation.x
            let newY = startClockY + translation.y
            let halfWidth = implicitWidth / 2
            let halfHeight = implicitHeight / 2

            newX = Math.max(halfWidth, Math.min(screenWidth - halfWidth, newX))
            newY = Math.max(halfHeight, Math.min(screenHeight - halfHeight, newY))

            clockPositionChanged(newX, newY)
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

    Rectangle {
        visible: !clockWidget.fixedClockPosition
        anchors.centerIn: parent
        width: clockColumn.width
        height: clockColumn.height
        color: "transparent"
        border.color: "red"
        border.width: 3
        radius: Appearance.rounding.normal
        z: -1  // Put it behind the text
    }
    
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
        enabled: !clockWidget.fixedClockPosition
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y < 0) 
                Config.options.background.clockSizeMultiplier = Math.max(0.3, Config.options.background.clockSizeMultiplier - 0.1)
            else if (event.angleDelta.y > 0) 
                Config.options.background.clockSizeMultiplier = Math.min(7, Config.options.background.clockSizeMultiplier + 0.1)
        }
    }
}