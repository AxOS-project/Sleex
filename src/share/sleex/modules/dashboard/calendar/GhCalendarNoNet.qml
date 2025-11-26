import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: contributionCalendar
    width: 300
    height: 60

    GridLayout {
        anchors.centerIn: parent
        rows: 7
        columns: 40
        rowSpacing: 2
        columnSpacing: 2

        RowLayout {
            spacing: 2

            Repeater {
                model: 40  // weeks
                delegate: ColumnLayout {
                    spacing: 2

                    Repeater {
                        model: 7  // days
                        delegate: Rectangle {
                            width: 7
                            height: 7
                            radius: 2

                            color: Appearance.colors.colLayer2
                        }
                    }
                }
            }
        }

    }
}
