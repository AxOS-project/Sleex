import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property int size: 25
    property color color

    property QtObject cornerEnum: QtObject {
        property int topLeft: 0
        property int topRight: 1
        property int bottomLeft: 2
        property int bottomRight: 3
    }

    property int corner: cornerEnum.topLeft // Default to TopLeft

    readonly property bool isTL: corner === cornerEnum.topLeft
    readonly property bool isTR: corner === cornerEnum.topRight
    readonly property bool isBL: corner === cornerEnum.bottomLeft
    readonly property bool isBR: corner === cornerEnum.bottomRight

    width: size
    height: size

    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            fillColor: root.color
            strokeWidth: 0
            strokeColor: "transparent"

            startX: root.isTL || root.isTR ? 0 : root.size
            startY: root.isTL || root.isBL ? root.size : 0

            PathArc {
                x: root.isTL || root.isTR ? root.size : 0
                y: root.isTR || root.isBR ? root.size : 0
                radiusX: root.size
                radiusY: root.size
                direction: PathArc.Clockwise
            }

            PathLine {
                x: root.isTR || root.isBR ? root.size : 0
                y: root.isBL || root.isBR ? root.size : 0
            }

            PathLine {
                x: root.isTL || root.isTR ? 0 : root.size
                y: root.isTL || root.isBL ? root.size : 0
            }
        }
    }

    Behavior on size {
        animation: Appearance?.animation.elementMoveFast.numberAnimation.createObject(this)
    }
}