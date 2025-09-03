import QtQuick

Rectangle {
    id: monitor
    width: 120
    height: 80
    color: "#000000"
    radius: 6
    border.color: dragArea.pressed ? "#007acc" : "#666666"
    border.width: 2

    property string monitorName: ""
    property var workspace: null
    property var otherMonitor: null
    property bool isSnapping: false
    property int snapThreshold: 20
    property int snapPosition

    // Monitor label
    Text {
        text: parent.monitorName
        color: "white"
        font.pixelSize: 12
        font.bold: true
        anchors.centerIn: parent
    }

    // Drag behavior
    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: monitor
        drag.axis: Drag.XAndYAxis
        
        property point startPoint: Qt.point(0, 0)

        onPressed: {
            startPoint = Qt.point(monitor.x, monitor.y)
            monitor.z = 100 // Bring to front
            
            // Scale up slightly when dragging
            scaleAnimation.to = 1.1
            scaleAnimation.start()
        }

        onPositionChanged: {
            if (drag.active) {
                checkSnapping()
                constrainToBounds()
            }
        }

        onReleased: {
            monitor.z = 0
            var snapGuide = workspace.children[2] // Get snap guide from workspace
            snapGuide.visible = false
            
            // Scale back to normal
            scaleAnimation.to = 1.0
            scaleAnimation.start()

            // Perform final snap if needed
            performSnap()
        }
    }

    // Helper function to find snap guide
    function findSnapGuide() {
        if (!workspace) return null
        
        // Look for the snap guide in workspace children
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

        var snapGuide = workspace.children[2] // Get snap guide from workspace
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
        } else {
            snapGuide.visible = false
            monitor.isSnapping = false
        }
    }

    // Get possible snap positions
    function getSnapPositions() {
        if (!otherMonitor) return []

        return [
            // Right side
            { x: otherMonitor.x + otherMonitor.width, y: otherMonitor.y },
            // Left side  
            { x: otherMonitor.x - monitor.width, y: otherMonitor.y },
            // Top
            { x: otherMonitor.x, y: otherMonitor.y - monitor.height },
            // Bottom
            { x: otherMonitor.x, y: otherMonitor.y + otherMonitor.height },
            // Top-right corner
            { x: otherMonitor.x + otherMonitor.width, y: otherMonitor.y - monitor.height },
            // Bottom-right corner
            { x: otherMonitor.x + otherMonitor.width, y: otherMonitor.y + otherMonitor.height },
            // Top-left corner
            { x: otherMonitor.x - monitor.width, y: otherMonitor.y - monitor.height },
            // Bottom-left corner
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
        when: dragArea.containsMouse && !dragArea.pressed
        PropertyChanges { target: monitor; scale: 1.05 }
    }

    transitions: Transition {
        NumberAnimation { property: "scale"; duration: 100 }
    }
}