// https://github.com/AvengeMedia/DankMaterialShell/blob/master/Services/CalendarService.qml

import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import Qt.labs.platform
import qs.modules.common.functions
import qs.modules.common

Singleton {
    id: root

    property bool khalAvailable: false
    property bool isLoading: true
    property var events: []
    property var weekdays: [
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday"
    ]
    property var sortedWeekdays: root.weekdays.map((_, i) => weekdays[(i + Config.options.time.firstDayOfWeek + 1) % 7])
    property var eventsInWeek: [
        {
            name: sortedWeekdays[0],
            events: [
                {
                    title: "Example: This is a sample event\nUse khal to add real events",
                    start: "7:30",
                    end: "9:20",
                    color: Appearance.m3colors.m3error,
                    uid: "example-uid-1"
                },
            ]
        },
        {
            name: sortedWeekdays[1],
            events: []
        },
        {
            name: sortedWeekdays[2],
            events: []
        },
        {
            name: sortedWeekdays[3],
            events: []
        },
        {
            name: sortedWeekdays[4],
            events: []
        },
        {
            name: sortedWeekdays[5],
            events: []
        },
        {
            name: sortedWeekdays[6],
            events: []
        }
    ]

    // Process for checking khal configuration
    Process {
        id: khalCheckProcess

        command: ["khal", "list", "today"]
        running: true
        onExited: (exitCode) => {
            root.khalAvailable = (exitCode === 0)
            if (root.khalAvailable) {
                interval.running = true
            }
        }
    }

    function getTasksByDate(currentDate) {
        if (!khalAvailable) {
            return []
        }
        const res = []

        const currentDay = currentDate.getDate()
        const currentMonth = currentDate.getMonth()
        const currentYear = currentDate.getFullYear()

        for (let i = 0; i < root.events.length; i++) {
            const taskDate = new Date(root.events[i]['startDate'])
            if (
                taskDate.getDate() === currentDay &&
                taskDate.getMonth() === currentMonth &&
                taskDate.getFullYear() === currentYear
            ) {
                res.push(root.events[i])
            }
        }

        return res
    }

    function getEventsInWeek() {
        const d = new Date()
        const num_day_today = d.getDay()
        let result = []
        for (let i = 0; i < root.weekdays.length; i++) {
            const dayOffset = (i + Config.options.time.firstDayOfWeek + 1)
            d.setDate(d.getDate() - d.getDay() + dayOffset % 7)
            const events = this.getTasksByDate(d)
            const name_weekday = root.weekdays[d.getDay()]
            let obj = {
                "name": name_weekday,
                "events": []
            }
            events.forEach((evt, i) => {
                let start_time = Qt.formatDateTime(evt["startDate"], "hh:mm")
                let end_time = Qt.formatDateTime(evt["endDate"], "hh:mm")
                let title = evt["content"]
                obj["events"].push({
                    "start": start_time,
                    "end": end_time,
                    "title": title,
                    "color": evt['color'],
                    "uid": evt['uid']
                })
            })
            result.push(obj)
        }

        return result
    }

    // Process for loading events
    Process {
        id: getEventsProcess
        running: false
        command: [
            "khal", "list",
            "--json", "title",
            "--json", "start-date",
            "--json", "start-time",
            "--json", "end-time",
            "--json", "uid",
            Qt.formatDate((() => { let d = new Date(); d.setMonth(d.getMonth() - 3); return d; })(), "dd/MM/yyyy"),
            Qt.formatDate((() => { let d = new Date(); d.setMonth(d.getMonth() + 3); return d; })(), "dd/MM/yyyy")
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let events = []
                let lines = this.text.split('\n')
                for (let line of lines) {
                    line = line.trim()
                    if (!line || line === "[]")
                        continue
                    let dayEvents = JSON.parse(line)
                    for (let event of dayEvents) {
                        let startDateParts = event['start-date'].split('/')
                        let startTimeParts = event['start-time']
                            ? event['start-time'].split(':').map(Number)
                            : [0, 0]

                        let endTimeParts = event['end-time']
                            ? event['end-time'].split(':').map(Number)
                            : [23, 59] // all day event

                        let startDate = new Date(
                            parseInt(startDateParts[2]),
                            parseInt(startDateParts[1]) - 1,
                            parseInt(startDateParts[0]),
                            parseInt(startTimeParts[0]),
                            parseInt(startTimeParts[1])
                        )

                        let endDate = new Date(
                            parseInt(startDateParts[2]),
                            parseInt(startDateParts[1]) - 1,
                            parseInt(startDateParts[0]),
                            parseInt(endTimeParts[0]),
                            parseInt(endTimeParts[1])
                        )

                        events.push({
                            "content": event['title'],
                            "startDate": startDate,
                            "endDate": endDate,
                            "color": ColorUtils.stringToColor(event['title']),
                            "uid": event['uid']
                        })
                    }
                }
                root.events = events
                root.eventsInWeek = root.getEventsInWeekWithOffset(root.currentWeekOffset)
                root.isLoading = false
            }
        }
    }

    Process {
        id: syncProcess
        running: Config.options.dashboard.calendar.useVdirsyncer && !getEventsProcess.running
        command: ["vdirsyncer", "sync"]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                getEventsProcess.running = true
            } else {
                console.log("Error syncing calendars: " + exitCode)
            }
        }
    }

    function syncCalendars() {
        root.isLoading = true
        if (Config.options.dashboard.calendar.useVdirsyncer) {
            syncProcess.running = true
        } else {
            getEventsProcess.running = true
        }
    }

    Timer {
        id: interval
        running: false
        interval: Config.options.dashboard.calendar.syncInterval * 60000
        repeat: true
        onTriggered: {
            getEventsProcess.running = true
        }
    }

    Timer {
        id: syncInterval
        running: Config.options.dashboard.calendar.useVdirsyncer
        interval: 600000 // 10 minutes
        repeat: true
        onTriggered: {
            syncProcess.running = true
        }
    }

    Process {
        id: khalAddTaskProcess
        running: false
    }

    function addItem(item) {
        root.isLoading = true
        if (!item || !item.content) {
            console.error("Cannot add event: missing required fields")
            return false
        }

        let title = item.content
        let formattedDate

        if (item.date) {
            const parts = item.date.split('-')
            formattedDate = `${parts[2]}/${parts[1]}/${parts[0]}`
        } else {
            formattedDate = Qt.formatDate(new Date(), "dd/MM/yyyy")
        }

        let cmd = ["khal", "new"]

        if (!item.allDay && item.start) {
            cmd.push(`${formattedDate} ${item.start}`)
            if (item.end) {
                cmd.push(`${item.end}`)
            }
        } else {
            cmd.push(formattedDate)
        }

        cmd.push(title)
        khalAddTaskProcess.command = cmd
        khalAddTaskProcess.running = true
        if (Config.options.dashboard.calendar.useVdirsyncer) syncProcess.running = true
        return true
    }

    Process {
        id: khalRemoveProcess
        running: false
    }

    function removeItem(item) {
        root.isLoading = true
        let taskToDelete = item['uid']
        khalRemoveProcess.command = [
            "sqlite3",
            String(StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]).replace("file://", "") + "/.local/share/khal/khal.db",
            "DELETE FROM events WHERE item LIKE '%UID:" + taskToDelete + "%';"
        ]
        khalRemoveProcess.running = true
        console.log(khalRemoveProcess.command)
        if (Config.options.dashboard.calendar.useVdirsyncer) syncProcess.running = true
    }

    Process {
        id: khalEditProcess
        running: false
    }

    function editItem(uid, item) {
        root.isLoading = true

        if (!uid || !item || !item.content) {
            console.error("Cannot edit event: missing required fields")
            return false
        }

        let title = item.content
        let formattedDate

        if (item.date) {
            const parts = item.date.split('-')
            formattedDate = `${parts[2]}/${parts[1]}/${parts[0]}`
        } else {
            formattedDate = Qt.formatDate(new Date(), "dd/MM/yyyy")
        }

        let cmd = ["khal", "edit", "--show-past", uid]

        if (!item.allDay && item.start) {
            cmd.push(`${formattedDate} ${item.start}`)
            if (item.end) {
                cmd.push(`${item.end}`)
            }
        } else {
            cmd.push(formattedDate)
        }

        cmd.push(title)
        console.log("Running command:", cmd.join(' '))
        khalEditProcess.command = cmd
        khalEditProcess.running = true
        if (Config.options.dashboard.calendar.useVdirsyncer) syncProcess.running = true
        return true
    }

    property int currentWeekOffset: 0

    function nextWeek() {
        root.currentWeekOffset += 1
        root.eventsInWeek = root.getEventsInWeekWithOffset(root.currentWeekOffset)
    }

    function previousWeek() {
        root.currentWeekOffset -= 1
        root.eventsInWeek = root.getEventsInWeekWithOffset(root.currentWeekOffset)
    }

    function getEventsInWeekWithOffset(offset) {
        const today = new Date()
        const firstDayOfWeek = Config.options.time.firstDayOfWeek + 1
        let result = []
        for (let i = 0; i < root.weekdays.length; i++) {
            let d = new Date(today)
            d.setDate(today.getDate() - today.getDay() + ((i + firstDayOfWeek) % 7) + offset * 7)
            const events = root.getTasksByDate(d)
            const name_weekday = root.weekdays[d.getDay()]
            let obj = {
                "name": name_weekday,
                "events": []
            }
            events.forEach((evt) => {
                let start_time = Qt.formatDateTime(evt["startDate"], "hh:mm")
                let end_time = Qt.formatDateTime(evt["endDate"], "hh:mm")
                let title = evt["content"]
                obj["events"].push({
                    "start": start_time,
                    "end": end_time,
                    "title": title,
                    "color": evt['color'],
                    "uid": evt['uid']
                })
            })
            result.push(obj)
        }
        return result
    }
}
