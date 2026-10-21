import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Functions
import Sleex.Utils

Rectangle {
    id: root

    property real cellWidth: 0
    property real cellHeight: 0
    property real gridSpacing: 10

    readonly property bool active: BentoModel.isDragging
    readonly property bool isValid: BentoModel.dropValid
    readonly property color accentColor: root.isValid ? Appearance.colors.colPrimary : (Appearance.colors.colError ?? "#FF5555")

    x: BentoModel.dropCol * (root.cellWidth + root.gridSpacing)
    y: BentoModel.dropRow * (root.cellHeight + root.gridSpacing)
    width: BentoModel.dropColSpan * root.cellWidth + Math.max(0, BentoModel.dropColSpan - 1) * root.gridSpacing
    height: BentoModel.dropRowSpan * root.cellHeight + Math.max(0, BentoModel.dropRowSpan - 1) * root.gridSpacing

    radius: Appearance.rounding.normal
    color: ColorUtils.transparentize(root.accentColor, 0.85)
    border.width: 2
    border.color: root.accentColor

    opacity: root.active ? 1.0 : 0.0
    visible: opacity > 0

    Behavior on x {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
}
