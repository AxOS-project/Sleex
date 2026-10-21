import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property var bar
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    // Track whether the mouse is hovering over this area or a menu is open
    property bool hovered: (hoverHandler.hovered || menuBar.openMenuIndex !== -1) && menuBar.menus.length > 0

    implicitWidth: root.hovered ? menuBar.implicitWidth : colLayout.implicitWidth

    HoverHandler {
        id: hoverHandler
    }

    // ── App title (fades out on hover) ────────────────────────────────
    ColumnLayout {
        id: colLayout

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: -4

        opacity: root.hovered ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: root.activeWindow?.activated ? root.activeWindow?.appId : qsTr("Desktop")
        }

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            text: root.activeWindow?.activated ? root.activeWindow?.title : `${qsTr("Workspace")} ${monitor.activeWorkspace?.id}`
        }

    }

    // ── Menu bar (fades in on hover) ──────────────────────────────────
    AppMenuBar {
        id: menuBar
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        bar: root.bar

        opacity: root.hovered ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }

}
