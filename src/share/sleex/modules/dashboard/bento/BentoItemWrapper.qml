import QtQuick
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import Sleex.Utils

Item {
    id: root

    property string widgetId: model.widgetId ?? ""
    property string title: model.title ?? ""
    property string icon: model.icon ?? "widgets"
    property int col: model.col ?? 0
    property int row: model.row ?? 0
    property int previewCol: model.previewCol ?? 0
    property int previewRow: model.previewRow ?? 0
    property int colSpan: model.colSpan ?? 1
    property int rowSpan: model.rowSpan ?? 2
    property int previewColSpan: model.previewColSpan ?? 1
    property int previewRowSpan: model.previewRowSpan ?? 2
    property bool widgetEnabled: model.widgetEnabled ?? true
    property var presets: model.presets ?? []

    property real cellWidth: 0
    property real cellHeight: 0
    property real gridSpacing: 10
    property var registry: null
    readonly property Component widgetComponent: root.registry ? root.registry.componentForId(root.widgetId) : null

    property bool animationsReady: false
    property bool isActiveDrag: false
    property real dragStartX: 0
    property real dragStartY: 0
    property real dragOffsetX: 0
    property real dragOffsetY: 0

    readonly property int effectiveCol: BentoModel.isDragging ? root.previewCol : root.col
    readonly property int effectiveRow: BentoModel.isDragging ? root.previewRow : root.row
    readonly property int effectiveColSpan: BentoModel.isDragging ? root.previewColSpan : root.colSpan
    readonly property int effectiveRowSpan: BentoModel.isDragging ? root.previewRowSpan : root.rowSpan

    readonly property real snappedX: root.effectiveCol * (root.cellWidth + root.gridSpacing)
    readonly property real snappedY: root.effectiveRow * (root.cellHeight + root.gridSpacing)
    readonly property real snappedWidth: root.effectiveColSpan * root.cellWidth + Math.max(0, root.effectiveColSpan - 1) * root.gridSpacing
    readonly property real snappedHeight: root.effectiveRowSpan * root.cellHeight + Math.max(0, root.effectiveRowSpan - 1) * root.gridSpacing

    Component.onCompleted: {
        Qt.callLater(() => {
            root.animationsReady = true
        })
    }

    x: root.isActiveDrag ? (root.dragStartX + root.dragOffsetX) : root.snappedX
    y: root.isActiveDrag ? (root.dragStartY + root.dragOffsetY) : root.snappedY
    width: root.snappedWidth
    height: root.snappedHeight

    z: root.isActiveDrag ? 100 : (hoverHandler.hovered || dragHandle.actionsExpanded ? 10 : 1)
    opacity: root.widgetEnabled ? (root.isActiveDrag ? 0.94 : 1.0) : 0.0
    visible: opacity > 0
    scale: root.widgetEnabled ? (root.isActiveDrag ? 1.025 : 1.0) : 0.88

    Behavior on x {
        enabled: root.animationsReady && !root.isActiveDrag
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    Behavior on y {
        enabled: root.animationsReady && !root.isActiveDrag
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    Behavior on width {
        enabled: root.animationsReady
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    Behavior on height {
        enabled: root.animationsReady
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    Behavior on scale {
        enabled: root.animationsReady
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Behavior on opacity {
        enabled: root.animationsReady
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    StyledRectangularShadow {
        target: cardBody
        visible: root.isActiveDrag
    }

    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: "transparent"

        Loader {
            id: contentLoader
            asynchronous: true
            active: root.widgetEnabled
            anchors.fill: parent
            sourceComponent: root.widgetComponent
        }
    }

    BentoDragHandle {
        id: dragHandle
        anchors.top: parent.top
        anchors.margins: 8
        anchors.right: parent.right
        z: 20

        widgetId: root.widgetId
        widgetTitle: root.title
        currentColSpan: root.colSpan
        currentRowSpan: root.rowSpan
        sizePresets: root.presets
        cardHovered: hoverHandler.hovered
        cardDragging: root.isActiveDrag
        gridCanvas: root.parent

        onDragStarted: {
            root.dragStartX = root.x
            root.dragStartY = root.y
            root.dragOffsetX = 0
            root.dragOffsetY = 0
            root.isActiveDrag = true
            BentoModel.beginDrag(root.widgetId)
        }

        onDragMoved: (totalDx, totalDy) => {
            root.dragOffsetX = totalDx
            root.dragOffsetY = totalDy

            const stepW = root.cellWidth + root.gridSpacing
            const stepH = root.cellHeight + root.gridSpacing
            if (stepW > 0 && stepH > 0) {
                const targetC = Math.round(root.x / stepW)
                const targetR = Math.round(root.y / stepH)
                BentoModel.updateDragTarget(targetC, targetR)
            }
        }

        onDragEnded: {
            BentoModel.commitDrag()
            root.isActiveDrag = false
            root.dragOffsetX = 0
            root.dragOffsetY = 0
        }
    }
}
