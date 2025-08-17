import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    required property string iconName
    required property double percentage
    property bool shown: true
    clip: true
    visible: width > 0 && height > 0
    implicitWidth: resourceRowLayout.x < 0 ? 0 : resourceRowLayout.implicitWidth
    implicitHeight: resourceRowLayout.implicitHeight

    // Helper function to format KB to GB  
    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    // Generate tooltip content based on resource type
    property var tooltipData: {
        switch(iconName) {
            case "memory":
                return [
                    { icon: "memory", label: "Memory Usage", value: "" },
                    { icon: "storage", label: "Used:", value: formatKB(ResourceUsage.memoryUsed) },
                    { icon: "check_circle", label: "Free:", value: formatKB(ResourceUsage.memoryFree) },
                    { icon: "dns", label: "Total:", value: formatKB(ResourceUsage.memoryTotal) },
                    { icon: "percent", label: "Usage:", value: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%` }
                ]
            case "swap_horiz":
                return ResourceUsage.swapTotal > 0 ?
                [
                    { icon: "swap_horiz", label: "Swap Usage", value: "" },
                    { icon: "storage", label: "Used:", value: formatKB(ResourceUsage.swapUsed) },
                    { icon: "check_circle", label: "Free:", value: formatKB(ResourceUsage.swapFree) },
                    { icon: "dns", label: "Total:", value: formatKB(ResourceUsage.swapTotal) },
                    { icon: "percent", label: "Usage:", value: `${Math.round(ResourceUsage.swapUsedPercentage * 100)}%` }
                ] :
                [
                    { icon: "swap_horiz", label: "Swap:", value: "Not configured" }
                ]
            case "settings_slow_motion":
                return [
                    { icon: "settings_slow_motion", label: "CPU Usage", value: "" },
                    { icon: "bolt", label: "Current:", value: `${Math.round(ResourceUsage.cpuUsage * 100)}%` },
                    { icon: "speed", label: "Load:", value: ResourceUsage.cpuUsage > 0.8 ?
                        "High" :
                        ResourceUsage.cpuUsage > 0.5 ? "Medium" : "Low"
                    },
                    { icon: "thermostat", label: "Temperature:", value: `${ResourceUsage.cpuTemperature} °C` }
                ]
            default:
                return [
                    { icon: "info", label: "System Resource", value: "" }
                ]
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: resourceRowLayout.x >= 0 && root.width > 0 && root.visible
    }

    LazyLoader {
        id: popupLoader
        active: mouseArea.containsMouse

        component: PanelWindow {
            id: popupWindow
            visible: true

            color: "transparent"
            exclusiveZone: 0
            anchors.top: true
            anchors.left: true

            implicitWidth: resourcePopup.implicitWidth
            implicitHeight: resourcePopup.implicitHeight

            margins {
                left: root.mapToGlobal(Qt.point(
                    (root.width - resourcePopup.implicitWidth) / 2,
                    0
                )).x
                top: root.mapToGlobal(Qt.point(0, root.height)).y - 30 
            }

            
            Rectangle {
                id: resourcePopup
                readonly property real margin: 10
                implicitWidth: columnLayout.implicitWidth + margin * 2
                implicitHeight: columnLayout.implicitHeight + margin * 2
                color: Appearance.m3colors.m3background
                radius: Appearance.rounding.small
                border.width: 1
                border.color: Appearance.colors.colLayer0
                clip: true

                ColumnLayout {
                    id: columnLayout
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: root.tooltipData
                        delegate: RowLayout {
                            spacing: 5
                            Layout.fillWidth: true

                            MaterialSymbol {
                                text: modelData.icon
                                color: Appearance.m3colors.m3onSecondaryContainer
                            }
                            StyledText {
                                text: modelData.label
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                visible: modelData.value !== ""
                                color: Appearance.colors.colOnLayer1
                                text: modelData.value
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        spacing: 4
        id: resourceRowLayout
        x: shown ? 0 : -resourceRowLayout.width

        CircularProgress {
            Layout.alignment: Qt.AlignVCenter
            lineWidth: 2
            value: percentage
            implicitSize: 26
            colSecondary: Appearance.colors.colSecondaryContainer
            colPrimary: Appearance.m3colors.m3onSecondaryContainer
            enableAnimation: false

            MaterialSymbol {
                anchors.centerIn: parent
                fill: 1
                text: iconName
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3onSecondaryContainer
            }

        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            color: Appearance.colors.colOnLayer1
            text: `${Math.round(percentage * 100)}%`
        }

        Behavior on x {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }
}