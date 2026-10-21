import QtQuick
import QtQuick.Layouts
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import Sleex.Utils

Rectangle {
    id: root

    property string widgetId: ""
    property string widgetTitle: ""
    property int currentColSpan: 1
    property int currentRowSpan: 2
    property var sizePresets: []
    property bool cardHovered: false
    property bool cardDragging: false
    property Item gridCanvas: null

    property bool actionsExpanded: false
    readonly property bool isExpanded: (root.actionsExpanded || BentoModel.customizeOpen) && !root.cardDragging
    readonly property bool handleShown: root.cardHovered || root.cardDragging || root.actionsExpanded || BentoModel.customizeOpen

    signal dragStarted()
    signal dragMoved(real totalDx, real totalDy)
    signal dragEnded()

    onCardHoveredChanged: {
        if (!root.cardHovered && !root.cardDragging) {
            collapseTimer.restart()
        } else {
            collapseTimer.stop()
        }
    }

    Timer {
        id: collapseTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!root.cardHovered && !root.cardDragging) {
                root.actionsExpanded = false
            }
        }
    }

    implicitWidth: gripArea.implicitWidth + actionsRevealer.implicitWidth + 12
    implicitHeight: 28
    radius: Appearance.rounding.full
    color: root.cardDragging ? Appearance.colors.colPrimary : (root.isExpanded ? Appearance.colors.colLayer1 : "transparent")
    opacity: root.handleShown ? 1.0 : 0.0
    visible: opacity > 0
    transformOrigin: Item.Right
    scale: root.cardDragging ? 1.06 : (root.handleShown ? 1.0 : 0.9)
    border.width: root.isExpanded ? 1 : 0
    border.color: Appearance.colors.colOutlineVariant

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Appearance.animation.elementMoveFast.duration
        }
    }

    Revealer {
        id: actionsRevealer
        anchors.right: gripArea.left
        anchors.verticalCenter: parent.verticalCenter
        reveal: root.isExpanded
        vertical: false

        RowLayout {
            spacing: 3

            Repeater {
                model: root.sizePresets
                delegate: RippleButton {
                    readonly property bool isCurrentSize: modelData.colSpan === root.currentColSpan && modelData.rowSpan === root.currentRowSpan

                    implicitHeight: 20
                    implicitWidth: presetLabel.implicitWidth + 10
                    buttonRadius: Appearance.rounding.full
                    toggled: isCurrentSize
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colBackgroundToggled: Appearance.colors.colPrimary

                    onClicked: {
                        BentoModel.resizeWidget(root.widgetId, modelData.colSpan, modelData.rowSpan)
                    }

                    contentItem: StyledText {
                        id: presetLabel
                        text: modelData.label
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    }
                }
            }

            RippleButton {
                implicitWidth: 22
                implicitHeight: 20
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colErrorContainer ?? Appearance.colors.colLayer1Hover

                onClicked: {
                    root.actionsExpanded = false
                    BentoModel.setWidgetEnabled(root.widgetId, false)
                }

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "visibility_off"
                    iconSize: 13
                    color: Appearance.colors.colOnLayer1
                }

                StyledToolTip {
                    text: qsTr("Hide widget")
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 14
                Layout.leftMargin: 1
                Layout.rightMargin: 4
                color: Appearance.colors.colOutlineVariant
            }
        }
    }

    Item {
        id: gripArea
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: gripRow.implicitWidth + 8
        implicitHeight: 24

        RowLayout {
            id: gripRow
            anchors.centerIn: parent
            spacing: 3

            MaterialSymbol {
                text: "drag_indicator"
                iconSize: 16
                color: root.cardDragging ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
            }
        }

        DragManager {
            id: dragManager
            anchors.fill: parent
            automaticallyReset: false
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: root.cardDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property point pressCanvasPos: Qt.point(0, 0)
            property bool dragSessionActive: false

            onPressed: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    root.actionsExpanded = !root.actionsExpanded
                    mouse.accepted = true
                    return
                }
                const targetCanvas = root.gridCanvas ?? root.parent?.parent
                if (targetCanvas) {
                    pressCanvasPos = dragManager.mapToItem(targetCanvas, mouse.x, mouse.y)
                }
                dragSessionActive = false
            }

            onDragPressed: (diffX, diffY) => {
                const targetCanvas = root.gridCanvas ?? root.parent?.parent
                if (!targetCanvas) return

                const curCanvasPos = dragManager.mapToItem(targetCanvas, dragManager.mouseX, dragManager.mouseY)
                const totalDx = curCanvasPos.x - pressCanvasPos.x
                const totalDy = curCanvasPos.y - pressCanvasPos.y
                const totalDist = Math.hypot(totalDx, totalDy)

                if (!dragSessionActive && totalDist > 5) {
                    dragSessionActive = true
                    root.actionsExpanded = false
                    root.dragStarted()
                }

                if (dragSessionActive) {
                    root.dragMoved(totalDx, totalDy)
                }
            }

            onDragReleased: (diffX, diffY) => {
                if (dragSessionActive) {
                    dragSessionActive = false
                    root.dragEnded()
                } else {
                    root.actionsExpanded = !root.actionsExpanded
                }
                resetDrag()
            }
        }
    }
}
