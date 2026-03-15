import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: bgMenu
    
    anchors.fill: parent
    z: 998
    visible: false
    
    property real menuX: 0
    property real menuY: 0
    
    MouseArea {
        anchors.fill: parent
        onClicked: bgMenu.close()
    }

    Rectangle {
        id: popupBackground
        readonly property real padding: 4
        
        x: bgMenu.menuX
        y: bgMenu.menuY
        
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.windowRounding
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        clip: true
        
        implicitWidth: menuLayout.implicitWidth + padding * 2
        implicitHeight: menuLayout.implicitHeight + padding * 2
        
        Behavior on opacity { NumberAnimation { duration: 150 } }
        opacity: bgMenu.visible ? 1 : 0
        
        ColumnLayout {
            id: menuLayout
            anchors.fill: parent
            anchors.margins: popupBackground.padding
            spacing: 0

            RippleButton {
                Layout.fillWidth: true
                buttonRadius: popupBackground.radius - popupBackground.padding
                
                contentItem: RowLayout {
                    spacing: 8
                    anchors.fill: parent
                    anchors.margins: 12
                    MaterialSymbol { text: "terminal"; iconSize: 20 }
                    StyledText { text: "Open terminal"; Layout.fillWidth: true }
                }
                
                onClicked: {
                    Quickshell.execDetached([Config.options.apps.terminal, "--working-directory", FileUtils.trimFileProtocol(Directories.desktop)])
                    bgMenu.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Appearance.m3colors.m3outlineVariant
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            RippleButton {
                Layout.fillWidth: true
                buttonRadius: popupBackground.radius - popupBackground.padding
                
                contentItem: RowLayout {
                    spacing: 8
                    anchors.fill: parent
                    anchors.margins: 12
                    MaterialSymbol { text: "settings"; iconSize: 20 }
                    StyledText { text: "Sleex settings"; Layout.fillWidth: true }
                }
                
                onClicked: {
                    Quickshell.execDetached(["qs", "-p", "/usr/share/sleex/settings.qml"])
                    bgMenu.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Appearance.m3colors.m3outlineVariant
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            RippleButton {
                Layout.fillWidth: true
                buttonRadius: popupBackground.radius - popupBackground.padding
                
                contentItem: RowLayout {
                    spacing: 8
                    anchors.fill: parent
                    anchors.margins: 12
                    MaterialSymbol { text: "logout"; iconSize: 20 }
                    StyledText { text: "Logout"; Layout.fillWidth: true }
                }
                
                onClicked: {
                    Hyprland.dispatch("global quickshell:sessionOpen")
                    bgMenu.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Appearance.m3colors.m3outlineVariant
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            RippleButton {
                Layout.fillWidth: true
                buttonRadius: popupBackground.radius - popupBackground.padding
                
                contentItem: RowLayout {
                    spacing: 8
                    anchors.fill: parent
                    anchors.margins: 12
                    MaterialSymbol { text: Config.options.background.showDesktopIcons ? "visibility_off" : "visibility"; iconSize: 20 }
                    StyledText { text: Config.options.background.showDesktopIcons ? "Hide icons" : "Show icons"; Layout.fillWidth: true }
                }

                onClicked: {
                    Config.options.background.showDesktopIcons = !Config.options.background.showDesktopIcons
                    bgMenu.close()
                }
            }
        }
    }
    
    function openAt(mouseX, mouseY, parentW, parentH) {
        menuX = Math.min(mouseX, parentW - popupBackground.implicitWidth)
        menuY = Math.min(mouseY, parentH - popupBackground.implicitHeight)
        visible = true
    }
    
    function close() {
        visible = false
    }
}