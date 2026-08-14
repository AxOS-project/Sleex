import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import "./calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    // Layout.topMargin: 10
    property int monthShift: 0
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)

    anchors.fill: parent
    clip: true

    function buildEventCalendar(grid) {
        const eventsByDay = new Map()
        if (CalendarService.khalAvailable) {
            for (const evt of CalendarService.events) {
                const start = evt.startDate
                const key = start.getFullYear() * 400 + start.getMonth() * 32 + start.getDate()
                const bucket = eventsByDay.get(key)
                if (bucket) bucket.push(evt)
                else eventsByDay.set(key, [evt])
            }
        }

        const noEvents = []
        const out = []
        for (let r = 0; r < grid.length; r++) {
            const row = []
            for (let c = 0; c < grid[r].length; c++) {
                const cell = grid[r][c]
                const date = cell.date
                const key = date.getFullYear() * 400 + date.getMonth() * 32 + date.getDate()
                row.push({
                    "day": cell.day,
                    "today": cell.today,
                    "events": eventsByDay.get(key) || noEvents
                })
            }
            out.push(row)
        }
        return out
    }

    property var eventCalendar: buildEventCalendar(calendarLayout)

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.normal
    }
    

    MouseArea {
        anchors.fill: parent
        onWheel: (event) => {
            if (event.angleDelta.y > 0) {
                monthShift--;
            } else if (event.angleDelta.y < 0) {
                monthShift++;
            }
        }
    }

    ColumnLayout {
        id: calendarColumn
        anchors.fill: parent
        anchors.margins: 12
        

        // Calendar header
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            CalendarHeaderButton {
                clip: true
                buttonText: `${monthShift != 0 ? "• " : ""}${viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")}`
                tooltipText: (monthShift === 0) ? "" : qsTr("Jump to current month")
                onClicked: {
                    monthShift = 0;
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
            CalendarHeaderButton {
                forceCircle: true
                onClicked: {
                    monthShift--;
                }
                contentItem: MaterialSymbol {
                    text: "chevron_left"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
            CalendarHeaderButton {
                forceCircle: true
                onClicked: {
                    monthShift++;
                }
                contentItem: MaterialSymbol {
                    text: "chevron_right"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        // Week days row
        RowLayout {
            id: weekDaysRow
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 5
            Repeater {
                model: CalendarLayout.weekDays
                delegate: CalendarDayButton {
                    day: modelData.day
                    isToday: modelData.today
                    bold: true
                    enabled: false
                }
            }
        }

        // Real week rows
        Repeater {
            id: calendarRows
            // model: calendarLayout
            model: 6
            delegate: RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5
                Repeater {
                    model: Array(7).fill(modelData)
                    delegate: CalendarDayButton {
                        day: eventCalendar[modelData][index].day
                        isToday: eventCalendar[modelData][index].today
                        dayEvents: eventCalendar[modelData][index].events
                    }
                }
            }
        }
    }
}
