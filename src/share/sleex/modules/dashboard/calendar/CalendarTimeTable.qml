import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.modules.common.functions

Item {
    id: root
    property real spacing: 8
    property color backgroundColor: "transparent"

    property alias addMode: calendarAddComponent.editMode
    property alias editMode: calendarEditComponent.editMode
    

    property var tempCalendarEvent: null // used to pass event to CalendarEdit

    property int startHour: 0
    property int startMinute: 0
    property int endHour: 24
    property int slotDuration: 60 // in minutes
    property int slotHeight: 60 // in pixels
    property int timeColumnWidth: 90
    property real maxContentWidth: parent.width - 10

    readonly property int totalSlots: Math.floor(((endHour * 60) - (startHour * 60 + startMinute)) / slotDuration)
    readonly property real pixelsPerMinute: slotHeight / slotDuration
    readonly property int contentHeight: totalSlots * slotHeight

    property real maxHeight: parent.height
    property real headerHeight: 64 // Material 3 standard header height
    property real currentTimeY: -1
    property bool initialScrollApplied: false
    // Make columns adapt to available space by calculating dayColumnWidth based on available width
    readonly property real dayColumnWidth: (function() {
        if (!root.days || root.days.length === 0) return 100
        // Calculate available space excluding time column and spacing
        const totalWidth = root.maxContentWidth || root.width
        const availableWidth = totalWidth - timeColumnWidth - spacing
        // Calculate exact column width (remove extra spacing at the end)
        return (availableWidth - (root.days.length - 1) * spacing) / root.days.length
    })()

    // Calculate total content width based on the column widths
    readonly property real totalContentWidth: timeColumnWidth + spacing + 
        (root.days ? (root.days.length * dayColumnWidth + (root.days.length - 1) * spacing) : 0)

    readonly property int currentDayIndex: (DateTime.clock.date.getDay() - Config.options.time.firstDayOfWeek+ 6)%7

    implicitWidth: Math.min(maxContentWidth, timeColumnWidth + (dayColumnWidth * days.length) + ((days.length + 1) * spacing))
    implicitHeight: Math.min(headerHeight + contentHeight, maxHeight)
    property var days: CalendarService.eventsInWeek
    readonly property int allDayChipHeight: 36
    readonly property int allDayChipSpacing: 6
    readonly property int maxAllDayEventCount: {
        if (!root.days || root.days.length === 0)
            return 0;

        var maxCount = 0;
        for (var i = 0; i < root.days.length; i++) {
            var day = root.days[i];
            if (!day || !day.events)
                continue;

            var count = 0;
            for (var j = 0; j < day.events.length; j++) {
                if (root.isAllDayEvent(day.events[j]))
                    count++;
            }
            if (count > maxCount)
                maxCount = count;
        }
        return maxCount;
    }
    readonly property bool hasAllDayEvents: maxAllDayEventCount > 0
    readonly property color todayHighlightFill: withOpacity(Appearance.colors.colPrimary, 0.12)
    readonly property color todayHighlightBorder: withOpacity(Appearance.colors.colPrimary, 0.28)

    function updateCurrentTimeLine() {
        let time = DateTime.clock.date;
        let hours = time.getHours();
        let minutes = time.getMinutes();

        let baseTotalMinutes = root.startHour * 60 + root.startMinute;
        let currentTotalMinutes = hours * 60 + minutes;
        let diffMinutes = currentTotalMinutes - baseTotalMinutes;

        currentTimeY = diffMinutes * root.pixelsPerMinute;
    }
    
    function dateForColumn(index) {
        const today = new Date(DateTime.clock.date);
        const firstDayOfWeek = Config.options.time.firstDayOfWeek + 1;
        const offset = CalendarService.currentWeekOffset || 0;
        
        const currentDayOfWeek = today.getDay();
        const daysFromWeekStart = (currentDayOfWeek - firstDayOfWeek + 7) % 7;
        const weekStart = new Date(today);
        weekStart.setDate(today.getDate() - daysFromWeekStart + offset * 7);
        
        const d = new Date(weekStart);
        d.setDate(weekStart.getDate() + index);
        d.setHours(0, 0, 0, 0);
        return d;
    }

    function withOpacity(colorValue, alpha) {
        if (!colorValue)
            return Qt.rgba(0, 0, 0, alpha);

        let color = Qt.color(colorValue);
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function isAllDayEvent(event) {
        if (!event)
            return false;

        let start = event.start || "";
        let end = event.end || "";

        return (start === "00:00" && end === "23:59") ||
               (start === "00:00" && end === "00:00") ||
               (!event.start && !event.end);
    }

    function getAllDayEvents(events) {
        if (!events || !events.length)
            return [];

        return events.filter(function(evt) { return root.isAllDayEvent(evt); });
    }

    function getTimedEvents(events) {
        if (!events || !events.length)
            return [];

        return events.filter(function(evt) { return !root.isAllDayEvent(evt); });
    }

    function formatEventTooltip(event) {
        if (!event)
            return "";

        let title = event.title || qsTr("Event");
        if (root.isAllDayEvent(event))
            return title + "\n" + qsTr("All day");

        let startTotal = root.parseTimeToMinutes(event.start);
        let endTotal = root.parseTimeToMinutes(event.end);

        let formatTime = (totalMinutes) => {
            if (totalMinutes === null)
                return "";
            let hour = Math.floor(totalMinutes / 60);
            let minute = totalMinutes % 60;
            let date = new Date();
            date.setHours(hour, minute, 0, 0);
            return Qt.formatTime(date, Config.options?.time.format ?? "hh:mm");
        };

        let startStr = formatTime(startTotal) || event.start || "";
        let endStr = formatTime(endTotal) || event.end || "";
        let range = startStr && endStr ? startStr + " - " + endStr : startStr || endStr;
        return range ? title + "\n" + range : title;
    }

    function parseTimeToMinutes(timeStr) {
        if (!timeStr)
            return null;
        let parts = timeStr.split(":");
        if (parts.length < 2)
            return null;
        let hour = parseInt(parts[0]);
        let minute = parseInt(parts[1]);
        if (isNaN(hour) || isNaN(minute))
            return null;
        return hour * 60 + minute;
    }

    function earliestEventStartMinutes() {
        if (!root.days || root.days.length === 0)
            return -1;

        var earliest = -1;
        for (var i = 0; i < root.days.length; i++) {
            var timed = root.getTimedEvents(root.days[i]?.events);
            for (var j = 0; j < timed.length; j++) {
                var start = root.parseTimeToMinutes(timed[j].start);
                if (start === null)
                    continue;
                if (earliest === -1 || start < earliest)
                    earliest = start;
            }
        }
        return earliest;
    }

    function scrollToFirstEvent() {
        if (!styledFlickable)
            return;

        let earliest = root.earliestEventStartMinutes();
        let minOfDay = earliest;

        if (minOfDay === -1 || minOfDay <= (root.startHour * 60 + root.startMinute)) {
            styledFlickable.contentY = 0;
            return;
        }

        let diff = minOfDay - (root.startHour * 60 + root.startMinute);
        if (diff < 0)
            diff = 0;

        let targetY = diff * root.pixelsPerMinute - root.slotHeight;
        targetY = Math.max(0, targetY);

        let maxScroll = Math.max(0, styledFlickable.contentHeight - styledFlickable.height);
        if (styledFlickable.height <= 0) {
            Qt.callLater(root.scrollToFirstEvent);
            return;
        }
        styledFlickable.contentY = Math.min(targetY, maxScroll);
    }

    function maybeApplyInitialScroll() {
        if (root.initialScrollApplied)
            return;

        if (!styledFlickable || styledFlickable.height <= 0 || !root.days || root.days.length === 0) {
            Qt.callLater(root.maybeApplyInitialScroll);
            return;
        }

        root.scrollToFirstEvent();
        root.initialScrollApplied = true;
    }

    Connections {
        target: DateTime.clock
        function onDateChanged() {
            root.updateCurrentTimeLine();
        }
    }

    Connections {
        target: CalendarService
        function onEventsInWeekChanged() {
            Qt.callLater(root.maybeApplyInitialScroll);
        }
    }

    Component.onCompleted: {
        root.updateCurrentTimeLine();
        Qt.callLater(root.maybeApplyInitialScroll);
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colSurfaceContainer
        radius: Appearance.rounding.large
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Row {
            id: headerRow
            Layout.fillWidth: true
            Layout.preferredHeight: root.headerHeight
            spacing: root.spacing

            Item {
                width: root.timeColumnWidth
                height: root.headerHeight

                // Current time indicator
                Rectangle {
                    anchors.centerIn: parent
                    height: 32
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSecondaryContainer

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        // RippleButton {
                        //     buttonRadius: Appearance.rounding.full
                        //     width: 35
                        //     height: 35
                        //     onClicked: CalendarService.previousWeek()
                        //     colBackground: Appearance.colors.colSurfaceContainerHigh
                        //     contentItem: MaterialSymbol {
                        //         anchors.centerIn: parent
                        //         horizontalAlignment: Text.AlignHCenter
                        //         font.pixelSize: Appearance.font.pixelSize.title
                        //         text: "chevron_left"
                        //     }
                        // }

                        // RippleButton {
                        //     buttonRadius: Appearance.rounding.full
                        //     width: 35
                        //     height: 35
                        //     onClicked: CalendarService.nextWeek()
                        //     colBackground: Appearance.colors.colSurfaceContainerHigh
                        //     contentItem: MaterialSymbol {
                        //         anchors.centerIn: parent
                        //         horizontalAlignment: Text.AlignHCenter
                        //         font.pixelSize: Appearance.font.pixelSize.title
                        //         text: "chevron_right"
                        //     }
                        // }
                    }
                }
            }
            Repeater {
                model: root.days
                delegate: Item {
                    width: root.dayColumnWidth
                    height: root.headerHeight

                    property var allDayEvents: root.getAllDayEvents(modelData.events)
                    // highlight if this column's date equals today's date (respects week offset)
                    property bool isToday: (function() {
                        const col = root.dateForColumn(index);
                        const now = new Date(DateTime.clock.date);
                        return col.getFullYear() === now.getFullYear()
                            && col.getMonth() === now.getMonth()
                            && col.getDate() === now.getDate();
                    })()

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: 40
                        radius: Appearance.rounding.large
                        color: allDayEvents.length > 0 ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            StyledText {
                                id: dayTitle
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurfaceVariant
                                text: modelData.name
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }

                            StyledText {
                                id: dayDate
                                font.weight: Font.Normal
                                color: Appearance.colors.colOnSurfaceVariant
                                text: {
                                    let dateObj = root.dateForColumn(index);
                                    Qt.formatDate(dateObj, "dd MMM")
                                }
                                font.pixelSize: dayTitle.font.pixelSize * 0.85
                                horizontalAlignment: Text.AlignHCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        HoverHandler {
                            id: allDayHover
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 4
                            spacing: root.allDayChipSpacing

                            Repeater {
                                model: allDayEvents
                                delegate: Rectangle {
                                    width: parent.width
                                    height: root.allDayChipHeight
                                    color: 'transparent'

                                    ToolTip {
                                        visible: allDayHover.hovered
                                        delay: 250
                                        timeout: 0
                                        text: root.formatEventTooltip(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

     

        // Subtle separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Appearance.colors.colOutlineVariant
            Layout.bottomMargin: 8
        }

        // StyledFlickable with calendar grid
        StyledFlickable {
            id: styledFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            flickableDirection: Flickable.VerticalFlick
            clip: true
            // Set contentWidth to match the calculated total content width
            contentWidth: root.totalContentWidth
            contentHeight: root.contentHeight
            topMargin: 20
            bottomMargin: 20

            // Background grid (placed before content to ensure it's behind events)
            Item {
                id: gridBackground
                width: eventsRow.width
                height: contentRow.height
                x: timeColumn.width + root.spacing
                z: -10

                // Hour grid lines (horizontal)
                Repeater {
                    model: root.totalSlots
                    Rectangle {
                        x: 0
                        y: index * root.slotHeight
                        width: parent.width
                        height: 1
                        color: Appearance.colors.colOutlineVariant
                        opacity: 0.6
                    }
                }

                // Vertical grid lines (one per day column)
                Row {
                    spacing: root.spacing
                    
                    Repeater {
                        model: root.days ? root.days.length : 0
                        delegate: Item {
                            width: root.dayColumnWidth
                            height: gridBackground.height
                            
                            // Left border of each day column
                            Rectangle {
                                x: 0
                                y: 0
                                width: 1
                                height: parent.height
                                color: Appearance.colors.colOutlineVariant
                                opacity: 0.7
                            }
                            
                            // Right border of the last column
                            Rectangle {
                                visible: index === (root.days ? root.days.length - 1 : 0)
                                x: parent.width
                                y: 0
                                width: 1
                                height: parent.height
                                color: Appearance.colors.colOutlineVariant
                                opacity: 0.7
                            }
                        }
                    }
                }
            }

            Row {
                id: contentRow
                spacing: root.spacing

                Column {
                    id: timeColumn
                    width: root.timeColumnWidth

                    Repeater {
                        model: root.totalSlots
                        delegate: Item {
                            width: parent.width
                            height: root.slotHeight

                            StyledText {
                                text: {
                                    let totalMinutes = root.startMinute + (index * root.slotDuration);
                                    let hour = root.startHour + Math.floor(totalMinutes / 60);
                                    let minute = totalMinutes % 60;

                                    // Format time based on DateTime format
                                    let testDate = new Date();
                                    testDate.setHours(hour, minute, 0);
                                    return Qt.formatTime(testDate, Config.options?.time.format ?? "hh:mm");
                                }
                                anchors.top: parent.top
                                anchors.topMargin: -font.pixelSize / 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Row {
                    id: eventsRow
                    height: root.contentHeight
                    spacing: root.spacing

                    Repeater {
                        model: root.days
                        delegate: Item {
                            width: root.dayColumnWidth
                            height: parent.height
                            clip: true
                            // highlight if this column's date equals today's date (respects week offset)
                            property bool isToday: (function() {
                                const col = root.dateForColumn(index);
                                const now = new Date(DateTime.clock.date);
                                return col.getFullYear() === now.getFullYear()
                                    && col.getMonth() === now.getMonth()
                                    && col.getDate() === now.getDate();
                            })()
                            property var timedEvents: root.getTimedEvents(modelData.events)

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.large
                                color: isToday ? root.todayHighlightFill : Qt.rgba(0, 0, 0, 0)
                                border.width: isToday ? 1 : 0
                                border.color: isToday ? root.todayHighlightBorder : Qt.rgba(0, 0, 0, 0)
                                z: -1
                            }

                            Repeater {
                                model: timedEvents
                                Rectangle {
                                    width: parent.width - 10
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    radius: Appearance.rounding.large
                                    clip: true
                                    y: {
                                        let startHr = parseInt(modelData.start.split(":")[0]);
                                        let startMin = parseInt(modelData.start.split(":")[1]);
                                        let baseTotalMinutes = root.startHour * 60 + root.startMinute;
                                        let eventTotalMinutes = startHr * 60 + startMin;
                                        let diffMinutes = eventTotalMinutes - baseTotalMinutes;
                                        return diffMinutes * root.pixelsPerMinute;
                                    }
                                    height: {
                                        let startHr = parseInt(modelData.start.split(":")[0]);
                                        let endHr = parseInt(modelData.end.split(":")[0]);
                                        let startMin = parseInt(modelData.start.split(":")[1]);
                                        let endMin = parseInt(modelData.end.split(":")[1]);
                                        let totalMins = (endHr * 60 + endMin) - (startHr * 60 + startMin);
                                        return Math.max(totalMins * root.pixelsPerMinute - 4, 48); // Minimum height for touch targets
                                    }

                                    color: modelData.color || Appearance.colors.colTertiaryContainer

                                    HoverHandler {
                                        id: eventHover
                                    }
                                    Row {
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 4
                                        spacing: 4

                                        RippleButton {
                                            width: 28
                                            height: 28
                                            buttonRadius: Appearance.rounding.large
                                            opacity: eventHover.hovered ? 1 : 0
                                            visible: opacity > 0

                                            colBackgroundHover: Appearance.colors.colSurfaceContainerHigh

                                            Behavior on opacity { NumberAnimation { duration: 120 } }

                                            contentItem: MaterialSymbol {
                                                anchors.fill: parent
                                                horizontalAlignment: Text.AlignHCenter
                                                font.pixelSize: Appearance.font.pixelSize.title
                                                text: "edit"
                                            }

                                            onClicked: {
                                                root.tempCalendarEvent = modelData;
                                                root.editMode = true;
                                            }
                                        }

                                        RippleButton {
                                            width: 28
                                            height: 28
                                            buttonRadius: Appearance.rounding.large
                                            opacity: eventHover.hovered ? 1 : 0
                                            visible: opacity > 0

                                            colBackgroundHover: Appearance.colors.colSurfaceContainerHigh

                                            Behavior on opacity { NumberAnimation { duration: 120 } }

                                            contentItem: MaterialSymbol {
                                                anchors.fill: parent
                                                horizontalAlignment: Text.AlignHCenter
                                                font.pixelSize: Appearance.font.pixelSize.title
                                                text: "cancel"
                                            }

                                            onClicked: CalendarService.removeItem(modelData)
                                        }
                                    }

                                    ToolTip {
                                        visible: eventHover.hovered
                                        delay: 200
                                        timeout: 0
                                        text: root.formatEventTooltip(modelData)
                                    }

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 4

                                        Text {
                                            text: {
                                                let startHr = parseInt(modelData.start.split(":")[0]);
                                                let startMin = parseInt(modelData.start.split(":")[1]);
                                                let endHr = parseInt(modelData.end.split(":")[0]);
                                                let endMin = parseInt(modelData.end.split(":")[1]);

                                                let formatTime = (hour, minute) => {
                                                    let testDate = new Date();
                                                    testDate.setHours(hour, minute, 0);
                                                    return Qt.formatTime(testDate, Config.options?.time.format ?? "hh:mm");
                                                };

                                                return formatTime(startHr, startMin) + " - " + formatTime(endHr, endMin);
                                            }
                                            font.weight: Font.Medium
                                            color: ColorUtils.getContrastingTextColor(modelData.color)
                                            width: parent.width
                                            wrapMode: Text.NoWrap
                                            elide: Text.ElideRight
                                            lineHeight: 1.2
                                        }

                                        Text {
                                            id: eventTitle
                                            text: modelData.title
                                            font.weight: Font.Medium
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            width: parent.width
                                            color: ColorUtils.getContrastingTextColor(modelData.color)
                                            lineHeight: 1.1
                                            visible: !truncated
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: currentTimeLine
                width: contentRow.width
                height: 3
                color: Appearance.colors.colPrimary
                y: root.currentTimeY
                visible: root.currentTimeY >= 0 && root.currentTimeY <= contentRow.height
                z: 10
                radius: Appearance.rounding.unsharpen

                // Material 3 time chip
                Rectangle {
                    x: (timeColumn.width / 2) - (width / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(timeText.implicitWidth + 20, timeColumn.width - 4)
                    height: 32
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colPrimary

                    Text {
                        id: timeText
                        anchors.centerIn: parent
                        text: DateTime.time
                        color: Appearance.colors.colOnPrimary
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    Row {
        spacing: 10
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 16

        RippleButton {
            width: 50
            height: 50
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            anchors.verticalCenter: parent.verticalCenter

            onClicked: CalendarService.previousWeek();

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.title * 1.5
                color: Appearance.colors.colOnPrimary
                text: "chevron_left"
            }
        }

        RippleButton {
            width: 50
            height: 50
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            anchors.verticalCenter: parent.verticalCenter

            onClicked: CalendarService.nextWeek();

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.title * 1.5
                color: Appearance.colors.colOnPrimary
                text: "chevron_right"
            }
        }

        RippleButton {
            width: 50
            height: 50
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            anchors.verticalCenter: parent.verticalCenter

            onClicked: CalendarService.syncCalendars();

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.title * 1.5
                color: Appearance.colors.colOnPrimary
                text: "sync"
            }
        }

        RippleButton {
            width: 65
            height: 65
            buttonRadius: Appearance.rounding.normal
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            anchors.leftMargin: 20

            onClicked: root.addMode = true;

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.title * 1.5
                color: Appearance.colors.colOnPrimary
                text: "add"
            }
        }
    }


    // Loading overlay when CalendarService.isLoading is true
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.52)
        radius: Appearance.rounding.large
        visible: CalendarService.isLoading
        z: 50
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        StyledBusyIndicator {
            anchors.centerIn: parent
            running: CalendarService.isLoading
            implicitSize: 120
            strokeWidth: 8
            internalStrokeWidth: 8
            z: 51
        }

        MouseArea { anchors.fill: parent }
    }

    CalendarAdd {
        id: calendarAddComponent
        anchors.fill: parent
        editMode: root.addMode
        z: 100
    }

    CalendarEdit {
        id: calendarEditComponent
        anchors.fill: parent
        editMode: root.editMode
        event: root.tempCalendarEvent
        z: 100
    }
}
