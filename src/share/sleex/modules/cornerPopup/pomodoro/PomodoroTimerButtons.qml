import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    implicitWidth: layoutContainer.implicitWidth + 24
    implicitHeight: layoutContainer.implicitHeight + 20
    color: "transparent"
    Layout.alignment: Qt.AlignVCenter

    ColumnLayout {
        id: layoutContainer
        anchors.centerIn: parent
        spacing: 8

        Grid {
            columns: 2
            spacing: 6
            Layout.alignment: Qt.AlignHCenter

            // +5 min
            Rectangle {
                implicitWidth: 70
                implicitHeight: 30
                radius: Appearance.rounding.small
                color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                border.width: 1
                border.color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.3)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    MaterialSymbol { text: "add"; iconSize: 14; color: Appearance.colors.colPrimary }
                    StyledText { text: "5m"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Medium; color: Appearance.colors.colPrimary }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pomodoro.addMinutes(5)
                }
            }

            // -5 min
            Rectangle {
                implicitWidth: 70
                implicitHeight: 30
                radius: Appearance.rounding.small
                color: ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.5)
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    MaterialSymbol { text: "remove"; iconSize: 14; color: Appearance.colors.colOnLayer1 }
                    StyledText { text: "5m"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Medium; color: Appearance.colors.colOnLayer1 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pomodoro.addMinutes(-5)
                }
            }

            // +1 min
            Rectangle {
                implicitWidth: 70
                implicitHeight: 30
                radius: Appearance.rounding.small
                color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                border.width: 1
                border.color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.3)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    MaterialSymbol { text: "add"; iconSize: 14; color: Appearance.colors.colPrimary }
                    StyledText { text: "1m"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Medium; color: Appearance.colors.colPrimary }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pomodoro.addMinutes(1)
                }
            }

            // -1 min
            Rectangle {
                implicitWidth: 70
                implicitHeight: 30
                radius: Appearance.rounding.small
                color: ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.5)
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    MaterialSymbol { text: "remove"; iconSize: 14; color: Appearance.colors.colOnLayer1 }
                    StyledText { text: "1m"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Medium; color: Appearance.colors.colOnLayer1 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pomodoro.addMinutes(-1)
                }
            }
        }
    }
}
