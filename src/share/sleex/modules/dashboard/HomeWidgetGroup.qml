import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import qs.services
import qs.modules.dashboard.bento
import QtQuick
import QtQuick.Layouts
import Quickshell
import Sleex.Services
import Sleex.Utils

Rectangle {
    id: root
    color: "transparent"

    property bool connected: Network.networks.filter(n => n.active).length > 0

    ColumnLayout {
        anchors.fill: parent
        spacing: BentoModel.customizeOpen ? 10 : 0

        BentoCustomizeBar {
            Layout.fillWidth: true
        }

        BentoGrid {
            Layout.fillWidth: true
            Layout.fillHeight: true
            connected: root.connected
        }
    }
}
