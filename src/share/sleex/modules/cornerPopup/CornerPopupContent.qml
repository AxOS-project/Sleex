import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: root
    property int cardWidth: 500
    property int cardHeight: 300
    property int cornerSize: Appearance.rounding.screenRounding ?? 20
    property int currentTab: 0

    width: cardWidth + cornerSize
    height: cardHeight + cornerSize

    RoundCorner {
        id: topLeftInvertedCorner
        anchors.left: parent.left
        anchors.bottom: mainCard.top
        size: root.cornerSize
        corner: cornerEnum.bottomLeft
        color: Appearance.colors.colLayer0
    }

    RoundCorner {
        id: bottomRightInvertedCorner
        anchors.left: mainCard.right
        anchors.bottom: parent.bottom
        size: root.cornerSize
        corner: cornerEnum.bottomLeft
        color: Appearance.colors.colLayer0
    }

    Item {
        id: mainCard
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.cardWidth
        height: root.cardHeight

        Shape {
            id: mainCardShape
            anchors.fill: parent
            antialiasing: true

            readonly property real w: parent.width
            readonly property real h: parent.height
            readonly property real r: Appearance.rounding.large ?? 24

            ShapePath {
                fillColor: Appearance.colors.colLayer0
                strokeWidth: 0
                strokeColor: "transparent"

                startX: 0
                startY: mainCardShape.h

                PathLine { x: 0; y: 0 }
                PathLine { x: mainCardShape.w - mainCardShape.r; y: 0 }

                PathQuad {
                    x: mainCardShape.w
                    y: mainCardShape.r
                    controlX: mainCardShape.w
                    controlY: 0
                }

                PathLine { x: mainCardShape.w; y: mainCardShape.h }
                PathLine { x: 0; y: mainCardShape.h }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            PrimaryTabBar {
                id: tabBar
                Layout.fillWidth: true
                tabButtonList: [
                    { "icon": "timer", "name": "Pomodoro" },
                    { "icon": "timer_3", "name": "Stopwatch" },
                ]
                externalTrackedTab: root.currentTab
                onCurrentIndexChanged: (index) => {
                    root.currentTab = index
                }
            }

            SwipeView {
                id: swipeView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 10
                currentIndex: root.currentTab
                onCurrentIndexChanged: {
                    root.currentTab = currentIndex
                }

                PomodoroTab {}
                StopwatchTab {}
            }
        }
    }
}
