import qs
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import qs.services
import QtQuick

Item {
    id: root

    required property bool editMode

    signal addingFinished()

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
    readonly property int selectedDateCount: selectedDates ? selectedDates.length : 0

    property string startTime: DateTime.is24Hour ?
        String(startHour).padStart(2, '0') + ":" + String(startMinute).padStart(2, '0') :
        ((startHour % 12) || 12) + ":" + String(startMinute).padStart(2, '0') + (startHour >= 12 ? " PM" : " AM")
    property string endTime: DateTime.is24Hour ?
        String(endHour).padStart(2, '0') + ":" + String(endMinute).padStart(2, '0') :
        ((endHour % 12) || 12) + ":" + String(endMinute).padStart(2, '0') + (endHour >= 12 ? " PM" : " AM")

    readonly property string selectedDateLabel: {
        if (root.selectedDateCount === 0) return qsTr("Select a date");
        if (root.selectedDateCount === 1) return Qt.formatDate(root.selectedDates[0], "MMM d");
        const sorted = root.selectedDates;
        const first = Qt.formatDate(sorted[0], "MMM d");
        const last = Qt.formatDate(sorted[sorted.length - 1], "MMM d");
        return root.selectedDateCount + qsTr(" dates · ") + first + " – " + last;
    }

    readonly property bool canSubmit: eventTitleInput.text.trim().length > 0 && root.selectedDateCount > 0

    function resetForm() {
        eventTitleInput.text = "";
        datePicker.setSelection([new Date()]);
        // reset times to defaults
        startHour = 12;
        startMinute = 0;
        endHour = 13;
        endMinute = 0;
        allDaySwitch.checked = false;
        customColorSwitch.checked = false;
    }

    Component.onCompleted: datePicker.setSelection([new Date()])

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
            root.resetForm();
            root.editMode = false;
            root.addingFinished();
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
                            text: "event"
                            iconSize: Appearance.font.pixelSize.title
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: qsTr("New Event")
                            font.pixelSize: Appearance.font.pixelSize.title
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    RippleButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
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
                            root.resetForm();
                            root.editMode = false;
                            root.addingFinished();
                        }
                    }
                }

                MaterialTextField {
                    id: eventTitleInput
                    width: parent.width
                    padding: 12
                    font.pixelSize: Appearance.font.pixelSize.larger
                    placeholderText: qsTr("Event title")
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
                        const anchorDate = datePicker.selectedDates.length > 0
                            ? datePicker.selectedDates[datePicker.selectedDates.length - 1]
                            : new Date();
                        datePicker.displayYear = anchorDate.getFullYear();
                        datePicker.displayMonth = anchorDate.getMonth();
                        datePickerDialog.visible = true;
                    }
                }

                StyledText {
                    visible: root.selectedDateCount > 1
                    width: parent.width
                    text: qsTr("This event will be added to all %1 selected dates.").arg(root.selectedDateCount)
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                    wrapMode: Text.WordWrap
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
                            text: root.selectedDateCount > 1
                                ? qsTr("Add to %1 dates").arg(root.selectedDateCount)
                                : qsTr("Add event")
                            color: Appearance.colors.colOnPrimary
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.Medium
                        }
                        onClicked: {
                            if (!root.canSubmit) return;
                            try {
                                const title = eventTitleInput.text.trim();
                                for (const d of root.selectedDates) {
                                    const formattedDate = Qt.formatDate(d, "yyyy-MM-dd");
                                    const eventData = {
                                        content: title,
                                        date: formattedDate,
                                        start: startTime,
                                        end: endTime,
                                        allDay: allDaySwitch.checked
                                    };
                                    if (customColorSwitch.checked) {
                                        eventData.color = root.selectedColorHex;
                                    }
                                    CalendarService.addItem(eventData);
                                }
                                root.resetForm();
                                root.editMode = false;
                            } catch (e) {
                                console.error("Error adding event:", e);
                            }
                            root.addingFinished();
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
                            root.resetForm();
                            root.editMode = false;
                            root.addingFinished();
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
            id: dateDialogContent
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
                multiSelect: true
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
