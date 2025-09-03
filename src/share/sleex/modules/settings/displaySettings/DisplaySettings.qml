import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    // Track pending changes
    property var pendingChanges: ({})
    property bool hasChanges: Object.keys(pendingChanges).length > 0

    Rectangle {
        id: workspace
        anchors.fill: parent
        anchors.bottomMargin: 80 // Make room for buttons
        color: "transparent"

        // Dynamically create monitor items based on detected monitors
        Repeater {
            model: Monitors.monitors || []
            
            MonitorItem {
                monitorName: modelData && modelData.name ? modelData.name : ""
                // Scale down positions for display (divide by scale factor)
                x: modelData && modelData.x !== undefined ? modelData.x / 16 : 0
                y: modelData && modelData.y !== undefined ? modelData.y / 16 : 0
                workspace: workspace
                
                // Find other monitors for snapping
                property var otherMonitors: {
                    if (!Monitors.monitors || !modelData || !modelData.name) return [];
                    return Monitors.monitors.filter(m => m && m.name && m.name !== monitorName);
                }
            }
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

    // Apply all pending changes
    function applyChanges() {
        for (const monitorName in pendingChanges) {
            const change = pendingChanges[monitorName];
            Monitors.setMonitorPosition(monitorName, change.x, change.y);
        }
        pendingChanges = {};
    }

    // Cancel all pending changes
    function cancelChanges() {
        // Reset monitor positions to their original values
        for (const monitorName in pendingChanges) {
            const monitor = findMonitorItem(monitorName);
            if (monitor) {
                const originalMonitor = Monitors.monitors.find(m => m.name === monitorName);
                if (originalMonitor) {
                    monitor.x = originalMonitor.x / 16;
                    monitor.y = originalMonitor.y / 16;
                }
            }
        }
        pendingChanges = {};
    }

    // Find monitor item by name
    function findMonitorItem(name) {
        for (let i = 0; i < workspace.children.length; i++) {
            const child = workspace.children[i];
            if (child.monitorName === name) {
                return child;
            }
        }
        return null;
    }

    // Quick preset functions - now add to pending changes instead of applying immediately
    function presetDualHorizontal() {
        const monitors = Monitors.monitors;
        if (monitors.length >= 2) {
            const primary = monitors[0];
            const secondary = monitors[1];
            
            // Set positions in pending changes
            pendingChanges[secondary.name] = {
                x: primary.x + primary.width,
                y: primary.y
            };
            
            // Update display positions
            const secondaryItem = findMonitorItem(secondary.name);
            if (secondaryItem) {
                secondaryItem.x = (primary.x + primary.width) / 16;
                secondaryItem.y = primary.y / 16;
            }
        }
    }

    function presetDualVertical() {
        const monitors = Monitors.monitors;
        if (monitors.length >= 2) {
            const primary = monitors[0];
            const secondary = monitors[1];
            
            // Set positions in pending changes
            pendingChanges[secondary.name] = {
                x: primary.x,
                y: primary.y + primary.height
            };
            
            // Update display positions
            const secondaryItem = findMonitorItem(secondary.name);
            if (secondaryItem) {
                secondaryItem.x = primary.x / 16;
                secondaryItem.y = (primary.y + primary.height) / 16;
            }
        }
    }

    component MonitorItem: Rectangle {
        id: monitor
        width: 120
        height: 80
        color: hasChanges && (monitorName in root.pendingChanges) ? "#1a1a1a" : "#000000"
        radius: Appearance.rounding.unsharpenmore
        border.color: {
            if (dragHandler.active) return Appearance.m3colors.m3primary;
            if (hasChanges && (monitorName in root.pendingChanges)) return Appearance.m3colors.m3secondary;
            return "#666666";
        }
        border.width: 2

        property string monitorName: ""
        property var workspace: null
        property var otherMonitors: []
        property bool isSnapping: false
        property int snapThreshold: Monitors.snapThreshold
        property point snapPosition: Qt.point(0, 0)

        // Monitor label
        Text {
            text: parent.monitorName + (hasChanges && (monitorName in root.pendingChanges) ? " *" : "")
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
                    // Add to pending changes instead of applying immediately
                    const actualX = Math.round(monitor.x * 16);
                    const actualY = Math.round(monitor.y * 16);
                    root.pendingChanges[monitor.monitorName] = { x: actualX, y: actualY };
                    root.pendingChangesChanged(); // Trigger property binding update
                }
            }

            onTranslationChanged: {
                let newX = startX + translation.x
                let newY = startY + translation.y

                // clamp inside workspace (use parent dimensions as fallback)
                let workspaceWidth = workspace ? workspace.width : (monitor.parent ? monitor.parent.width : 800)
                let workspaceHeight = workspace ? workspace.height : (monitor.parent ? monitor.parent.height : 600)
                
                let maxX = workspaceWidth - monitor.width
                let maxY = workspaceHeight - monitor.height

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
            
            // Find the actual MonitorItem for the other monitor to get its display size
            const otherItem = root.findMonitorItem(otherMonitor.name);
            const otherW = otherItem ? otherItem.width : 120;
            const otherH = otherItem ? otherItem.height : 80;
            
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
    Column {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 20
        spacing: 10

        // Preset buttons
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
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

        // Apply/Cancel buttons
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            visible: root.hasChanges

            Button {
                text: "Apply Changes"
                highlighted: true
                onClicked: root.applyChanges()
            }

            Button {
                text: "Cancel"
                onClicked: root.cancelChanges()
            }
        }

        // Status text
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hasChanges ? 
                `${Object.keys(root.pendingChanges).length} monitor(s) have pending changes` : 
                "No pending changes"
            color: root.hasChanges ? Appearance.m3colors.m3secondary : "#666666"
            font.pixelSize: 11
            visible: true
        }
    }
}