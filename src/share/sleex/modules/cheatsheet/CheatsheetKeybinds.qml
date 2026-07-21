pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property real spacing: 16
    property real padding: 4
    implicitWidth: QsWindow?.window?.screen.width * 0.5 ?? 0
    implicitHeight: QsWindow?.window?.screen.height * 0.7 ?? 0

    StyledFlickable {
        id: flick
        anchors.fill: parent
        contentWidth: root.width
        contentHeight: layout.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: true
        clip: true

        ColumnLayout {
            id: layout
            width: root.width
            spacing: root.spacing

            Repeater {
                model: [...HyprlandKeybinds.keybindCategories, ""]
                delegate: CheatsheetKeybindsCategory {
                    required property var modelData
                    categoryName: modelData
                }
            }
        }
    }
}