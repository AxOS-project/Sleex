import qs.modules.common.widgets
import qs.modules.common
import qs.services

QuickToggleButton {
    id: root
    toggled: !Idle.hypnos.enabled
    buttonIcon: "coffee"
    onClicked: {
        Idle.hypnos.enabled = !Idle.hypnos.enabled;
    }

    StyledToolTip {
        text: qsTr("Keep system awake")
    }
}
