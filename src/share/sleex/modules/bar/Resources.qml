import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Sleex.Services

Item {
    id: root
    property bool alwaysShowAllResources: true
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: 32

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "memory"
            percentage: ResourceMonitor.memoryUsedPercentage
        }

        Resource {
            iconName: "swap_horiz"
            percentage: ResourceMonitor.swapUsedPercentage
        }

        Resource {
            iconName: "settings_slow_motion"
            percentage: ResourceMonitor.cpuUsage
            Layout.leftMargin: shown ? 4 : 0
        }

    }

}
