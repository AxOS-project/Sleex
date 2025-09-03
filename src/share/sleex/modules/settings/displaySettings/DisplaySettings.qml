import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common

Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    Rectangle {
        id: workspace
        anchors.fill: parent
        color: "transparent"

        // Dynamically create monitor items based on detected monitors
        Repeater {
            model: Monitors.monitors
            
            MonitorItem {
                monitorName: modelData.name
                // Scale down positions for display (divide by scale factor)
                x: modelData.x / 16
                y: modelData.y / 16
                workspace: workspace
                
                // Find other monitors for snapping
                property var otherMonitors: Monitors.monitors.filter(m => m.name !== monitorName)
            }
        }

        // Snap guide overlay (same as before)
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
        // Settings are applied automatically when dragging
        console.log("Monitor positions applied to Hyprland");
    }

    // Quick preset functions
    function presetDualHorizontal() {
        const monitors = Monitors.monitors;
        if (monitors.length >= 2) {
            Monitors.snapMonitors(monitors[0].name, monitors[1].name, "right");
        }
    }

    function presetDualVertical() {
        const monitors = Monitors.monitors;
        if (monitors.length >= 2) {
            Monitors.snapMonitors(monitors[0].name, monitors[1].name, "bottom");
        }
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
        property var otherMonitors: []
        property bool isSnapping: false
        property int snapThreshold: Monitors.snapThreshold
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
                    // Apply to Hyprland when drag ends
                    const actualX = Math.round(monitor.x * 16);
                    const actualY = Math.round(monitor.y * 16);
                    Monitors.setMonitorPosition(monitor.monitorName, actualX, actualY);
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

        // Simplified snapping logic
        function checkSnapping() {
            if (!otherMonitors.length || !workspace) return;
            
            var snapGuide = findSnapGuide();
            var bestSnap = null;
            var minDistance = snapThreshold + 1;

            // Check snap positions against all other monitors
            for (var i = 0; i < otherMonitors.length; i++) {
                var otherMonitor = otherMonitors[i];
                var snapPositions = getSnapPositions(otherMonitor);
                
                for (var j = 0; j < snapPositions.length; j++) {
                    var pos = snapPositions[j];
                    var distance = Math.sqrt(Math.pow(monitor.x - pos.x, 2) + Math.pow(monitor.y - pos.y, 2));
                    if (distance < minDistance) {
                        minDistance = distance;
                        bestSnap = pos;
                    }
                }
            }

            if (bestSnap && minDistance <= snapThreshold) {
                showSnapGuide(bestSnap.x, bestSnap.y);
                monitor.isSnapping = true;
                monitor.snapPosition = Qt.point(bestSnap.x, bestSnap.y);
            } else {
                if (snapGuide) snapGuide.visible = false;
                monitor.isSnapping = false;
            }
        }

        // Get snap positions for another monitor (scaled down for display)
        function getSnapPositions(otherMonitor) {
            const otherX = otherMonitor.x / 16;
            const otherY = otherMonitor.y / 16;
            const otherW = 120; // Display width
            const otherH = 80;  // Display height
            
            return [
                { x: otherX + otherW, y: otherY },      // Right
                { x: otherX - monitor.width, y: otherY }, // Left
                { x: otherX, y: otherY - monitor.height }, // Top
                { x: otherX, y: otherY + otherH }       // Bottom
            ];
        }

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

        function showSnapGuide(snapX, snapY) {
            var snapGuide = findSnapGuide()
            if (!snapGuide) return
            snapGuide.x = snapX
            snapGuide.y = snapY
            snapGuide.width = monitor.width
            snapGuide.height = monitor.height
            snapGuide.visible = true
        }

        function performSnap() {
            if (monitor.isSnapping) {
                snapAnimation.to = monitor.snapPosition
                snapAnimation.start()
            }
        }

        // Animations
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

    // Control buttons
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 20
        spacing: 10

        Button {
            text: "Side by Side"
            onClicked: root.presetDualHorizontal()
        }

        Button {
            text: "Stacked"  
            onClicked: root.presetDualVertical()
        }

        Button {
            text: "Refresh"
            onClicked: Monitors.refreshMonitors()
        }
    }
}