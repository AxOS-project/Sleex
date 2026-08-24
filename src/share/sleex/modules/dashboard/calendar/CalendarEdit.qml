import qs
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import qs.services
import QtQuick

Item {
    id: root

    required property bool editMode
    property var event: {
        uid: ""
        title: ""
        start: ""
        end: ""
        date: ""
        allDay: false
    }

    signal editingFinished()

    // store start/end times independently (do not bind to the shared timePicker)
    property int startHour: 12
    property int startMinute: 0
    property int endHour: 13
    property int endMinute: 0
    // which field is being edited by the time picker: "start" or "end"
    property string editingTarget: "start"

    property var colorOptions: [
        "#F44336", "#E91E63", "#9C27B0", "#673AB7",
        "#3F51B5", "#2196F3", "#03A9F4", "#009688",
        "#4CAF50", "#8BC34A", "#CDDC39", "#FFEB3B",
        "#FF9800", "#FF5722", "#795548", "#607D8B",
        "#7E57C2", "#26A69A"
    ]
    property string selectedColorHex: root.colorOptions[0]

    readonly property var selectedDates: datePicker.selectedDates
    readonly property var selectedDate: selectedDates && selectedDates.length > 0 ? selectedDates[0] : new Date()
    readonly property string selectedDateLabel: Qt.formatDate(root.selectedDate, "MMM d")
    readonly property bool canSubmit: eventTitleInput.text.trim().length > 0 && selectedDates && selectedDates.length > 0

    // Initialize date and times from event data when dialog opens
    onEventChanged: {
        // reset times to defaults
        startHour = 12;
        startMinute = 0;
        endHour = 13;
        endMinute = 0;

        let initialDate = new Date();
        if (event && event.date) {
            const parsedDate = parseDate(event.date);
            if (parsedDate) initialDate = parsedDate;
        } else if (event && event.startDate) {
            initialDate = new Date(event.startDate);
        }

        if (event && event.start) {
            const startParts = parseTime(event.start);
            if (startParts) {
                startHour = startParts.hour;
                startMinute = startParts.minute;
            }
        }
        if (event && event.end) {
            const endParts = parseTime(event.end);
            if (endParts) {
                endHour = endParts.hour;
                endMinute = endParts.minute;
            }
        }

        Qt.callLater(function() {
            if (datePicker) {
                datePicker.setSelection([initialDate]);
                datePicker.displayYear = initialDate.getFullYear();
                datePicker.displayMonth = initialDate.getMonth();
            }
            if (eventTitleInput) {
                eventTitleInput.text = event?.title || "";
            }
            if (allDaySwitch) {
                allDaySwitch.checked = root.eventIsAllDay(event);
            }
            if (customColorSwitch) {
                customColorSwitch.checked = !!(event && event.customColor);
            }
            root.selectedColorHex = (event && event.color) ? event.color : root.colorOptions[0];
        });
    }

    function eventIsAllDay(evt) {
        if (!evt)
            return false;
        if (evt.allDay !== undefined)
            return !!evt.allDay;
        let s = evt.start || "";
        let e = evt.end || "";
        return (s === "00:00" && e === "23:59") ||
               (s === "00:00" && e === "00:00") ||
               (!evt.start && !evt.end);
    }

    function parseDate(dateStr) {
        if (!dateStr) return null;
        if (dateStr instanceof Date) return new Date(dateStr.getTime());

        let match = String(dateStr).match(/^(\d{4})-(\d{2})-(\d{2})$/);
        if (match) return new Date(parseInt(match[1]), parseInt(match[2]) - 1, parseInt(match[3]));

        match = String(dateStr).match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
        if (match) return new Date(parseInt(match[3]), parseInt(match[2]) - 1, parseInt(match[1]));

        const parsed = new Date(dateStr);
        return isNaN(parsed.getTime()) ? null : parsed;
    }

    // Helper function to parse time strings (supports both 24h and 12h formats)
    function parseTime(timeStr) {
        if (!timeStr) return null;

        // Try 24-hour format first (HH:MM)
        let match = timeStr.match(/^(\d{1,2}):(\d{2})$/);
        if (match) return { hour: parseInt(match[1]), minute: parseInt(match[2]) };

        // Try 12-hour format (H:MM AM/PM)
        match = timeStr.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
        if (match) {
            let hour = parseInt(match[1]);
            const minute = parseInt(match[2]);
            const isPM = match[3].toUpperCase() === 'PM';
            if (hour === 12) hour = 0;
            if (isPM) hour += 12;
            return { hour, minute };
        }
        return null;
    }

    property string startTime: DateTime.is24Hour ?
        String(startHour).padStart(2, '0') + ":" + String(startMinute).padStart(2, '0') :
        ((startHour % 12) || 12) + ":" + String(startMinute).padStart(2, '0') + (startHour >= 12 ? " PM" : " AM")
    property string endTime: DateTime.is24Hour ?
        String(endHour).padStart(2, '0') + ":" + String(endMinute).padStart(2, '0') :
        ((endHour % 12) || 12) + ":" + String(endMinute).padStart(2, '0') + (endHour >= 12 ? " PM" : " AM")

    anchors.fill: parent
    visible: root.editMode
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    function opaque(c) {
        return Qt.rgba(c.r, c.g, c.b, 1.0)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: {
            root.editMode = false;
            root.editingFinished();
        }
    }

    Item {
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 48)
        height: Math.min(Math.max(cardColumn.implicitHeight + 48, 560), parent.height - 32)

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: root.opaque(Appearance.colors.colLayer0)
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            MouseArea { anchors.fill: parent; onClicked: {} }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 24
            contentWidth: width
            contentHeight: cardColumn.implicitHeight
            clip: true
            interactive: contentHeight > height

            Column {
                id: cardColumn
                width: parent.width
                spacing: 18

                Row {
                    width: parent.width
                    height: 32

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        MaterialSymbol {
                            text: "edit_calendar"
                            iconSize: Appearance.font.pixelSize.title
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: qsTr("Edit Event")
                            font.pixelSize: Appearance.font.pixelSize.title
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        RippleButton {
                            width: 32; height: 32
                            buttonRadius: 16
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.m3colors.m3error
                            }
                            onClicked: {
                                try {
                                    CalendarService.removeItem(root.event);
                                } catch (e) {
                                    console.error("Error deleting event:", e);
                                }
                                root.editMode = false;
                                root.editingFinished();
                            }
                        }

                        RippleButton {
                            width: 32; height: 32
                            buttonRadius: 16
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                            onClicked: {
                                root.editMode = false;
                                root.editingFinished();
                            }
                        }
                    }
                }

                MaterialTextField {
                    id: eventTitleInput
                    width: parent.width
                    padding: 12
                    font.pixelSize: Appearance.font.pixelSize.larger
                    placeholderText: qsTr("Event title")
                    text: ""
                    validator: RegularExpressionValidator {
                        // Allow any non-empty string
                        regularExpression: /^(?!\s*$).+/
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                }

                FieldRow {
                    width: parent.width
                    icon: "calendar_month"
                    label: qsTr("Date")
                    valueText: root.selectedDateLabel
                    onClicked: {
                        datePicker.displayYear = root.selectedDate.getFullYear();
                        datePicker.displayMonth = root.selectedDate.getMonth();
                        datePickerDialog.visible = true;
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    FieldRow {
                        id: startField
                        width: (parent.width - 10) / 2
                        icon: "schedule"
                        label: qsTr("Starts")
                        enabled: !allDaySwitch.checked
                        opacity: allDaySwitch.checked ? 0.35 : 1
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        valueText: allDaySwitch.checked ? "—" : root.startTime
                        onClicked: {
                            if (allDaySwitch.checked) return
                            // open time picker to edit start time
                            editingTarget = "start"
                            timePicker.hour = startHour
                            timePicker.minute = startMinute
                            timePickerDialog.visible = true
                        }
                    }

                    FieldRow {
                        id: endField
                        width: (parent.width - 10) / 2
                        icon: "update"
                        label: qsTr("Ends")
                        enabled: !allDaySwitch.checked
                        opacity: allDaySwitch.checked ? 0.35 : 1
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        valueText: allDaySwitch.checked ? "—" : root.endTime
                        onClicked: {
                            if (allDaySwitch.checked) return
                            // open time picker to edit end time
                            editingTarget = "end"
                            timePicker.hour = endHour
                            timePicker.minute = endMinute
                            timePickerDialog.visible = true
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 36

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        MaterialSymbol {
                            text: "wb_sunny"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("All day")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    ConfigSwitch {
                        id: allDaySwitch
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: false
                        onClicked: checked = !checked
                        onCheckedChanged: {
                            if (checked)
                                timePickerDialog.visible = false
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 36

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        MaterialSymbol {
                            text: "palette"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Custom color")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    ConfigSwitch {
                        id: customColorSwitch
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: false
                        onClicked: checked = !checked
                    }
                }

                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 9
                    spacing: 8
                    visible: customColorSwitch.checked

                    Repeater {
                        model: root.colorOptions
                        delegate: Rectangle {
                            required property string modelData
                            width: 26
                            height: 26
                            radius: 13
                            color: modelData
                            scale: modelData === root.selectedColorHex ? 1.15 : 1
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: modelData === root.selectedColorHex ? 2 : 0
                                border.color: "#FFFFFF"
                                Behavior on border.width { NumberAnimation { duration: 100 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedColorHex = modelData
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    RippleButton {
                        width: (parent.width - parent.spacing) / 2
                        height: 46
                        buttonRadius: Appearance.rounding.normal
                        enabled: root.canSubmit
                        opacity: enabled ? 1 : 0.5
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Save changes")
                            color: Appearance.colors.colOnPrimary
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.Medium
                        }
                        onClicked: {
                            if (!root.canSubmit) return;
                            try {
                                const title = eventTitleInput.text.trim();
                                const formattedDate = Qt.formatDate(root.selectedDate, "yyyy-MM-dd");
                                const eventData = {
                                    content: title,
                                    date: formattedDate,
                                    start: startTime,
                                    end: endTime,
                                    allDay: allDaySwitch.checked
                                };
                                if (customColorSwitch.checked) {
                                    eventData.color = root.selectedColorHex;
                                } else if (root.event && root.event.customColor) {
                                    eventData.color = "NONE";
                                }
                                CalendarService.editItem(root.event.uid, eventData);
                                root.editMode = false;
                            } catch (e) {
                                console.error("Error editing event:", e);
                            }
                            root.editingFinished();
                        }
                    }

                    RippleButton {
                        width: (parent.width - parent.spacing) / 2
                        height: 46
                        buttonRadius: Appearance.rounding.normal
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: Appearance.colors.colOnSurfaceVariant
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                        }
                        onClicked: {
                            root.editMode = false;
                            root.editingFinished();
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: datePickerDialog
        anchors.fill: parent
        color: "transparent"
        visible: false
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Rectangle {
            width: Math.min(420, parent.width - 48)
            height: Math.min(560, parent.height - 32)
            anchors.centerIn: parent
            radius: Appearance.rounding.large
            color: root.opaque(Appearance.colors.colLayer0)
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            CalendarDatePicker {
                id: datePicker
                anchors.fill: parent
                anchors.margins: 16
                anchors.bottomMargin: 64
                multiSelect: false
            }

            RippleButton {
                buttonRadius: Appearance.rounding.normal
                height: 40
                width: 120
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Done")
                    color: Appearance.colors.colOnPrimary
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                }
                onClicked: datePickerDialog.visible = false
            }
        }
    }

    // Time selector dialog
    Rectangle {
        id: timePickerDialog
        anchors.fill: parent
        color: "transparent"
        visible: false
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Rectangle {
            width: Math.min(420, parent.width - 48)
            height: Math.min(560, parent.height - 32)
            anchors.centerIn: parent
            radius: Appearance.rounding.large
            color: root.opaque(Appearance.colors.colLayer0)
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            TimePicker {
                id: timePicker
                anchors.centerIn: parent
                is24h: DateTime.is24Hour
                hour: 12
                minute: 0

                enabled: !allDaySwitch.checked
                opacity: allDaySwitch.checked ? 0.4 : 1
            }

            RippleButton {
                buttonRadius: Appearance.rounding.normal
                height: 40
                width: 120
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Done")
                    color: Appearance.colors.colOnPrimary
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                }
                onClicked: {
                    // apply picked time to the appropriate target
                    if (editingTarget === "start") {
                        startHour = timePicker.hour
                        startMinute = timePicker.minute
                    } else {
                        endHour = timePicker.hour
                        endMinute = timePicker.minute
                    }
                    timePickerDialog.visible = false;
                }
            }
        }
    }

    component FieldRow: Rectangle {
        id: fieldRoot
        property string icon: ""
        property string label: ""
        property string valueText: ""
        signal clicked()

        height: 56
        radius: Appearance.rounding.normal
        color: rowMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: fieldRoot.icon
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnSurfaceVariant
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                StyledText {
                    text: fieldRoot.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: fieldRoot.valueText
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        MaterialSymbol {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "chevron_right"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnSurfaceVariant
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fieldRoot.clicked()
        }
    }
}
