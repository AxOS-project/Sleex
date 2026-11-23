import qs.modules.common
import SleexUiKit.Widgets
import "../"
import Quickshell
import Quickshell.Io
import Sleex.Fhtc

QuickToggleButton {
    property bool enabled: false
    buttonIcon: "gamepad"
    toggled: enabled

    onClicked: {
        enabled = !enabled
        FhtcIpc.dispatch("reload-config")
    }

    StyledToolTip {
        text: qsTr("Game mode")
    }
}
