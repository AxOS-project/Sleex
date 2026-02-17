import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        visible: SystemInfo.distroName == "AxOS"
        title: "Distro"
        
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20
            Layout.topMargin: 10
            Layout.bottomMargin: 10

            IconImage {
                implicitSize: 100
                source: "file:///usr/share/pixmaps/axos-logo.png"
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                // spacing: 10
                StyledText {
                    text: SystemInfo.distroName + " " + SystemInfo.axosVersion
                    font.pixelSize: Appearance.font.pixelSize.title
                }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.normal
                    text: "https://www.axos-project.com"
                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link)
                    }
                    PointingHandLinkHover {}
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
    ContentSection {
        title: "Sleex"

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            IconImage {
               implicitSize: 100
               source: "file:///usr/share/pixmaps/sleex/svg/dark.svg"
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                // spacing: 10
                StyledText {
                    text: "Sleex"
                    font.pixelSize: Appearance.font.pixelSize.title
                }
                StyledText {
                    text: "https://github.com/axos-project/sleex"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link)
                    }
                    PointingHandLinkHover {}
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

    Item {
        implicitHeight: 24
    }

}
