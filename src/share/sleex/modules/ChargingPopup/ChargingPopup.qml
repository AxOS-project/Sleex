import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property real   pct:     0
    property int    _lastAc: -1
    property int    _tick:   0

    property string battCapacityPath: ""
    property string acOnlinePath:     ""
    property bool   ready:            false

    Process {
        id: detectBatt
        running: true
        command: [
            "bash", "-c",
            "for d in /sys/class/power_supply/*/; do " +
            "  t=$(cat \"$d/type\" 2>/dev/null); " +
            "  [ \"$t\" = \"Battery\" ] && echo \"${d}capacity\" && break; " +
            "done"
        ]
        stdout: SplitParser {
            onRead: function(data) {
                var p = data.trim()
                if (p) { root.battCapacityPath = p; root._checkReady() }
            }
        }
    }

    Process {
        id: detectAc
        running: true
        command: [
            "bash", "-c",
            "for d in /sys/class/power_supply/*/; do " +
            "  t=$(cat \"$d/type\" 2>/dev/null); " +
            "  case \"$t\" in Mains|USB|USB_PD|USB_PD_DRP|USB_C) " +
            "    echo \"${d}online\" && break;; esac; " +
            "done"
        ]
        stdout: SplitParser {
            onRead: function(data) {
                var p = data.trim()
                if (p) { root.acOnlinePath = p; root._checkReady() }
            }
        }
    }

    function _checkReady() {
        if (battCapacityPath !== "" && acOnlinePath !== "") {
            ready = true
            catCapacity.running = true
            catAc.running = true
        }
    }

    Process {
        id: catCapacity
        command: ["cat", root.battCapacityPath]
        running: false
        stdout: SplitParser {
            onRead: function(data) {
                var v = parseInt(data.trim())
                if (!isNaN(v)) root.pct = v
            }
        }
    }

    Process {
        id: catAc
        command: ["cat", root.acOnlinePath]
        running: false
        stdout: SplitParser {
            onRead: function(data) {
                var v = parseInt(data.trim())
                if (isNaN(v)) return
                var changed = root._lastAc !== -1 && root._lastAc !== v
                root._lastAc = v
                if (changed && v === 1) {
                    catCapacity.running = false
                    catCapacity.running = true
                    win.triggerShow()
                }
            }
        }
    }

    Timer {
        interval: 1000; running: root.ready; repeat: true
        onTriggered: {
            catAc.running = false
            catAc.running = true
            root._tick++
            if (root._tick % 5 === 0) {
                catCapacity.running = false
                catCapacity.running = true
            }
        }
    }

    function waveColor(p) {
        if (p < 20) return { r: 1.0, g: 0.20, b: 0.20 }
        if (p < 50) return { r: 1.0, g: 0.60, b: 0.10 }
        return             { r: 0.0, g: 1.0,  b: 0.50 }
    }

    PanelWindow {
        id: dimWin
        visible: true
        aboveWindows: true
        exclusiveZone: -1
        anchors.top: true; anchors.bottom: true
        anchors.left: true; anchors.right: true
        color: "transparent"
        mask: Region {}

        property real dimOpacity: 0.0

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: dimWin.dimOpacity
        }

        NumberAnimation {
            id: dimFadeIn
            target: dimWin; property: "dimOpacity"
            from: 0.0; to: 0.45; duration: 750
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: dimFadeOut
            target: dimWin; property: "dimOpacity"
            to: 0.0; duration: 750
            easing.type: Easing.InCubic
        }
    }

    PanelWindow {
        id: win
        visible: false
        aboveWindows: true
        exclusiveZone: -1
        width: 360; height: 360
        color: "transparent"

        property real showOpacity: 0.0
        property real showScale:   0.0

        function triggerShow() {
            morphOut.stop(); morphIn.stop(); dimFadeOut.stop()
            showOpacity = 0.0; showScale = 0.0; dimWin.dimOpacity = 0.0
            dimFadeIn.start()
            visible = true
            frameDelay.restart()
        }

        Timer {
            id: frameDelay; interval: 16
            onTriggered: { morphIn.start(); holdTimer.restart() }
        }

        Timer {
            id: holdTimer; interval: 6000
            onTriggered: morphOut.start()
        }

        ParallelAnimation {
            id: morphIn
            NumberAnimation {
                target: win; property: "showOpacity"
                from: 0.0; to: 1.0; duration: 850
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: win; property: "showScale"
                from: 0.04; to: 1.0; duration: 950
                easing.type: Easing.OutBack; easing.overshoot: 0.55
            }
        }

        SequentialAnimation {
            id: morphOut
            ParallelAnimation {
                NumberAnimation {
                    target: win; property: "showOpacity"
                    to: 0.0; duration: 850
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: win; property: "showScale"
                    to: 0.04; duration: 950
                    easing.type: Easing.InBack; easing.overshoot: 0.55
                }
            }
            ScriptAction {
                script: { win.visible = false; dimFadeOut.start() }
            }
        }

        ListModel {
            id: particleModel
            Component.onCompleted: {
                var cx = 180, cy = 180
                for (var i = 0; i < 100; i++) {
                    var angle  = Math.random() * Math.PI * 2
                    var outerR = 145 + Math.random() * 15
                    var innerR = 5   + Math.random() * 60
                    var perp   = (Math.random() - 0.5) * 50
                    var dur    = 2500 + Math.random() * 4500
                    var delay  = Math.random() * 5500
                    var sz     = 1.5 + Math.random() * 2.5
                    var fadeAt = 0.2 + Math.random() * 0.7
                    var dx = Math.cos(angle), dy = Math.sin(angle)
                    var midR = (outerR + innerR) / 2
                    append({
                        startX: cx + dx * outerR,
                        startY: cy + dy * outerR,
                        midX:   cx + dx * midR + (-dy) * perp,
                        midY:   cy + dy * midR + dx    * perp,
                        endX:   cx + dx * innerR,
                        endY:   cy + dy * innerR,
                        dur: dur, delay: delay, sz: sz, fadeAt: fadeAt
                    })
                }
            }
        }

        Item {
            anchors.fill: parent
            opacity: win.showOpacity
            scale: win.showScale
            transformOrigin: Item.Center

            Canvas {
                width: 360; height: 360

                property real phase:    0.0
                property real phase2:   0.0
                property real fillFrac: root.pct / 100.0

                Behavior on fillFrac {
                    NumberAnimation { duration: 1000; easing.type: Easing.OutCubic }
                }

                NumberAnimation on phase {
                    from: 0; to: Math.PI * 2; duration: 2800
                    loops: Animation.Infinite; easing.type: Easing.Linear
                    running: win.visible
                }
                NumberAnimation on phase2 {
                    from: 0; to: Math.PI * 2; duration: 3600
                    loops: Animation.Infinite; easing.type: Easing.Linear
                    running: win.visible
                }

                onPhaseChanged:    requestPaint()
                onPhase2Changed:   requestPaint()
                onFillFracChanged: requestPaint()

                onPaint: {
                    var c   = getContext("2d")
                    var cx  = width  / 2
                    var cy  = height / 2
                    var rad = width  / 2 - 2
                    var w   = width, h = height

                    c.clearRect(0, 0, w, h)
                    c.save()
                    c.beginPath()
                    c.arc(cx, cy, rad, 0, Math.PI * 2)
                    c.clip()

                    c.fillStyle = Qt.rgba(0.04, 0.04, 0.06, 0.55)
                    c.fillRect(0, 0, w, h)

                    var base = h * (1.0 - fillFrac)
                    var col  = root.waveColor(root.pct)

                    c.beginPath()
                    c.moveTo(0, h)
                    for (var x = 0; x <= w; x += 2)
                        c.lineTo(x, base + Math.sin(x / w * Math.PI * 6 + phase) * 9)
                    c.lineTo(w, h); c.closePath()
                    var g1 = c.createLinearGradient(0, base - 30, 0, h)
                    g1.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.75))
                    g1.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0.95))
                    c.fillStyle = g1; c.fill()

                    c.beginPath()
                    c.moveTo(0, h)
                    for (var x2 = 0; x2 <= w; x2 += 2)
                        c.lineTo(x2, base + 7 + Math.sin(x2 / w * Math.PI * 6 + phase2 + 1.6) * 6)
                    c.lineTo(w, h); c.closePath()
                    var g2 = c.createLinearGradient(0, base, 0, h)
                    g2.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.40))
                    g2.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0.62))
                    c.fillStyle = g2; c.fill()

                    c.restore()
                    c.beginPath()
                    c.arc(cx, cy, rad, 0, Math.PI * 2)
                    c.strokeStyle = Qt.rgba(1, 1, 1, 0.80)
                    c.lineWidth   = 3.5
                    c.stroke()
                }
            }

            Repeater {
                model: particleModel
                delegate: Rectangle {
                    id: ptcl
                    width: model.sz; height: model.sz
                    radius: model.sz / 2
                    color: "white"; opacity: 0
                    x: model.startX - model.sz / 2
                    y: model.startY - model.sz / 2
                    z: 5

                    SequentialAnimation {
                        running: win.visible

                        PauseAnimation { duration: model.delay }

                        ParallelAnimation {
                            NumberAnimation {
                                target: ptcl; property: "opacity"
                                from: 0.0; to: 0.95
                                duration: model.dur * model.fadeAt * 0.4
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: ptcl; property: "x"
                                from: model.startX - ptcl.width / 2
                                to:   model.midX   - ptcl.width / 2
                                duration: model.dur * model.fadeAt
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                target: ptcl; property: "y"
                                from: model.startY - ptcl.height / 2
                                to:   model.midY   - ptcl.height / 2
                                duration: model.dur * model.fadeAt
                                easing.type: Easing.InOutSine
                            }
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: ptcl; property: "opacity"
                                to: 0.0
                                duration: model.dur * (1.0 - model.fadeAt)
                                easing.type: Easing.InQuart
                            }
                            NumberAnimation {
                                target: ptcl; property: "x"
                                to: model.endX - ptcl.width / 2
                                duration: model.dur * (1.0 - model.fadeAt)
                                easing.type: Easing.InOutCubic
                            }
                            NumberAnimation {
                                target: ptcl; property: "y"
                                to: model.endY - ptcl.height / 2
                                duration: model.dur * (1.0 - model.fadeAt)
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Math.round(root.pct) + "%"
                color: "white"
                font.family: "Geist"; font.pointSize: 58; font.weight: Font.Bold
                z: 10
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 55
                text: root.pct >= 100 ? "Fully Charged" : "Charging"
                color: Qt.rgba(1, 1, 1, 0.70)
                font.family: "Geist"; font.pointSize: 13
                font.weight: Font.Medium; font.letterSpacing: 1.2
                z: 10
            }
        }
    }
}
