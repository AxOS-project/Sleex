import QtQuick
import Sleex.Widgets
import SleexUiKit.Appearance
import qs.modules.common
import qs


MouseArea {
    id: root
    focus: true 
    property int gridSize: 24
    property bool showGrid: false
    readonly property bool isWidgetCanvas: true
    readonly property bool gridVisible: showGrid && Config.options.background.showGrid

    property bool centerXActive: false
    property bool centerYActive: false

    property var registeredWidgets: []
    property bool selecting: false
    property point selectionStartPoint: Qt.point(0, 0)
    property rect selectionRect: Qt.rect(0, 0, 0, 0)

    property var groupDragMemberStarts: []
    property real groupDragStartX: 0
    property real groupDragStartY: 0

    function deleteSelected() {
        const toDelete = root.registeredWidgets.filter(w => w.selected)
        for (const widget of toDelete) widget.requestDelete()
        root.clearSelection()
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.deleteSelected()
            event.accepted = true
        }
    }

    function setDragging(active) {
        root.showGrid = active
        if (!active) {
            root.centerXActive = false
            root.centerYActive = false
        }
    }

    function setCenterActive(xActive, yActive) {
        root.centerXActive = xActive
        root.centerYActive = yActive
    }

    function registerWidget(widget) {
        root.registeredWidgets = root.registeredWidgets.concat([widget])
    }

    function unregisterWidget(widget) {
        root.registeredWidgets = root.registeredWidgets.filter(w => w !== widget)
    }

    function bringToFront(widget) {
        if (widget.pinnedBottom) return
        let maxZ = 0
        for (const w of root.registeredWidgets) {
            if (w !== widget && !w.pinnedBottom && w.z > maxZ) maxZ = w.z
        }
        widget.z = maxZ + 1
    }

    function clearSelection() {
        for (const widget of root.registeredWidgets) widget.selected = false
    }

    function rectsIntersect(a, b) {
        return a.x < b.x + b.width && a.x + a.width > b.x
            && a.y < b.y + b.height && a.y + a.height > b.y
    }

    function selectWithinRect(rect) {
        for (const widget of root.registeredWidgets) {
            const widgetRect = Qt.rect(widget.x, widget.y, widget.width, widget.height)
            widget.selected = root.rectsIntersect(rect, widgetRect)
        }
    }

    function beginGroupDrag(initiator) {
        if (!initiator.selected) {
            root.groupDragMemberStarts = []
            return
        }
        root.groupDragStartX = initiator.x
        root.groupDragStartY = initiator.y
        root.groupDragMemberStarts = root.registeredWidgets
            .filter(w => w.selected && w !== initiator)
            .map(w => ({ widget: w, startX: w.x, startY: w.y }))
        for (const entry of root.groupDragMemberStarts) entry.widget.groupDragActive = true
    }

    function updateGroupDrag(initiator) {
        if (root.groupDragMemberStarts.length === 0) return
        const dx = initiator.x - root.groupDragStartX
        const dy = initiator.y - root.groupDragStartY
        for (const entry of root.groupDragMemberStarts) {
            entry.widget.x = entry.startX + dx
            entry.widget.y = entry.startY + dy
        }
    }

    function endGroupDrag() {
        for (const entry of root.groupDragMemberStarts) {
            entry.widget.groupDragActive = false
            entry.widget.commitPosition()
        }
        root.groupDragMemberStarts = []
    }

    onPressed: (mouse) => {
        if (Config.options.background.widgetsLocked) return
        GlobalStates.desktopWidgetKeyboardFocus = true 
        root.forceActiveFocus() 
        root.selecting = true
        root.selectionStartPoint = Qt.point(mouse.x, mouse.y)
        root.selectionRect = Qt.rect(mouse.x, mouse.y, 0, 0)
        if (!(mouse.modifiers & Qt.ControlModifier)) root.clearSelection()
    }

    onActiveFocusChanged: {
        if (!root.activeFocus) GlobalStates.desktopWidgetKeyboardFocus = false
    }

    onPositionChanged: (mouse) => {
        if (!root.selecting) return
        const startX = root.selectionStartPoint.x
        const startY = root.selectionStartPoint.y
        const rectX = Math.min(startX, mouse.x)
        const rectY = Math.min(startY, mouse.y)
        const rectW = Math.abs(mouse.x - startX)
        const rectH = Math.abs(mouse.y - startY)
        root.selectionRect = Qt.rect(rectX, rectY, rectW, rectH)
        root.selectWithinRect(root.selectionRect)
    }

    onReleased: {
        root.selecting = false
    }

    Repeater {
        id: crossRepeater
        readonly property int cols: Math.ceil(root.width / root.gridSize) + 1
        readonly property int rows: Math.ceil(root.height / root.gridSize) + 1
        model: root.gridVisible ? cols * rows : 0
        delegate: Item {
            id: crossPoint
            required property int index
            readonly property int col: index % crossRepeater.cols
            readonly property int row: Math.floor(index / crossRepeater.cols)
            readonly property int crossSize: 5

            x: col * root.gridSize - crossSize / 2
            y: row * root.gridSize - crossSize / 2
            width: crossSize
            height: crossSize

            Rectangle {
                anchors.centerIn: parent
                width: crossPoint.crossSize
                height: crossPoint.crossSize
                color: Appearance.colors.colLayer0Border
                radius: 99
                opacity: 0.6

                NumberAnimation on opacity {
                    from: 0
                    to: 0.6
                    duration: 150
                }
            }
        }
    }

    Rectangle {
        id: centerLineV
        visible: root.gridVisible
        x: root.width / 2 - width / 2
        width: root.centerXActive ? 2 : 1
        height: root.height
        color: root.centerXActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
        opacity: root.gridVisible ? (root.centerXActive ? 1 : 0.6) : 0

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on width {
            NumberAnimation { duration: 150 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    Rectangle {
        id: centerLineH
        visible: root.gridVisible
        y: root.height / 2 - height / 2
        width: root.width
        height: root.centerYActive ? 2 : 1
        color: root.centerYActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
        opacity: root.gridVisible ? (root.centerYActive ? 1 : 0.6) : 0

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on height {
            NumberAnimation { duration: 150 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }
}