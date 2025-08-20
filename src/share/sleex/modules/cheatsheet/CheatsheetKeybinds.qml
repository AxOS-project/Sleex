import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland

Item {
    id: root
    readonly property var keybinds: HyprlandKeybinds.keybinds
    property real spacing: 16
    property real titleSpacing: 8
    width: 800
    height: 600

    property var keyBlacklist: ["Super_L"]
    property var keySubstitutions: ({
        "Super": "󰖳",
        // "Super": "⌘", // Just for you, Grace
        "mouse_up": "Scroll ↓",
        "mouse_down": "Scroll ↑",
        "mouse:272": "LMB",
        "mouse:273": "RMB",
        "mouse:275": "MouseBack",
        "Slash": "/",
        "Hash": "#",
        "Return": "Enter",
    })

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
                model: keybinds.children

                delegate: ColumnLayout {
                    spacing: root.titleSpacing
                    required property var modelData
                    width: parent.width

                    StyledText {
                        text: modelData.name
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.family: Appearance.font.family.title
                        color: Appearance.colors.colOnLayer0
                        wrapMode: Text.Wrap
                    }

                    Repeater {
                        model: modelData.children

                        delegate: ColumnLayout {
                            spacing: root.titleSpacing
                            required property var modelData
                            width: parent.width

                            StyledText {
                                text: modelData.name
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.family: Appearance.font.family.title
                                color: Appearance.colors.colOnLayer0
                                wrapMode: Text.Wrap
                            }

                            Repeater {
                                model: modelData.keybinds

                                delegate: RowLayout {
                                    spacing: 10
                                    width: parent.width

                                    // Key sequence column, fixed width for alignment
                                    Item {
                                        Layout.preferredWidth: 250
                                        Layout.preferredHeight: 25
                                        Layout.alignment: Qt.AlignLeft

                                        RowLayout {
                                            id: keyRow
                                            spacing: 4
                                            anchors.verticalCenter: parent.verticalCenter

                                            Repeater {
                                                model: modelData.mods
                                                delegate: KeyboardKey {
                                                    required property var modelData
                                                    key: keySubstitutions[modelData] || modelData
                                                }
                                            }

                                            StyledText {
                                                visible: !keyBlacklist.includes(modelData.key) && modelData.mods.length > 0
                                                text: "+"
                                            }

                                            KeyboardKey {
                                                visible: !keyBlacklist.includes(modelData.key)
                                                key: keySubstitutions[modelData.key] || modelData.key
                                                color: Appearance.colors.colOnLayer0
                                            }
                                        }
                                    }

                                    // Description, fills remaining space
                                    StyledText {
                                        text: modelData.comment
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        wrapMode: Text.Wrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}