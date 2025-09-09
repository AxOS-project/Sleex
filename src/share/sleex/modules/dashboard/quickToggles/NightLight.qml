import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs
import qs.services
import Quickshell.Io

QuickToggleButton {
    id: nightLightButton
    property bool enabled: NightLight.active
    toggled: enabled
    buttonIcon: Config.options.display.nightLightAuto ? "night_sight_auto" : "bedtime"
    onClicked: {
        NightLight.toggle()
    }

    altAction: () => {
        Config.options.display.nightLightAuto = !Config.options.display.nightLightAuto
    }

    Component.onCompleted: {
        NightLight.fetchState()
    }
    
    StyledToolTip {
        content: "Night Light | Right-click to toggle Auto mode"
    }
}