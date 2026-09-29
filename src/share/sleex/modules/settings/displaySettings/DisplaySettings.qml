import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import Sleex.Services

Item {
    id: root
    implicitHeight: canvas.height + controlBar.height + selectedMonitorDetails.height + 48
    implicitWidth:  canvas.width

    Behavior on implicitHeight { NumberAnimation { duration: 150 } }

    readonly property bool hasPendingChanges: pendingChanges.count > 0

    property string selectedMonitorName: ""

    QtObject {
        id: pendingChanges
        property var map:   ({})
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
        }
        function clear() {
            map   = {}
            count = 0
        }
        function toVariantList() {
            let result = []
            for (let name in map) {
                let obj = { name: name }
                if (map[name].x !== undefined) obj.x = map[name].x
                if (map[name].y !== undefined) obj.y = map[name].y
                if (map[name].scale !== undefined) obj.scale = map[name].scale
                if (map[name].mode !== undefined) obj.mode = map[name].mode
                if (map[name].mirror !== undefined) obj.mirror = map[name].mirror
                result.push(obj)
            }
            return result
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            visible: Monitors.lastError !== ""
            height:  visible ? errorRow.implicitHeight + 16 : 0
            radius:  6
            color:   "#40FF4444"

            RowLayout {
                id: errorRow
                anchors { fill: parent; margins: 8 }
                spacing: 8
                StyledText {
                    text:  "⚠ " + Monitors.lastError
                    color: "#FF6666"
                    font.pixelSize: Appearance.font.pixelSize.small
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            id: canvas
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            radius: Appearance.rounding.normal
            color:  Appearance.colors.colLayer1
            clip:   true

            Rectangle {
                anchors.fill: parent
                visible:  Monitors.busy
                color:    "#80000000"
                radius:   parent.radius
                z:        99

                BusyIndicator { anchors.centerIn: parent; running: Monitors.busy }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: Monitors.monitors.length === 0 && !Monitors.busy

                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "desktop_access_disabled"
                    font.pixelSize: 48
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No monitors detected"
                    color: Appearance.colors.colSubtext
                }
            }

            Item {
                id: tileRoot
                anchors.fill: parent
                anchors.margins: 16

                // Snap guide
                Rectangle {
                    id: snapGuide
                    visible:  false
                    color:    "transparent"
                    border.color: Appearance.colors.colPrimary
                    border.width: 2
                    radius:   4
                    z:        50
                    opacity:  0.8

                    Behavior on x { NumberAnimation { duration: 80 } }
                    Behavior on y { NumberAnimation { duration: 80 } }
                }

                property real scaleF:   _scaleF()
                property point origin:  _origin()

                function _scaleF() {
                    const mons = Monitors.monitors
                    if (!mons || mons.length === 0) return 1/20
                    let minX = Infinity, minY = Infinity
                    let maxX = -Infinity, maxY = -Infinity
                    for (let m of mons) {
                        minX = Math.min(minX, m.x)
                        minY = Math.min(minY, m.y)
                        maxX = Math.max(maxX, m.x + m.width)
                        maxY = Math.max(maxY, m.y + m.height)
                    }
                    const wTotal = maxX - minX
                    const hTotal = maxY - minY
                    const sx = wTotal > 0 ? (tileRoot.width  - 0) / wTotal : 1/20
                    const sy = hTotal > 0 ? (tileRoot.height - 0) / hTotal : 1/20
                    return Math.min(sx, sy, 1/12)
                }

                function _origin() {
                    const mons = Monitors.monitors
                    if (!mons || mons.length === 0) return Qt.point(0, 0)
                    let minX = Infinity, minY = Infinity
                    for (let m of mons) {
                        minX = Math.min(minX, m.x)
                        minY = Math.min(minY, m.y)
                    }
                    return Qt.point(minX, minY)
                }

                // Convert real pixel coords → canvas coords
                function toCanvas(px, py) {
                    return Qt.point(
                        (px - origin.x) * scaleF,
                        (py - origin.y) * scaleF
                    )
                }

                // Convert canvas coords → real pixel coords
                function toReal(cx, cy) {
                    return Qt.point(
                        Math.round(cx / scaleF + origin.x),
                        Math.round(cy / scaleF + origin.y)
                    )
                }

                Repeater {
                    id: monitorRepeater
                    model: Monitors.monitors

                    delegate: MonitorTile {
                        required property var  modelData
                        required property int  index

                        isSelected: selectedMonitorName === modelData.name
                        onClicked: {
                            if (root.selectedMonitorName === modelData.name) {
                                root.selectedMonitorName = ""
                            } else {
                                root.selectedMonitorName = modelData.name
                            }
                        }
                        onIsSelectedChanged: {
                            if (isSelected) root.selectedMonitorName = monitorInfo.name
                        }

                        monitorInfo: modelData
                        canvasScaleF: tileRoot.scaleF
                        origin:       tileRoot.origin
                        isPending:    pendingChanges.map[modelData.name] !== undefined
                        tileParent:   tileRoot
                        allTiles:     monitorRepeater

                        onDragCommitted: (name, cx, cy) => {
                            const real = tileRoot.toReal(cx, cy)
                            pendingChanges.setPos(name, real.x, real.y)
                        }
                        onSnapGuideUpdate: (visible, cx, cy, cw, ch) => {
                            snapGuide.visible = visible
                            if (visible) {
                                snapGuide.x = cx; snapGuide.y = cy
                                snapGuide.width = cw; snapGuide.height = ch
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: selectedMonitorDetails
            Layout.fillWidth: true
            visible: root.selectedMonitorName !== ""
            height: optionsRow.implicitHeight
            color: 'transparent'

            Behavior on height { NumberAnimation { duration: 150 } }

            ConfigRow {
                id: optionsRow
                anchors.fill: parent

                ConfigSpinBox {
                    id: scaleSpinBox
                    from: 25; to: 300; stepSize: 25
                    fillWidth: false
                    value: {
                        const m = Monitors.monitors.find(m => m.name === root.selectedMonitorName)
                        return m ? Math.round(m.scale * 100) : 100
                    }
                    text: "Scale"
                    onValueChanged: {
                        const m = Monitors.monitors.find(m => m.name === root.selectedMonitorName)
                        if (m && Math.round(m.scale * 100) !== value) {
                            pendingChanges.setScale(root.selectedMonitorName, value / 100.0)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                IconComboBox {
                    id: mirrorCombo
                    icon: "tv_displays"
                    model: {
                        const others = Monitors.monitors
                            .filter(m => m.name !== root.selectedMonitorName)
                            .map(m => m.name)
                        return ["None", ...others]
                    }

                    currentIndex: {
                        const mon = Monitors.monitors.find(m => m.name === root.selectedMonitorName)
                        if (!mon || !mon.mirrorOf) return 0
                        const idx = model.indexOf(mon.mirrorOf)
                        return idx >= 0 ? idx : 0
                    }

                    onCurrentIndexChanged: {
                        if (currentIndex < 0) return
                        const m = Monitors.monitors.find(m => m.name === root.selectedMonitorName)
                        if (!m) return
                        const target = model[currentIndex]
                        const actualMirror = target === "None" ? "" : target
                        if (m.mirrorOf !== actualMirror) {
                            pendingChanges.setMirror(root.selectedMonitorName, actualMirror)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                IconComboBox {
                    id: resolutionCombo
                    icon: "display_settings"
                    model: {
                        const m = Monitors.monitors.find(m => m.name === root.selectedMonitorName)
                        return m ? m.availableModes : []
                    }
                    currentIndex: {
                        const m = Monitors.monitors.find(m => m.name === root.selectedMonitorName)
                        if (!m) return 0
                        return Math.max(0, model.indexOf(m.width + "x" + m.height))
                    }
                    onCurrentIndexChanged: {
                        if (currentIndex < 0) return
                        const m = Monitors.monitors.find(m => m.name === root.selectedMonitorName)
                        if (!m) return
                        const modeStr = m.width + "x" + m.height
                        if (modeStr !== model[currentIndex]) {
                            pendingChanges.setMode(root.selectedMonitorName, model[currentIndex])
                        }
                    }
                }
            }
        }

        RowLayout {
            id: controlBar
            Layout.fillWidth: true
            spacing: 8
            Layout.alignment: Qt.AlignHCenter

            RippleButtonWithIcon {
                materialIcon: "view_week"
                mainText:  "Horizontal"
                onClicked: root.applyPresetHorizontal()
            }

            RippleButtonWithIcon {
                materialIcon: "view_agenda"
                mainText:  "Vertical"
                onClicked: root.applyPresetVertical()
            }

            RippleButtonWithIcon {
                enabled: root.hasPendingChanges
                materialIcon: "cancel"
                mainText:  "Discard"
                onClicked: {
                    pendingChanges.clear()
                    Monitors.resetPositions()
                }
            }
            RippleButtonWithIcon {
                enabled: root.hasPendingChanges
                materialIcon: "check_circle"
                mainText:  "Apply"
                onClicked: {
                    Monitors.applyChanges(pendingChanges.toVariantList())
                    pendingChanges.clear()
                }
            }
        }
    }

    Connections {
        target: Monitors
        function onApplySucceeded() { pendingChanges.clear() }
    }

    function applyPresetHorizontal() {
        const mons = Monitors.monitors
        if (mons.length < 2) return
        let cursor = 0
        let changes = []
        for (let m of mons) {
            changes.push({ name: m.name, x: cursor, y: 0 })
            cursor += m.width
        }
        Monitors.applyChanges(changes)
    }

    function applyPresetVertical() {
        const mons = Monitors.monitors
        if (mons.length < 2) return
        let cursor = 0
        let changes = []
        for (let m of mons) {
            changes.push({ name: m.name, x: 0, y: cursor })
            cursor += m.height
        }
        Monitors.applyChanges(changes)
    }
}
