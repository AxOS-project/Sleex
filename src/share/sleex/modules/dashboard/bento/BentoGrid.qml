import QtQuick
import SleexUiKit.Appearance
import SleexUiKit.Functions
import Sleex.Utils

Item {
    id: root

    property bool connected: false
    property real gridSpacing: 10

    readonly property int cols: BentoModel.columns
    readonly property int rows: BentoModel.rows

    readonly property real cellWidth: root.cols > 0 ? (root.width - (root.cols - 1) * root.gridSpacing) / root.cols : 0
    readonly property real cellHeight: root.rows > 0 ? (root.height - (root.rows - 1) * root.gridSpacing) / root.rows : 0

    BentoWidgetRegistry {
        id: widgetRegistry
        connected: root.connected
    }

    Component.onCompleted: {
        if (BentoModel.rowCount() === 0) {
            BentoModel.initRegistry(widgetRegistry.definitions)
        }
    }

    // Subtle background cell grid visible while dragging or customizing
    Item {
        id: backgroundGridOverlay
        anchors.fill: parent
        opacity: (BentoModel.isDragging || BentoModel.customizeOpen) ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Repeater {
            model: root.cols * root.rows
            delegate: Rectangle {
                readonly property int cellCol: index % root.cols
                readonly property int cellRow: Math.floor(index / root.cols)

                x: cellCol * (root.cellWidth + root.gridSpacing)
                y: cellRow * (root.cellHeight + root.gridSpacing)
                width: root.cellWidth
                height: root.cellHeight
                radius: Appearance.rounding.normal
                color: "transparent"
                border.width: 1
                border.color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
            }
        }
    }

    // Animated ghost target placeholder during drag
    BentoDropPlaceholder {
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        gridSpacing: root.gridSpacing
    }

    // Flat Repeater of Bento widgets
    Repeater {
        model: BentoModel
        delegate: BentoItemWrapper {
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            gridSpacing: root.gridSpacing
            registry: widgetRegistry
        }
    }
}
