import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Layouts
import Sleex.Fhtc

Item {
    id: root
    required property var bar
    readonly property var monitor: FhtcMonitors.monitors[bar.screen.name] ?? null
    readonly property var activeWindow: FhtcWorkspaces.focusedWindow
    readonly property bool hasActiveWindow: activeWindow !== null && activeWindow !== undefined && Object.keys(activeWindow).length > 0

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
            text: root.hasActiveWindow ? (root.activeWindow["app-id"] || qsTr("Desktop")) : qsTr("Desktop")
        }

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            text: root.hasActiveWindow ? (root.activeWindow.title || "") : `${qsTr("Workspace")} ${(root.monitor?.["active-workspace-idx"] ?? 0) + 1}`
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
        active: hoverHandler.hovered || menuBar.openMenuIndex !== -1 || menuBar.visible

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
