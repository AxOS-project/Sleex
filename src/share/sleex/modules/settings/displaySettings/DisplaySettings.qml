import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import Sleex.Services
import "."

Item {
    id: root

    implicitHeight: canvas.height + (errorBanner.visible ? errorBanner.height + 8 : 0)
    implicitWidth: canvas.width

    readonly property bool hasPendingChanges: pendingChanges.count > 0

    property string selectedMonitorName: {
        if (Monitors.monitors && Monitors.monitors.length > 0) {
            const focused = Monitors.monitors.find(m => m.primary)
            return focused ? focused.name : Monitors.monitors[0].name
        }
        return ""
    }
    property alias  pendingChanges: pendingChanges

    // Auto-select focused monitor or first monitor on startup
    function ensureSelectedMonitor() {
        if (!Monitors.monitors || Monitors.monitors.length === 0) {
            root.selectedMonitorName = ""
            return
        }
        const exists = Monitors.monitors.some(m => m.name === root.selectedMonitorName)
        if (!exists || root.selectedMonitorName === "") {
            const focused = Monitors.monitors.find(m => m.primary)
            root.selectedMonitorName = focused ? focused.name : Monitors.monitors[0].name
        }
    }

    Component.onCompleted: ensureSelectedMonitor()

    Connections {
        target: Monitors
        function onMonitorsChanged() {
            root.ensureSelectedMonitor()
            root.layoutBounds = root._calcBounds()
        }
        function onApplySucceeded() {
            pendingChanges.clear()
        }
    }

    // Pending changes state store
    QtObject {
        id: pendingChanges
        property var map: ({})
        property int count: 0

        function setPos(name, x, y) {
            let m = Object.assign({}, map)
            if (!m[name]) m[name] = {}
            m[name].x = x
            m[name].y = y
            map = m
            count = Object.keys(m).length
        }

        function setScale(name, scale) {
            let m = Object.assign({}, map)
            if (!m[name]) m[name] = {}
            m[name].scale = scale
            map = m
            count = Object.keys(m).length
        }

        function setMirror(name, mirror) {
            let m = Object.assign({}, map)
            if (!m[name]) m[name] = {}
            m[name].mirror = mirror
            map = m
            count = Object.keys(m).length
        }

        function setMode(name, mode) {
            let m = Object.assign({}, map)
            if (!m[name]) m[name] = {}
            m[name].mode = mode
            map = m
            count = Object.keys(m).length
            root.layoutBounds = root._calcBounds()
        }

        function clear() {
            map = {}
            count = 0
            root.layoutBounds = root._calcBounds()
        }

        function toVariantList() {
            const mons = Monitors.monitors
            if (!mons || mons.length === 0) return []

            let minX = Infinity, minY = Infinity
            for (let i = 0; i < mons.length; i++) {
                const m = mons[i]
                const px = (map[m.name] && map[m.name].x !== undefined) ? map[m.name].x : m.x
                const py = (map[m.name] && map[m.name].y !== undefined) ? map[m.name].y : m.y
                minX = Math.min(minX, px)
                minY = Math.min(minY, py)
            }
            if (minX === Infinity) minX = 0
            if (minY === Infinity) minY = 0

            let result = []
            for (let i = 0; i < mons.length; i++) {
                const m = mons[i]
                const p = map[m.name] || {}
                const hasPending = (map[m.name] !== undefined)

                const rawX = (p.x !== undefined) ? p.x : m.x
                const rawY = (p.y !== undefined) ? p.y : m.y
                const normX = Math.max(0, Math.round(rawX - minX))
                const normY = Math.max(0, Math.round(rawY - minY))

                const posChanged = (normX !== m.x || normY !== m.y)
                const scaleChanged = (p.scale !== undefined && Math.abs(p.scale - m.scale) > 0.001)
                const modeChanged = (p.mode !== undefined && p.mode !== (m.width + "x" + m.height))
                const mirrorChanged = (p.mirror !== undefined && p.mirror !== m.mirrorOf)

                if (hasPending || posChanged || scaleChanged || modeChanged || mirrorChanged) {
                    let obj = { name: m.name, x: normX, y: normY }
                    if (p.scale !== undefined) obj.scale = p.scale
                    if (p.mode !== undefined) obj.mode = p.mode
                    if (p.mirror !== undefined) obj.mirror = p.mirror
                    result.push(obj)
                }
            }
            return result
        }
    }

    // Centering & Scaling Bounds
    property var layoutBounds: _calcBounds()

    function _calcBounds() {
        const mons = Monitors.monitors
        if (!mons || mons.length === 0) {
            return { minX: 0, minY: 0, scaleF: 0.08, offsetX: 32, offsetY: 32 }
        }

        let minX = Infinity, minY = Infinity
        let maxX = -Infinity, maxY = -Infinity

        for (let i = 0; i < mons.length; i++) {
            const m = mons[i]
            const p = pendingChanges.map[m.name] || {}
            const px = (p.x !== undefined) ? p.x : m.x
            const py = (p.y !== undefined) ? p.y : m.y

            let pw = m.width
            let ph = m.height
            if (p.mode) {
                const parts = p.mode.split("x")
                if (parts.length === 2) {
                    pw = parseInt(parts[0]) || m.width
                    ph = parseInt(parts[1]) || m.height
                }
            }

            minX = Math.min(minX, px)
            minY = Math.min(minY, py)
            maxX = Math.max(maxX, px + pw)
            maxY = Math.max(maxY, py + ph)
        }

        const totalW = Math.max(1, maxX - minX)
        const totalH = Math.max(1, maxY - minY)

        const availW = Math.max(100, (canvas ? canvas.width : 500) - 64)
        const availH = Math.max(100, (canvas ? canvas.height : 300) - 64)

        const sx = availW / totalW
        const sy = availH / totalH
        const scaleF = Math.min(sx, sy, 0.11)

        const contentW = totalW * scaleF
        const contentH = totalH * scaleF

        const offsetX = Math.max(16, ((canvas ? canvas.width : 500) - contentW) / 2)
        const offsetY = Math.max(16, ((canvas ? canvas.height : 300) - contentH) / 2)

        return { minX: minX, minY: minY, scaleF: scaleF, offsetX: offsetX, offsetY: offsetY }
    }

    onWidthChanged: layoutBounds = _calcBounds()

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Error Banner
        Rectangle {
            id: errorBanner
            Layout.fillWidth: true
            visible: Monitors.lastError !== ""
            implicitHeight: errorRow.implicitHeight + 14
            radius: Appearance.rounding.small
            color: "#30FF4444"
            border.color: "#60FF4444"
            border.width: 1

            RowLayout {
                id: errorRow
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                MaterialSymbol {
                    text: "warning"
                    iconSize: 20
                    color: "#FF6666"
                }

                StyledText {
                    text: Monitors.lastError
                    color: "#FF8888"
                    font.pixelSize: Appearance.font.pixelSize.small
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }

        // Arrangement Canvas
        Rectangle {
            id: canvas
            Layout.fillWidth: true
            Layout.preferredHeight: 310
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            border.color: Appearance.colors.colOutlineVariant
            border.width: 1
            clip: true

            // Center crosshair guidelines
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 1
                color: Appearance.colors.colOutlineVariant
                opacity: 0.18
            }
            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: parent.height
                color: Appearance.colors.colOutlineVariant
                opacity: 0.18
            }

            // Magnetic snap guidelines
            Rectangle {
                id: hSnapLine
                visible: false
                color: Appearance.colors.colPrimary
                height: 1
                width: parent.width
                z: 40
                opacity: 0.8
            }

            Rectangle {
                id: vSnapLine
                visible: false
                color: Appearance.colors.colPrimary
                width: 1
                height: parent.height
                z: 40
                opacity: 0.8
            }

            // Snap Ghost Preview Box
            Rectangle {
                id: snapGhostGuide
                visible: false
                color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.14)
                border.color: Appearance.colors.colPrimary
                border.width: 1.5
                radius: 8
                z: 35

                Behavior on x { NumberAnimation { duration: 60 } }
                Behavior on y { NumberAnimation { duration: 60 } }
            }

            Item {
                id: tileRoot
                anchors.fill: parent

                Repeater {
                    id: monitorRepeater
                    model: Monitors.monitors

                    delegate: MonitorTile {
                        required property var modelData
                        required property int index

                        monitorInfo: modelData
                        monitorIndex: index
                        tileParent: tileRoot
                        allTiles: monitorRepeater

                        isSelected: root.selectedMonitorName === modelData.name
                        isPending: pendingChanges.map[modelData.name] !== undefined
                        isMirroring: {
                            const p = pendingChanges.map[modelData.name]
                            if (p && p.mirror !== undefined) return p.mirror !== ""
                            return (modelData.mirrorOf !== "")
                        }
                        mirrorTarget: {
                            const p = pendingChanges.map[modelData.name]
                            if (p && p.mirror !== undefined) return p.mirror
                            return modelData.mirrorOf
                        }
                        isFocused: modelData.primary

                        realX: {
                            const p = pendingChanges.map[modelData.name]
                            return (p && p.x !== undefined) ? p.x : modelData.x
                        }
                        realY: {
                            const p = pendingChanges.map[modelData.name]
                            return (p && p.y !== undefined) ? p.y : modelData.y
                        }
                        realWidth: {
                            const p = pendingChanges.map[modelData.name]
                            if (p && p.mode) {
                                const parts = p.mode.split("x")
                                if (parts.length === 2) return parseInt(parts[0]) || modelData.width
                            }
                            return modelData.width
                        }
                        realHeight: {
                            const p = pendingChanges.map[modelData.name]
                            if (p && p.mode) {
                                const parts = p.mode.split("x")
                                if (parts.length === 2) return parseInt(parts[1]) || modelData.height
                            }
                            return modelData.height
                        }
                        realScale: {
                            const p = pendingChanges.map[modelData.name]
                            return (p && p.scale !== undefined) ? p.scale : modelData.scale
                        }

                        canvasScaleF: root.layoutBounds.scaleF
                        canvasOrigin: Qt.point(root.layoutBounds.minX, root.layoutBounds.minY)
                        canvasOffsetX: root.layoutBounds.offsetX
                        canvasOffsetY: root.layoutBounds.offsetY

                        onClicked: {
                            root.selectedMonitorName = modelData.name
                        }

                        onDragCommitted: (name, rx, ry) => {
                            pendingChanges.setPos(name, rx, ry)
                            root.layoutBounds = root._calcBounds()
                        }

                        onSnapGuideUpdate: (visible, cx, cy, cw, ch, guideType) => {
                            snapGhostGuide.visible = visible
                            if (visible) {
                                snapGhostGuide.x = cx
                                snapGhostGuide.y = cy
                                snapGhostGuide.width = cw
                                snapGhostGuide.height = ch
                            }
                        }

                        onSnapLineUpdate: (showH, hy, showV, vx) => {
                            hSnapLine.visible = showH
                            if (showH) hSnapLine.y = hy

                            vSnapLine.visible = showV
                            if (showV) vSnapLine.x = vx
                        }
                    }
                }
            }

            // Floating Snackbar (Discord style)
            Rectangle {
                id: floatingSnackbar
                anchors.bottom: canvas.bottom
                anchors.bottomMargin: 14
                anchors.horizontalCenter: canvas.horizontalCenter
                width: canvas.width - 32
                height: 48
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer2
                border.color: Appearance.colors.colOutlineVariant
                border.width: 1
                z: 100

                visible: opacity > 0
                opacity: root.hasPendingChanges ? 1 : 0
                y: root.hasPendingChanges ? (canvas.height - height - 14) : canvas.height

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10

                    MaterialSymbol {
                        text: "warning"
                        iconSize: 20
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: qsTr("Careful, you have unsaved changes!")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        elide: Text.ElideRight 
                        color: Appearance.colors.colOnLayer2
                    }

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        buttonRadius: Appearance.rounding.small
                        height: 32
                        width: 76
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Reset")
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                        }
                        onClicked: root.applyReset()
                    }

                    RippleButtonWithIcon {
                        materialIcon: "check"
                        mainText: qsTr("Apply")
                        implicitHeight: 32
                        colBackground: Appearance.colors.colPrimary
                        colText: Appearance.colors.colOnPrimary
                        onClicked: {
                            Monitors.applyChanges(pendingChanges.toVariantList())
                            pendingChanges.clear()
                        }
                    }
                }
            }
        }
    }

    function applyReset() {
        pendingChanges.clear()
        Monitors.resetPositions()
        root.layoutBounds = root._calcBounds()
    }
}
