import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    // Get the directory where this QML file is located
    readonly property string configDir: Qt.resolvedUrl(".").toString().replace("file://", "")

    PanelWindow {
        id: buttonPanel

        // **FIX:** Set the width and height of the PanelWindow
        // to be exactly the same as its child (the pillButton).
        // This stops the invisible PanelWindow from blocking clicks
        // in a larger area than intended.
        width: pillButton.width
        height: pillButton.height

        // Position at top-left of current monitor
        anchors {
            top: true
            left: true
        }
        margins {
            top: -35
            left: 25
        }

        // Make the panel itself transparent
        color: "transparent"

        Rectangle {
            id: pillButton

            // Position with margin inside the panel
            anchors {
                top: parent.top
                left: parent.left
            }

            // Pill dimensions
            width: 70
            height: 30
            radius: 30

            // Toggle between transparent and solid
            color: isActive ? "#004F57" : "transparent"

            // Track active state
            property bool isActive: false

            // The image inside
            Image {
                id: icon
                anchors.centerIn: parent
                source: configDir + "/icon.png"
                width: 34
                height: 34
            }

            // Click handler
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    // Toggle the active state
                    pillButton.isActive = !pillButton.isActive
                    console.log("Button clicked! Active state:", pillButton.isActive)

                    // Always run close first
                    processRunner.shouldRunOpen = pillButton.isActive
                    processRunner.runClose()
                }
            }
        }

        // Process runner
        Item {
            id: processRunner
            property bool shouldRunOpen: false

            function runClose() {
                console.log("Running close...")
                var closeProc = closeComponent.createObject(processRunner)
                closeProc.running = true
            }

            function runOpen() {
                console.log("Running open...")
                var openProc = openComponent.createObject(processRunner)
                openProc.running = true
            }
        }

        // Close process component
        Component {
            id: closeComponent
            Process {
                command: ["sh", "-c", configDir + "/close"]

                onExited: {
                    console.log("Close exited with code:", exitCode)

                    // If button is active, run open after close finishes
                    if (processRunner.shouldRunOpen) {
                        processRunner.runOpen()
                    }

                    destroy()
                }
            }
        }

        // Open process component
        Component {
            id: openComponent
            Process {
                command: ["sh", "-c", configDir + "/open"]

                onExited: {
                    console.log("Open exited with code:", exitCode)
                    destroy()
                }
            }
        }
    }
}