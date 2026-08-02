import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

MouseArea {
    id: root

    property bool borderless: Config.options.bar.borderless
    readonly property bool isCharging: Battery.isCharging
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100
    readonly property color batteryLowBackground: Appearance.m3colors.darkmode ?
        Appearance.m3colors.m3error : Appearance.m3colors.m3errorContainer
    readonly property color batteryLowOnBackground: Appearance.m3colors.darkmode ?
        Appearance.m3colors.m3errorContainer : Appearance.m3colors.m3error

    implicitWidth: 75
    implicitHeight: 23

    hoverEnabled: true

    // Pulses the background opacity for a subtle low-battery warning.
    SequentialAnimation {
        id: lowBatteryPulse
        running: root.isLow && !root.isCharging
        loops: Animation.Infinite
        PropertyAnimation {
            target: background
            property: "opacity"
            from: 0.7
            to: 1.0
            duration: 600
            easing.type: Easing.InOutSine
        }
        PropertyAnimation {
            target: background
            property: "opacity"
            from: 1.0
            to: 0.7
            duration: 600
            easing.type: Easing.InOutSine
        }
    }

    ClippingRectangle {
        id: background
        anchors.fill: parent
        radius: 100
        color: root.isLow ? "#350000" : Appearance.colors.colLayer2
        opacity: 1.0

        RowLayout {
            id: textLayer
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                text: "bolt"
                visible: root.isCharging
                font.pixelSize: 18
                color: root.isLow ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
            }
            Text {
                id: batteryText
                text: `${Math.round(percentage * 100)}%`
                font.pixelSize: 13
                color: root.isLow ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
                font { bold: root.isLow }
            }
        }

        Rectangle {
            id: bar
            clip: true
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: root.width * Math.min(Math.max(parseFloat(percentage * 100), 0), 100) / 100
            color: root.isCharging ? "transparent" : (root.isLow ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1)

            // Pulses the bar color to red when battery is low and not charging.
            SequentialAnimation {
                running: root.isLow && !root.isCharging
                loops: Animation.Infinite
                ColorAnimation {
                    target: bar
                    property: "color"
                    from: Appearance.m3colors.m3error
                    to: "#d92e2e"
                    duration: 600
                    easing.type: Easing.InOutSine
                }
                ColorAnimation {
                    target: bar
                    property: "color"
                    from: "#d92e2e"
                    to: Appearance.m3colors.m3error
                    duration: 600
                    easing.type: Easing.InOutSine
                }
            }

            // Animated gradient overlay shown only when charging.
            LinearGradient {
                id: chargingGradient
                anchors.fill: parent
                visible: root.isCharging
                start: Qt.point(0, 0)
                end: Qt.point(parent.width, 0)
                property real animationPosition: 0.0
                gradient: Gradient {
                    GradientStop { position: chargingGradient.animationPosition - 0.5; color: "#7ffc83" }
                    GradientStop { position: chargingGradient.animationPosition; color: "#8ff455"}
                    GradientStop { position: chargingGradient.animationPosition + 0.6; color: "#74f278" }
                }
                PropertyAnimation {
                    target: chargingGradient
                    property: "animationPosition"
                    from: -0.2
                    to: 1.2
                    duration: 2500
                    loops: Animation.Infinite
                    running: root.isCharging
                }
            }

            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

            RowLayout {
                id: textLayer2
                x: (root.width - width) / 2
                y: (root.height - height) / 2
                spacing: 4
                MaterialSymbol {
                    text: "bolt"
                    visible: root.isCharging
                    font.pixelSize: 16
                    color: Appearance.colors.colLayer0
                }
                Text {
                    text: `${Math.round(percentage * 100)}%`
                    font.pixelSize: 13
                    color: Appearance.colors.colLayer0
                }
            }
        }
    }

    LazyLoader {
        id: popupLoader
        active: root.containsMouse

        component: PanelWindow {
            id: popupWindow
            visible: true
            color: "transparent"
            exclusiveZone: 0

            anchors.top: true
            anchors.right: true

            implicitWidth: batteryPopup.implicitWidth
            implicitHeight: batteryPopup.implicitHeight

            margins {
                left: root.mapToGlobal(Qt.point(0, root.width)).y - 30 
                top: root.mapToGlobal(Qt.point(0, root.height)).y - 30 
            }

            mask: Region {
                item: batteryPopup
            }

            BatteryPopup {
                id: batteryPopup
                anchors.centerIn: parent
            }
        }
    }
}