import qs.modules.common.widgets
import qs.modules.common
import qs.services

QuickToggleButton {
    id: root
    toggled: Persistent.states.idle.inhibit
    buttonIcon: "coffee"
    onClicked: {
        Idle.toggleInhibit()
    }

    StyledToolTip {
        text: qsTr("Keep system awake")
    }
}
