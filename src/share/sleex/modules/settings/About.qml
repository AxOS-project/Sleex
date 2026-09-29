import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import Sleex.Services

ContentPage {
    forceSingleColumn: true
    
    ContentSection {
        title: "Distro"
        icon: "info"

        RowLayout {
            anchors.margins: 24
            spacing: 24


            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 110
                implicitHeight: 110
                radius: 20
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)

                IconImage {
                    anchors.centerIn: parent
                    implicitWidth: 72
                    implicitHeight: 72
                    source: Quickshell.iconPath(SystemInfo.logo)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: SystemInfo.distroName
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.ExtraBold
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: (SystemInfo.axosVersion !== null ? SystemInfo.axosVersion : "Kernel: " + SystemInfo.kernelVersion )
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }

                Row {
                    id: colorRow
                    spacing: -6

                    Repeater {
                        model: [
                            Appearance.m3colors.m3primary,
                            Appearance.m3colors.m3secondary,
                            Appearance.m3colors.m3tertiary,
                            Appearance.m3colors.m3error,
                            Appearance.m3colors.m3primaryContainer,
                            Appearance.m3colors.m3secondaryContainer,
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: 28
                            height: 28
                            radius: width / 2
                            color: modelData
                            z: index
                            border.width: 2
                            border.color: Appearance.colors.colLayer1
                        }
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 5

            RippleButtonWithIcon {
                materialIcon: "globe"
                mainText: "Website"
                onClicked: {
                    Qt.openUrlExternally("https://www.axos-project.com")
                }
            }

            RippleButtonWithIcon {
                materialIcon: "auto_stories"
                mainText: "Documentation"
                onClicked: {
                    Qt.openUrlExternally("https://www.axos-project.com/docs")
                }
            }
            RippleButtonWithIcon {
                materialIcon: "support"
                mainText: "Help & Support"
                onClicked: {
                    Qt.openUrlExternally("https://discord.axos-project.com")
                }
            }
            RippleButtonWithIcon {
                materialIcon: "bug_report"
                mainText: "Report a Bug"
                onClicked: {
                    Qt.openUrlExternally("https://github.com/axos-project")
                }
            }
            RippleButtonWithIcon {
                materialIcon: "favorite"
                mainText: "Donate"
                onClicked: {
                    Qt.openUrlExternally("https://github.com/sponsors/axos-project")
                }
            }

        }
    }

    GridLayout {
        columns: 2
        Layout.fillWidth: true
        rowSpacing: 8
        columnSpacing: 8

        AboutCard {
            icon: "settings_slow_motion"
            label: "CPU"
            value: SystemInfo.cpu || "Loading..."
            Layout.fillWidth: true
        }

        AboutCard {
            icon: "developer_board"
            label: "GPU"
            value: SystemInfo.gpu || "Loading..."
            Layout.fillWidth: true
        }

        AboutCard {
            icon: "memory"
            label: "Memory"
            value: ResourceMonitor.memoryTotal ? (ResourceMonitor.memoryTotal / (1024 * 1024)).toFixed(2) + " GB" : "Loading..."
            Layout.fillWidth: true
        }

        AboutCard {
            icon: "storage"
            label: "Disk"
            value: SystemInfo.disk || "Loading..."
            Layout.fillWidth: true
        }
    }

    ContentSection {
        title: "Sleex"
        icon: "info"

        RowLayout {
            anchors.margins: 24
            spacing: 24


            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 110
                implicitHeight: 110
                radius: 20
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)

                IconImage {
                    anchors.centerIn: parent
                    implicitWidth: 72
                    implicitHeight: 72
                    source: "file:///usr/share/pixmaps/sleex/svg/dark.svg"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: "Sleex"
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.ExtraBold
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: SystemInfo.sleexVersion || "Loading..."
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 5

            RippleButtonWithIcon {
                materialIcon: "auto_stories"
                mainText: "Documentation"
                onClicked: {
                    Qt.openUrlExternally("https://www.axos-project.com/docs/guides/sleex")
                }
            }
            RippleButtonWithIcon {
                materialIcon: "adjust"
                materialIconFill: false
                mainText: "Issues"
                onClicked: {
                    Qt.openUrlExternally("https://github.com/axos-project/sleex/issues")
                }
            }
            RippleButtonWithIcon {
                materialIcon: "forum"
                mainText: "Discussions"
                onClicked: {
                    Qt.openUrlExternally("https://github.com/axos-project/sleex/discussions")
                }
            }
        }
    }
}
