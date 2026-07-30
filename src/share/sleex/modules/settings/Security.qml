import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceSingleColumn: true
    
    ContentSection {
        title: "Lock"
        icon: "lock"

        ConfigSwitch {
            id: enableFaceAuthSwitch
            text: "Enable Face Authentication"
            checked: Config.options.lockscreen.enableFaceAuth
            onClicked: checked = !checked;
            onCheckedChanged: {
                Config.options.lockscreen.enableFaceAuth = checked
            }
            StyledToolTip { text: "Uses Howdy for face authentication.\nIR camera is recommended." }
        }   
    }
}
