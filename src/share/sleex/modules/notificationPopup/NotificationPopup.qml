import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: notificationPopup

    property string position: Config.options?.notifications?.position ?? "top-right"

    PanelWindow {
        id: root
        visible: (Notifications.popupList.length > 0)
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

        WlrLayershell.namespace: "quickshell:notificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusiveZone: 0

        anchors: {
            switch (notificationPopup.position) {
            case "top-left":
                return {
                    top: true,
                    left: true,
                    bottom: true,
                }
            case "top-center":
                return {
                    top: true,
                    bottom: true,
                }
            case "top-right":
                return {
                    top: true,
                    right: true,
                    bottom: true,
                }
            default:
                return {
                    top: true,
                    right: true
                }
            }
        }

        mask: Region {
            item: listview.contentItem
        }

        color: "transparent"
        implicitWidth: Appearance.sizes.notificationPopupWidth

        NotificationListView {
            id: listview
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 5
            implicitWidth: parent.width - Appearance.sizes.elevationMargin * 2
            popup: true
        }
    }
}
