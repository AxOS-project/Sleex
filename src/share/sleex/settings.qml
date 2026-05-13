//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_SCALE_FACTOR=1

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root

    // Layout
    minimumWidth: 750
    minimumHeight: 730
    width: 850
    height: 700
    color: Appearance.colors.colLayer1

    // State
    property real contentPadding: 8
    property bool showNextTime: false
    property int currentPage: 0
    property var pages: [
        { name: "Style",       icon: "palette",          component: "modules/settings/Style.qml",         type: "item" },
        { name: "Interface",   icon: "space_dashboard",  component: "modules/settings/Interface.qml",     type: "item" },
        { type: "divider" },
        { name: "Behavior",    icon: "settings",         component: "modules/settings/BehaviorConfig.qml", type: "item" },
        { name: "Sound",       icon: "brand_awareness",  component: "modules/settings/Sound.qml",         type: "item" },
        { name: "Bluetooth",   icon: "bluetooth",        component: "modules/settings/Bluetooth.qml",     type: "item" },
        { name: "Wifi",        icon: "wifi",             component: "modules/settings/Wifi.qml",          type: "item" },
        { name: "Applications",icon: "apps",             component: "modules/settings/Applications.qml",  type: "item" },
        { name: "Display",     icon: "display_settings", component: "modules/settings/Display.qml",       type: "item" },
        { type: "divider" },
        { name: "Privacy",     icon: "lock",             component: "modules/settings/Privacy.qml",       type: "item" },
        { name: "About",       icon: "info",             component: "modules/settings/About.qml",         type: "item" }
    ]

    visible: true
    title: "Sleex Settings"

    onClosing: Qt.quit()

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Idle.init()
    }

    // Root layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Appearance.colors.colLayer1

            // Sidebar
            Item {
                id: menuContainer
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                implicitWidth: 250

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10
                    
                    SettingUserInfo {}

                    ListView {
                        id: sidebar
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        spacing: 8
                        clip: true
                        model: root.pages
                        currentIndex: root.currentPage
                        highlightMoveDuration: 100

                        onCurrentIndexChanged: root.currentPage = currentIndex

                        highlight: Rectangle {
                            color: Appearance.colors.colPrimaryContainer
                            radius: Appearance.rounding.small
                            visible: modelData.type !== "divider"

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 3
                                height: 15
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colPrimary
                                z: 2
                            }

                            NumberAnimation on y {
                                duration: 250
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                            }
                        }

                        delegate: Item {
                            id: row
                            width: ListView.view.width
                            height: modelData.type === "divider" ? 1 : 44

                            // Divider line
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: sidebar.width
                                height: 1
                                color: Appearance.colors.colOutline
                                visible: modelData.type === "divider"
                            }

                            // Nav item
                            RowLayout {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 24 }
                                spacing: 12
                                visible: modelData.type !== "divider"

                                MaterialSymbol { text: modelData.icon; iconSize: 20 }
                                Label {
                                    text: modelData.name
                                    color: Appearance.colors.colOnLayer0
                                }
                            }

                            // Hover background
                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: ma.containsMouse && sidebar.currentIndex !== index
                                    ? Appearance.colors.colSurfaceContainerHigh
                                    : "transparent"
                                z: -1
                                visible: modelData.type !== "divider"
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: modelData.type !== "divider"
                                onClicked: sidebar.currentIndex = index
                            }
                        }
                    }
                }
            }

            // Content pane
            Rectangle {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: menuContainer.right
                    right: parent.right
                    leftMargin: 6
                    margins: root.contentPadding
                }
                color: Appearance.colors.colLayer0
                radius: Appearance.rounding.windowRounding - root.contentPadding

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    source: root.pages[0].component

                    Connections {
                        target: root
                        function onCurrentPageChanged() {
                            if (pageLoader.sourceComponent !== root.pages[root.currentPage].component)
                                switchAnim.restart()
                        }
                    }

                    SequentialAnimation {
                        id: switchAnim

                        NumberAnimation {
                            target: pageLoader
                            property: "opacity"
                            from: 1; to: 0
                            duration: 150
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedFirstHalf
                        }
                        PropertyAction {
                            target: pageLoader
                            property: "source"
                            value: root.pages[root.currentPage].component
                        }
                        NumberAnimation {
                            target: pageLoader
                            property: "opacity"
                            from: 0; to: 1
                            duration: 250
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "settings"
        function reloadWallpaper(newPath: string): void {
            Config.options.background.wallpaperPath = newPath
        }
    }
}
