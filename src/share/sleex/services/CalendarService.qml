// https://github.com/AvengeMedia/DankMaterialShell/blob/master/Services/CalendarService.qml

import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import Qt.labs.platform
import SleexUiKit.Functions
import SleexUiKit.Appearance

Singleton {
    id: root

    Component.onCompleted: {
        root._notifiedReminders = {}
        Qt.callLater(root._rearmReminderTimer)
        // console.log("[CalendarService] initialized. khalAvailable=" + root.khalAvailable + " isLoading=" + root.isLoading)
    }

    property bool khalAvailable: false
    property bool isLoading: true

    property bool manualRefresh: false
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

    property bool resyncInFlight: false
    property bool resyncPending: false

    property int _stateGeneration: 0
    property int _resyncRequestGeneration: 0

    function requestResync() {
        if (root.resyncInFlight) {
            root.resyncPending = true
            return
        }
        root._startResync()
    }

    function _startResync() {
        root.resyncInFlight = true
        root._resyncRequestGeneration = root._stateGeneration

        if (Config.options.dashboard.calendar.useVdirsyncer) {
            syncProcess.running = true
        } else {
            getEventsProcess.running = true
        }
    }

    function _resyncFinished() {
        root.manualRefresh = false
        root.resyncInFlight = false
        if (root.resyncPending) {
            root.resyncPending = false
            root._startResync()
        } else {
            root.isLoading = false
        }
    }

    // Process for checking khal configuration
    Process {
        id: khalCheckProcess

        command: ["khal", "list", "today"]
        running: true
        onExited: (exitCode) => {
            root.khalAvailable = (exitCode === 0)
            // console.log("[CalendarService] khalCheckProcess exited with code", exitCode, "khalAvailable=", root.khalAvailable)
            if (root.khalAvailable) {
                // console.log("[CalendarService] khal available — starting initial sync and enabling interval")
                // Start an initial sync immediately and enable the periodic interval
                syncCalendars()
                interval.running = true
            } else {

                root.isLoading = false
            }
        }
    }

    function getTasksByDate(currentDate) {
        // console.log("[CalendarService] getTasksByDate for", currentDate.toDateString(), "khalAvailable=", khalAvailable)
        if (!khalAvailable) {
            // console.log("[CalendarService] khal not available, returning empty list")
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
        // console.log("[CalendarService] getEventsInWeek called")
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
                    "date": Qt.formatDateTime(evt["startDate"], "yyyy-MM-dd"),
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
            "bash", "-c",
            "khal list --json title --json start-date --json start-time --json end-time --json uid \"$1\" \"$2\" || exit $?;" +
            " echo '@@CUSTOM-COLORS@@';" +
            " find \"$HOME\" -name '*.ics' -exec grep -l '^X-SLEEX-COLOR:' {} + 2>/dev/null | while read -r f; do" +
            " u=$(grep -m1 '^UID:' \"$f\" | cut -d: -f2-); c=$(grep -m1 '^X-SLEEX-COLOR:' \"$f\" | cut -d: -f2-);" +
            " [ -n \"$u\" ] && [ -n \"$c\" ] && echo \"$u $c\"; done",
            "_",
            Qt.formatDate((() => { let d = new Date(); d.setMonth(d.getMonth() - 3); return d; })(), "dd/MM/yyyy"),
            Qt.formatDate((() => { let d = new Date(); d.setMonth(d.getMonth() + 3); return d; })(), "dd/MM/yyyy")
        ]
        stdout: StdioCollector {
            id: stdoutCollector
            onStreamFinished: {
                    // console.log("[CalendarService] getEventsProcess stdout finished; parsing events")
                    // Handle blank output gracefully
                    if (!this.text || String(this.text).trim().length === 0) {
                        console.warn("[CalendarService] khal returned blank output; treating as zero events")
                        root._applyFreshEvents([])
                        root._resyncFinished()
                        return
                    }

                    let events = []
                    const source = String(this.text)
                    const colorMarker = "@@CUSTOM-COLORS@@"
                    const markerIndex = source.indexOf(colorMarker)
                    const khalOutput = markerIndex >= 0 ? source.slice(0, markerIndex) : source
                    const colorsOutput = markerIndex >= 0 ? source.slice(markerIndex + colorMarker.length) : ""

                    root._customColors = {}
                    for (let line of colorsOutput.split('\n')) {
                        line = line.trim()
                        if (!line) continue
                        const sep = line.indexOf(' ')
                        if (sep <= 0) continue
                        const uid = line.slice(0, sep)
                        const color = line.slice(sep + 1).trim()
                        if (uid && color) root._customColors[uid] = color
                    }

                    let lines = khalOutput.split('\n')
                for (let line of lines) {
                    line = line.trim()
                    if (!line || line === "[]")
                        continue
                    let dayEvents
                    try {
                        dayEvents = JSON.parse(line)
                    } catch (e) {
                        console.error("[CalendarService] JSON parse error while reading khal output:", e, "line:", line)
                        continue
                    }
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

                        const customColor = root._customColors[event['uid']] || ""

                        events.push({
                            "content": event['title'],
                            "startDate": startDate,
                            "endDate": endDate,
                            "color": customColor || ColorUtils.stringToColor(event['title']),
                            "uid": event['uid'],
                            "allDay": !event['start-time'] && !event['end-time'],
                            "customColor": !!customColor
                        })
                    }
                }
                // console.log("[CalendarService] parsed events count=", events.length)
                root._applyFreshEvents(events)
                root._resyncFinished()
            }
        }
        onStarted: {
            // console.log("[CalendarService] getEventsProcess started; command=", getEventsProcess.command.join(' '))
        }
        onExited: (exitCode) => {
            // console.log("[CalendarService] getEventsProcess exited with code=", exitCode, "stdout_len=", stdoutCollector.text ? stdoutCollector.text.length : 0)
            if (exitCode !== 0) {
                console.error("[CalendarService] getEventsProcess failed with exit code", exitCode)
                root._resyncFinished()
            }
        }
    }

    Process {
        id: syncProcess
        running: false
        command: ["vdirsyncer", "sync"]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                // console.log("[CalendarService] syncProcess completed successfully")
                getEventsProcess.running = true
            } else {
                // console.log("Error syncing calendars: " + exitCode)
                console.error("[CalendarService] vdirsyncer sync failed with exit code", exitCode)
                root._resyncFinished()
            }
        }
    }

    function syncCalendars() {
        root.manualRefresh = true
        root.requestResync()
    }

    property bool dragSuspended: false

    property var pendingEventsInWeek: null
    property int _pendingGeneration: -1

    function _applyFreshEvents(events) {
        if (root._resyncRequestGeneration !== root._stateGeneration) {
            return
        }
        root.events = events
        const rebuilt = root.getEventsInWeekWithOffset(root.currentWeekOffset)
        if (root.dragSuspended) {
            root.pendingEventsInWeek = rebuilt
            root._pendingGeneration = root._resyncRequestGeneration
        } else {
            root.eventsInWeek = rebuilt
        }
    }

    onDragSuspendedChanged: {
        if (!root.dragSuspended && root.pendingEventsInWeek) {
            const pending = root.pendingEventsInWeek
            const pendingGeneration = root._pendingGeneration
            root.pendingEventsInWeek = null
            root._pendingGeneration = -1
            if (pendingGeneration === root._stateGeneration) {
                root.eventsInWeek = pending
            }
        }
    }


    function _periodicResync() {
        if (!root.dragSuspended) root.requestResync()
    }

    Timer {
        id: interval
        running: false
        interval: Config.options.dashboard.calendar.syncInterval * 60000
        repeat: true
        onTriggered: root._periodicResync()
    }

    Timer {
        id: syncInterval
        running: Config.options.dashboard.calendar.useVdirsyncer
        interval: 600000 // 10 minutes
        repeat: true
        onTriggered: root._periodicResync()
    }

    property bool remindersEnabled: Config.options.dashboard.calendar.reminders
    property int reminderTime: Config.options.dashboard.calendar.reminderTime
    property var _notifiedReminders

    onRemindersEnabledChanged: Qt.callLater(root._rearmReminderTimer)
    onReminderTimeChanged: Qt.callLater(root._rearmReminderTimer)
    onEventsChanged: Qt.callLater(root._rearmReminderTimer)

    function _pruneNotifiedReminders(now) {
        for (const key of Object.keys(root._notifiedReminders)) {
            if (root._notifiedReminders[key] < now) delete root._notifiedReminders[key]
        }
    }

    function _rearmReminderTimer() {
        if (!root._notifiedReminders) root._notifiedReminders = {}
        reminderTimer.stop()
        if (!root.remindersEnabled || root.reminderTime <= 0) return

        const now = Date.now()
        root._pruneNotifiedReminders(now)
        let earliest = null
        for (let i = 0; i < root.events.length; i++) {
            const evt = root.events[i]
            if (evt.allDay || !evt.startDate) continue
            const start = new Date(evt.startDate).getTime()
            if (start <= now) continue
            if (root._notifiedReminders[evt.uid + "@" + start]) continue
            const reminderAt = start - root.reminderTime * 60000
            if (earliest === null || reminderAt < earliest) earliest = reminderAt
        }

        if (earliest === null) return
        const delay = Math.max(250, earliest - now)
        reminderTimer.interval = Math.min(delay, 2147483647)
        reminderTimer.start()
    }

    function _fireDueReminders() {
        if (!root._notifiedReminders) root._notifiedReminders = {}
        const now = Date.now()
        const tolerance = 1000
        for (let i = 0; i < root.events.length; i++) {
            const evt = root.events[i]
            if (evt.allDay || !evt.startDate) continue
            const start = new Date(evt.startDate).getTime()
            if (start <= now) continue
            const reminderAt = start - root.reminderTime * 60000
            if (reminderAt - tolerance > now) continue
            const key = evt.uid + "@" + start
            if (root._notifiedReminders[key]) continue
            root._notifiedReminders[key] = start
            root._sendReminderNotification(evt)
        }

        root._pruneNotifiedReminders(now)

        Qt.callLater(root._rearmReminderTimer)
    }

    function _sendReminderNotification(evt) {
        const startTime = Qt.formatDateTime(evt.startDate, Config.options?.time.format ?? "hh:mm")
        if (Config.options.dashboard.calendar.reminderSound)
            Audio.playSound("assets/sounds/battery/calendar_reminder.mp3")
        Quickshell.execDetached(["notify-send", qsTr("Upcoming event"), `${evt.content} at ${startTime}`, "-a", "Sleex"])
    }

    Timer {
        id: reminderTimer
        interval: 1
        repeat: false
        onTriggered: root._fireDueReminders()
    }

    function _buildNewEventCommand(item) {
        const title = item.content
        let formattedDate

        if (item.date) {
            const parts = item.date.split('-')
            formattedDate = `${parts[2]}/${parts[1]}/${parts[0]}`
        } else {
            formattedDate = Qt.formatDate(new Date(), "dd/MM/yyyy")
        }

        const cmd = ["khal", "new"]

        if (!item.allDay && item.start) {
            cmd.push(`${formattedDate} ${item.start}`)
            if (item.end) {
                cmd.push(`${item.end}`)
            }
        } else {
            cmd.push(formattedDate)
        }

        cmd.push(title)
        return cmd
    }

    property var _mutationQueue: []
    property var _customColors: ({})
    property bool _mutationBusy: false

    function _enqueueMutation(job) {
        root._mutationQueue.push(job)
        root._pumpMutationQueue()
    }

    function _pumpMutationQueue() {
        if (root._mutationBusy) return

        if (root._mutationQueue.length === 0) {

            root.requestResync()
            return
        }

        root._mutationBusy = true
        const job = root._mutationQueue.shift()

        if (job.kind === "add") {
            khalAddTaskProcess.command = job.payload.color
                ? root._buildCreateCommand(job.payload)
                : root._buildNewEventCommand(job.payload)
            khalAddTaskProcess.running = true
        } else if (job.kind === "edit") {
            khalEditProcess.command = root._buildRewriteCommand(job.payload.uid, job.payload.item)
            khalEditProcess.running = true
        } else if (job.kind === "remove") {
            khalRemoveProcess.command = root._buildRemoveCommand(job.payload)
            khalRemoveProcess.running = true
        }
    }

    function _mutationSettled() {
        root._mutationBusy = false
        root._pumpMutationQueue()
    }

    function _onMutationExited(label, exitCode) {
        if (exitCode !== 0) {
            console.error("[CalendarService] " + label + " failed with exit code", exitCode)
        }
        root._mutationSettled()
    }

    Process {
        id: khalAddTaskProcess
        running: false
        onExited: (exitCode) => root._onMutationExited("khal new", exitCode)
    }

    function addItem(item) {

        if (!item || !item.content) {
            console.error("[CalendarService] Cannot add event: missing required fields")
            return false
        }

        root.manualRefresh = true
        root._stateGeneration++
        root._enqueueMutation({ kind: "add", payload: item })
        return true
    }

    Process {
        id: khalRemoveProcess
        running: false
        onExited: (exitCode) => root._onMutationExited("event file removal", exitCode)
    }

    property string _icsLookup: 'grep -rlZF --include="*.ics" "UID:$1" "$HOME" 2>/dev/null'

    function _buildRemoveCommand(uid) {
        return [
            "bash", "-c",
            root._icsLookup + " | xargs -0 -r rm -f --",
            "_", uid
        ]
    }

    function _buildIcsBody(uid, item) {
        const pad = (n) => String(n).padStart(2, '0')
        const dateStr = item.date || Qt.formatDate(new Date(), "yyyy-MM-dd")
        const dateParts = String(dateStr).split('-')
        const icsDate = dateParts[0] + dateParts[1] + dateParts[2]
        const icsTime = (t) => {
            const hm = root._parseHM(t)
            return hm ? pad(hm.hour) + pad(hm.minute) + '00' : '000000'
        }
        const escapeIcsText = (text) => String(text)
            .replace(/\\/g, "\\\\")
            .replace(/;/g, "\\;")
            .replace(/,/g, "\\,")
            .replace(/\r/g, "")
            .replace(/\n/g, "\\n")

        const now = new Date()
        const stamp = String(now.getFullYear()) + pad(now.getMonth() + 1) + pad(now.getDate()) +
            "T" + pad(now.getHours()) + pad(now.getMinutes()) + "00Z"

        const lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Quickshell Calendar//EN",
            "BEGIN:VEVENT",
            "UID:" + uid,
            "DTSTAMP:" + stamp,
            "X-SLEEX-COLOR:@@COLOR@@"
        ]

        if (!item.allDay && item.start) {
            lines.push("DTSTART:" + icsDate + "T" + icsTime(item.start))
            if (item.end) {
                let endDateStr = icsDate
                const startMin = parseInt(item.start.split(':')[0]) * 60 + parseInt(item.start.split(':')[1])
                const endMin = parseInt(item.end.split(':')[0]) * 60 + parseInt(item.end.split(':')[1])
                if (endMin <= startMin) {
                    const d = new Date(dateParts[0], dateParts[1] - 1, dateParts[2])
                    d.setDate(d.getDate() + 1)
                    endDateStr = String(d.getFullYear()) + pad(d.getMonth() + 1) + pad(d.getDate())
                }
                lines.push("DTEND:" + endDateStr + "T" + icsTime(item.end))
            }
        } else {
            lines.push("DTSTART;VALUE=DATE:" + icsDate)

            const d = new Date(dateParts[0], dateParts[1] - 1, dateParts[2])
            d.setDate(d.getDate() + 1)
            lines.push("DTEND;VALUE=DATE:" + String(d.getFullYear()) + pad(d.getMonth() + 1) + pad(d.getDate()))
        }

        lines.push("SUMMARY:" + escapeIcsText(item.content))
        lines.push("END:VEVENT")
        lines.push("END:VCALENDAR")

        return lines.join("\n") + "\n"
    }

    function _buildRewriteCommand(uid, item) {
        const quotedBody = root._buildIcsBody(uid, item).replace(/'/g, "'\\''")
        const findScript = "f=$(" + root._icsLookup + " | tr '\\0' '\\n' | head -n1); [ -n \"$f\" ] || exit 0;"
        const colorScript = "col=$2; if [ \"$col\" = NONE ]; then col=; elif [ -z \"$col\" ]; then col=$(grep -m1 '^X-SLEEX-COLOR:' \"$f\" | cut -d: -f2-); fi;"
        const writeScript = "printf '%s' '" + quotedBody + "' > \"$f.tmp.$$\";" +
            " if [ -n \"$col\" ]; then sed -i \"s/@@COLOR@@/$col/\" \"$f.tmp.$$\"; else sed -i '/^X-SLEEX-COLOR:@@COLOR@@$/d' \"$f.tmp.$$\"; fi;" +
            " mv -f -- \"$f.tmp.$$\" \"$f\" && touch -- \"$(dirname \"$f\")\""
        return ["bash", "-c", findScript + " " + colorScript + " " + writeScript, "_", uid, item.color || ""]
    }

    function _buildCreateCommand(item) {
        const quotedBody = root._buildIcsBody("@@UID@@", item).replace(/'/g, "'\\''")
        const script = "uid=$(cat /proc/sys/kernel/random/uuid);" +
            " dir=$(grep -m1 -E '^[[:space:]]*path[[:space:]]*=' \"$HOME/.config/khal/config\" 2>/dev/null | sed -E 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//');" +
            " dir=${dir/#\\~/\"$HOME\"}; [ -z \"$dir\" ] && dir=\"$HOME/.local/share/khal/calendars\";" +
            " mkdir -p \"$dir\" || exit 1;" +
            " printf '%s' '" + quotedBody + "' | sed -e \"s/@@UID@@/$uid/\" -e \"s/@@COLOR@@/$1/\" > \"$dir/$uid.ics\""
        return ["bash", "-c", script, "_", item.color]
    }

    Process {
        id: khalEditProcess
        running: false
        onExited: (exitCode) => root._onMutationExited("event file rewrite", exitCode)
    }

    function removeItem(item) {
        if (!item || !item['uid']) {
            console.error("[CalendarService] Cannot remove event: missing uid")
            return false
        }

        let taskToDelete = item['uid']

        root._stateGeneration++
        root.events = root.events.filter((e) => e['uid'] !== taskToDelete)
        root.eventsInWeek = root.getEventsInWeekWithOffset(root.currentWeekOffset)

        root._enqueueMutation({ kind: "remove", payload: taskToDelete })
        return true
    }

    function editItem(uid, item, silent) {

        if (!uid || !item || !item.content) {
            console.error("[CalendarService] Cannot edit event: missing required fields")
            return false
        }

        if (!silent) {
            root.manualRefresh = true
        }
        root._stateGeneration++
        root.events = root.events.map((e) => {
            if (e['uid'] !== uid) return e
            const parsedDate = root._parseSlashOrDashDate(item.date) || e['startDate']
            let startH = 0, startM = 0, endH = 23, endM = 59
            if (!item.allDay && item.start) {
                const sp = root._parseHM(item.start)
                if (sp) { startH = sp.hour; startM = sp.minute }
            }
            if (!item.allDay && item.end) {
                const ep = root._parseHM(item.end)
                if (ep) { endH = ep.hour; endM = ep.minute }
            }
            const newStart = new Date(parsedDate.getFullYear(), parsedDate.getMonth(), parsedDate.getDate(), startH, startM)
            const newEnd = new Date(parsedDate.getFullYear(), parsedDate.getMonth(), parsedDate.getDate(), endH, endM)

            let newColor = e['color']
            let newCustomColor = !!e['customColor']
            if (item.color === "NONE") {
                newColor = ColorUtils.stringToColor(item.content)
                newCustomColor = false
            } else if (item.color) {
                newColor = item.color
                newCustomColor = true
            }

            return Object.assign({}, e, { startDate: newStart, endDate: newEnd, content: item.content, allDay: !!item.allDay, color: newColor, customColor: newCustomColor })
        })
        root.eventsInWeek = root.getEventsInWeekWithOffset(root.currentWeekOffset)

        root._enqueueMutation({ kind: "edit", payload: { uid: uid, item: item } })
        return true
    }

    function _parseSlashOrDashDate(dateStr) {
        if (!dateStr) return null
        let m = String(dateStr).match(/^(\d{4})-(\d{2})-(\d{2})$/)
        if (m) return new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3]))
        m = String(dateStr).match(/^(\d{2})\/(\d{2})\/(\d{4})$/)
        if (m) return new Date(parseInt(m[3]), parseInt(m[2]) - 1, parseInt(m[1]))
        return null
    }

    function _parseHM(timeStr) {
        if (!timeStr) return null
        let m = String(timeStr).match(/^(\d{1,2}):(\d{2})$/)
        if (m) return { hour: parseInt(m[1]), minute: parseInt(m[2]) }
        m = String(timeStr).match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i)
        if (m) {
            let hour = parseInt(m[1])
            const minute = parseInt(m[2])
            const isPM = m[3].toUpperCase() === 'PM'
            if (hour === 12) hour = 0
            if (isPM) hour += 12
            return { hour, minute }
        }
        return null
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
        // console.log("[CalendarService] getEventsInWeekWithOffset offset=", offset)
        const today = new Date()
        const firstDayOfWeek = Config.options.time.firstDayOfWeek + 1
        
        const currentDayOfWeek = today.getDay()
        const daysFromWeekStart = (currentDayOfWeek - firstDayOfWeek + 7) % 7
        const weekStart = new Date(today)
        weekStart.setDate(today.getDate() - daysFromWeekStart + offset * 7)
        
        let result = []
        for (let i = 0; i < root.weekdays.length; i++) {
            let d = new Date(weekStart)
            d.setDate(weekStart.getDate() + i)
            
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
                    "date": Qt.formatDateTime(evt["startDate"], "yyyy-MM-dd"),
                    "color": evt['color'],
                    "uid": evt['uid'],
                    "allDay": !!evt['allDay'],
                    "customColor": !!evt['customColor']
                })
            })
            result.push(obj)
        }
        return result
    }
}
