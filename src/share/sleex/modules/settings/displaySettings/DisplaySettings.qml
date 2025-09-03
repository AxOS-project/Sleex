import QtQuick
import QtQuick.Layouts
import qs.modules.common

Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    Rectangle {
        id: workspace
        anchors.fill: parent
        color: "transparent"

        // Primary Monitor
        MonitorItem {
            id: primaryMonitor
            x: 100
            y: 150
            monitorName: "HDMI1-A"
            workspace: workspace
            otherMonitor: secondaryMonitor
        }

        // Secondary Monitor  
        MonitorItem {
            id: secondaryMonitor
            x: 350
            y: 150
            monitorName: "eDP-1"
            workspace: workspace
            otherMonitor: primaryMonitor
        }

        // Snap guide overlay
        Rectangle {
            id: snapGuide
            objectName: "snapGuide"
            visible: false
            color: "transparent"
            border.color: Appearance.m3colors.m3primary
            border.width: 2
            radius: Appearance.rounding.unsharpenmore

            Behavior on x { NumberAnimation { duration: 100 } }
            Behavior on y { NumberAnimation { duration: 100 } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    function applySettings() {
        console.log("Primary monitor position:", primaryMonitor.x, primaryMonitor.y)
        console.log("Secondary monitor position:", secondaryMonitor.x, secondaryMonitor.y)
    }

    component MonitorItem: Rectangle {
        id: monitor
        width: 120
        height: 80
        color: "#000000"
        radius: Appearance.rounding.unsharpenmore
        border.color: dragHandler.active ? Appearance.m3colors.m3primary : "#666666"
        border.width: 2

        property string monitorName: ""
        property var workspace: null
        property var otherMonitor: null
        property bool isSnapping: false
        property int snapThreshold: 20
        property point snapPosition: Qt.point(0, 0)

        // Monitor label
        Text {
            text: parent.monitorName
            color: "white"
            font.pixelSize: 12
            font.bold: true
            anchors.centerIn: parent
        }

        // Drag handling
        DragHandler {
            id: dragHandler
            target: null
            cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real startX
            property real startY

            onActiveChanged: {
                if (active) {
                    startX = monitor.x
                    startY = monitor.y
                } else {
                    monitor.performSnap()
                }
            }

            onTranslationChanged: {
                let newX = startX + translation.x
                let newY = startY + translation.y

                // clamp inside workspace
                let maxX = workspace.width - monitor.width
                let maxY = workspace.height - monitor.height

                newX = Math.max(0, Math.min(maxX, newX))
                newY = Math.max(0, Math.min(maxY, newY))

                monitor.x = newX
                monitor.y = newY

                monitor.checkSnapping()
            }
        }


        // Helper function to find snap guide
        function findSnapGuide() {
            if (!workspace) return null
            for (var i = 0; i < workspace.children.length; i++) {
                var child = workspace.children[i]
                if (child.objectName === "snapGuide") {
                    return child
                }
            }
            return null
        }

        // Drag constraints
        function constrainToBounds() {
            if (!workspace) return
            if (monitor.x < 0) monitor.x = 0
            if (monitor.y < 0) monitor.y = 0
            if (monitor.x + monitor.width > workspace.width)
                monitor.x = workspace.width - monitor.width
            if (monitor.y + monitor.height > workspace.height)
                monitor.y = workspace.height - monitor.height
        }

        // Snap detection
        function checkSnapping() {
            if (!otherMonitor || !workspace) return
            var snapGuide = findSnapGuide()
            var snapPositions = getSnapPositions()
            var bestSnap = null
            var minDistance = snapThreshold + 1

            for (var i = 0; i < snapPositions.length; i++) {
                var pos = snapPositions[i]
                var distance = Math.sqrt(Math.pow(monitor.x - pos.x, 2) + Math.pow(monitor.y - pos.y, 2))
                if (distance < minDistance) {
                    minDistance = distance
                    bestSnap = pos
                }
            }

            if (bestSnap && minDistance <= snapThreshold) {
                showSnapGuide(bestSnap.x, bestSnap.y)
                monitor.isSnapping = true
                monitor.snapPosition = Qt.point(bestSnap.x, bestSnap.y)
            } else {
                if (snapGuide) snapGuide.visible = false
                monitor.isSnapping = false
            }
        }

        // Get possible snap positions
        function getSnapPositions() {
            if (!otherMonitor) return []
            return [
                { x: otherMonitor.x + otherMonitor.width, y: otherMonitor.y },
                { x: otherMonitor.x - monitor.width, y: otherMonitor.y },
                { x: otherMonitor.x, y: otherMonitor.y - monitor.height },
                { x: otherMonitor.x, y: otherMonitor.y + otherMonitor.height },
                { x: otherMonitor.x + otherMonitor.width, y: otherMonitor.y - monitor.height },
                { x: otherMonitor.x + otherMonitor.width, y: otherMonitor.y + otherMonitor.height },
                { x: otherMonitor.x - monitor.width, y: otherMonitor.y - monitor.height },
                { x: otherMonitor.x - monitor.width, y: otherMonitor.y + otherMonitor.height }
            ]
        }

        // Show snap guide
        function showSnapGuide(snapX, snapY) {
            var snapGuide = findSnapGuide()
            if (!snapGuide) return
            snapGuide.x = snapX
            snapGuide.y = snapY
            snapGuide.width = monitor.width
            snapGuide.height = monitor.height
            snapGuide.visible = true
        }

        // Perform final snap
        function performSnap() {
            if (monitor.isSnapping) {
                snapAnimation.to = monitor.snapPosition
                snapAnimation.start()
            }
        }

        // Animations
        NumberAnimation {
            id: scaleAnimation
            target: monitor
            property: "scale"
            duration: 150
            easing.type: Easing.OutCubic
        }

        ParallelAnimation {
            id: snapAnimation
            property point to: Qt.point(0, 0)

            NumberAnimation {
                target: monitor
                property: "x"
                to: snapAnimation.to.x
                duration: 200
                easing.type: Easing.OutBack
            }
            NumberAnimation {
                target: monitor
                property: "y"
                to: snapAnimation.to.y
                duration: 200
                easing.type: Easing.OutBack
            }
        }

        // Hover effect
        states: State {
            name: "hovered"
            when: dragHandler.active === false && dragHandler.containsMouse
            PropertyChanges { target: monitor; scale: 1.05 }
        }

        transitions: Transition {
            NumberAnimation { property: "scale"; duration: 100 }
        }
    }
}
