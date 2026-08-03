import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    implicitWidth: 200
    implicitHeight: 140
    radius: Appearance.rounding.small
    color: "transparent"
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    Layout.alignment: Qt.AlignVCenter

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                text: "Laps"
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer2
                Layout.fillWidth: true
            }

            StyledText {
                text: Stopwatch.laps.length + " recorded"
                font.pixelSize: 11
                color: Appearance.colors.colOnLayer2
                opacity: 0.7
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colOutlineVariant
            opacity: 0.3
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledText {
                anchors.centerIn: parent
                visible: Stopwatch.laps.length === 0
                text: "No laps recorded"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer2
                opacity: 0.6
            }

            ListView {
                anchors.fill: parent
                visible: Stopwatch.laps.length > 0
                model: Stopwatch.laps
                clip: true
                spacing: 4

                delegate: RowLayout {
                    width: parent ? parent.width : 0
                    spacing: 8

                    StyledText {
                        text: "Lap " + modelData.number
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Appearance.colors.colPrimary
                        Layout.preferredWidth: 45
                    }

                    StyledText {
                        text: "+" + modelData.lapTime
                        font.pixelSize: 12
                        color: Appearance.colors.colOnLayer1
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: modelData.totalTime
                        font.pixelSize: 11
                        color: Appearance.colors.colOnLayer2
                        opacity: 0.8
                    }
                }
            }
        }
    }
}
