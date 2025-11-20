import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "../"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import Sleex.Services

QuickToggleButton {

    toggled: Network.wifiEnabled
    buttonIcon: Network.getWifiIcon()
    onClicked: {
        Network.toggleWifi()
    }
    altAction: () => {
        Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`])
        GlobalStates.dashboardOpen = false
    }
    StyledToolTip {
        text: StringUtils.format(qsTr("{0} | Right-click to configure"), Network.active?.ssid ?? qsTr("Wi-Fi Disabled"))
    }
}
