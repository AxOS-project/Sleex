import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.dashboard.notifications
import qs.modules.dashboard.calendar
import qs.modules.mediaControls
import qs.modules.dashboard.weather
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell.Io
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import Sleex.Services

Rectangle {
    id: root
    color: "transparent"

    property bool connected: Network.networks.filter(n => n.active).length > 0    

    RowLayout {
        id: mainCols
        anchors.fill: parent
        spacing: 10
        
        ColumnLayout {
            id: firstCol
            spacing: 10

            Rectangle {
                id: userInfoWidget
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.normal
                Layout.fillWidth: true
                Layout.preferredHeight: 300

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    width: parent.width * 0.9
                
                    Rectangle {
                        id: userAvatar
                        width: 120
                        height: 120
                        radius: 99
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Appearance.colors.colLayer2

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: 150
                                height: 150
                                radius: 75
                            }
                        }

                        Image {
                            id: userAvatarImage
                            anchors.fill: parent
                            source: Config.options.dashboard.avatarPath
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                            antialiasing: true
                            sourceSize.width: 150
                            sourceSize.height: 150
                        }
                    }

                    Text {
                        text: qsTr("Welcome, %1!").arg(SystemInfo.username)
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: 30
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    StyledText {
                        text: Config.options.dashboard.userDesc
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: 20
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.normal
                Layout.fillWidth: true
                Layout.preferredHeight: 150

                Column{
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: DateTime.time
                        color: Appearance.colors.colPrimary
                        font.pixelSize: 60
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: DateTime.longDateFormat
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: 20
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
            }

            Rectangle {
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.normal
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                Column{
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        visible: root.connected
                        text: root.connected ? Github.contribution_number || qsTr("Loading...") : qsTr("--")
                        color: Appearance.colors.colPrimary
                        font.pixelSize: 60
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: root.connected ? qsTr("contributions in the last year") : "No network connection"
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: 20
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Loader {
                        active: root.connected
                        anchors.horizontalCenter: parent.horizontalCenter
                        sourceComponent: GhCalendar {}
                    }

                    Loader {
                        active: !root.connected
                        anchors.horizontalCenter: parent.horizontalCenter
                        sourceComponent: GhCalendarNoNet {}
                    }

                    Text {
                        text: `@${Github.author}`
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
            }
        }
        
        NotificationList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            anchors.margins: 15
        }
        
        ColumnLayout {
            id: thirdCol
            spacing: 10

            MediaControls {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
            }

            Rectangle {
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.normal
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Column {
                //     anchors.left: parent.left
                //     anchors.right: parent.right
                //     anchors.verticalCenter: parent.verticalCenter
                //     anchors.margins: 20
                //     spacing: 10
                    
                //     Text {
                //         text: Weather.temperature || qsTr("--")
                //         font.bold: true
                //         color: Appearance.colors.colPrimary
                //         font.pixelSize: 60
                //         anchors.horizontalCenter: parent.horizontalCenter
                //     }

                //     Text {
                //         text: Weather.condition || qsTr("Loading...")
                //         font.pixelSize: 20
                //         color: Appearance.colors.colOnLayer1
                //         width: parent.width
                //         wrapMode: Text.WordWrap
                //         horizontalAlignment: Text.AlignHCenter
                //         maximumLineCount: 2
                //         elide: Text.ElideRight
                //     }
                // }

                Loader {
                    active: !Config.options.dashboard.enableWeather
                    anchors.fill: parent
                    sourceComponent: WeatherOff {
                        id: weatherWidgetOff
                        anchors.fill: parent
                    }
                }

                Loader {
                    active: Config.options.dashboard.enableWeather && root.connected
                    anchors.fill: parent
                    sourceComponent: Weather {
                        id: weatherWidget
                        anchors.fill: parent
                    }
                }

                Loader {
                    active: Config.options.dashboard.enableWeather && !root.connected
                    anchors.fill: parent
                    sourceComponent: WeatherNoNet {
                        id: weatherWidgetNoNet
                        anchors.fill: parent
                    }
                }
                

            }

            Rectangle {
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.normal
                Layout.fillWidth: true
                Layout.preferredHeight: 375

                CalendarWidget {}
            }

        }
    }

    Rectangle {
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.normal
        Layout.fillWidth: true
        Layout.preferredHeight: 150
    }

}