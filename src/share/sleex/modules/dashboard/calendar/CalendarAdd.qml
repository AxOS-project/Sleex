import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
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
    property var selectedDate: new Date()

    property string startTime: DateTime.is24Hour ? 
        String(startHour).padStart(2, '0') + ":" + String(startMinute).padStart(2, '0') : 
        ((startHour % 12) || 12) + ":" + String(startMinute).padStart(2, '0') + (startHour >= 12 ? " PM" : " AM")
    property string endTime: DateTime.is24Hour ? 
        String(endHour).padStart(2, '0') + ":" + String(endMinute).padStart(2, '0') : 
        ((endHour % 12) || 12) + ":" + String(endMinute).padStart(2, '0') + (endHour >= 12 ? " PM" : " AM")

    property string selectedDateLabel: Qt.formatDate(selectedDate, "ddd, MMM d yyyy")

    property var newEventData: {
        content: ""
        start: undefined
        end: undefined
        date: undefined
        allDay: false
    }

    anchors.fill: parent
    gradient: Gradient {
        GradientStop { position: 0.0; color: Appearance.m3colors.m3surface }
        GradientStop { position: 0.3; color: Appearance.m3colors.m3surface }
        GradientStop { position: 1.0; color: Appearance.colors.colLayer0 }
        orientation: Gradient.Horizontal
    }
    radius: Appearance.rounding.large
    z: 100
    visible: root.editMode
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
    }

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: parent.width * 0.8

        StyledText {
            text: qsTr("Add a new event.")
            font.pixelSize: Appearance.font.pixelSize.title
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        MaterialTextField {
            id: eventTitleInput
            Layout.fillWidth: true
            implicitWidth: 330
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            padding: 10
            placeholderText: qsTr("Title")
            validator: RegularExpressionValidator {
                // Allow any non-empty string
                regularExpression: /^(?!\s*$).+/
            }
        }

        Rectangle {
            id: datePickerButton
            width: 336
            height: 56
            color: "transparent"
            radius: Appearance.rounding.normal

            property color borderColor: Appearance.m3colors.m3outline
            border.color: borderColor
            border.width: dateHoverArea.containsMouse ? 2 : 1.5

            Behavior on border.width { NumberAnimation { duration: 100 } }
            Behavior on borderColor  { ColorAnimation  { duration: 120 } }

            states: State {
                name: "hovered"
                when: dateHoverArea.containsMouse
                PropertyChanges {
                    target: datePickerButton
                    borderColor: Appearance.m3colors.m3primary
                }
            }

            Rectangle {
                x: 12
                y: -(height / 2)
                width: floatingLabel.implicitWidth + 8
                height: floatingLabel.implicitHeight
                color: Appearance.m3colors.m3background
            }

            StyledText {
                id: floatingLabel
                x: 16
                y: -(implicitHeight / 2)
                text: qsTr("Date")
                font.pixelSize: Appearance.font.pixelSize.small
                color: dateHoverArea.containsMouse
                    ? Appearance.m3colors.m3primary
                    : Appearance.m3colors.m3outline

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 16
                text: root.selectedDateLabel
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: Appearance.m3colors.m3onSurface
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 14
                text: "›"
                font.pixelSize: Appearance.font.pixelSize.title
                rotation: 90
                color: dateHoverArea.containsMouse
                    ? Appearance.m3colors.m3primary
                    : Appearance.m3colors.m3outline

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Appearance.m3colors.m3onSurface
                opacity: dateHoverArea.containsMouse ? 0.05 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                id: dateHoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    datePicker.displayYear  = root.selectedDate.getFullYear()
                    datePicker.displayMonth = root.selectedDate.getMonth()
                    datePickerDialog.visible = true
                }
            }
        }

        ConfigSwitch {
            id: allDaySwitch
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            text: qsTr("All Day Event")
            checked: false
            onCheckedChanged: root.newEventData.allDay = checked
        }

        Row {
            spacing: 16

            RippleButton {
                buttonRadius: Appearance.rounding.normal
                height: 40
                width: 160
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: qsTr(startTime)
                    color: Appearance.colors.colOnPrimary
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                onClicked: {
                    // open time picker to edit start time
                    editingTarget = "start"
                    timePicker.hour = startHour
                    timePicker.minute = startMinute
                    timePickerDialog.visible = true
                }
            }

            RippleButton {
                buttonRadius: Appearance.rounding.normal
                height: 40
                width: 160
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: qsTr(endTime)
                    color: Appearance.colors.colOnPrimary
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                onClicked: {
                    // open time picker to edit end time
                    editingTarget = "end"
                    timePicker.hour = endHour
                    timePicker.minute = endMinute
                    timePickerDialog.visible = true
                }
            }
        }

        Row {
            spacing: 16

            RippleButton {
                buttonRadius: Appearance.rounding.normal
                height: 40
                width: 160
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Validate")
                    color: Appearance.colors.colOnPrimary
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                onClicked: {
                    try {
                        const title = eventTitleInput.text.trim();

                        if (!title) {
                            console.error("Event title is required");
                            return;
                        }

                        const formattedDate = Qt.formatDate(root.selectedDate, "yyyy-MM-dd");

                        root.newEventData = {
                            content: title,
                            date: formattedDate,
                            start: startTime,
                            end: endTime,
                            allDay: allDaySwitch.checked
                        };

                        console.log("Adding event:", JSON.stringify(root.newEventData));
                        CalendarService.addItem(root.newEventData);

                        eventTitleInput.text = "";
                        root.selectedDate = new Date();
                        // reset times to defaults
                        startHour = 12;
                        startMinute = 0;
                        endHour = 13;
                        endMinute = 0;
                        allDaySwitch.checked = false;
                        root.editMode = false;
                    } catch (e) {
                        console.error("Error adding event:", e);
                    }
                    root.addingFinished();
                }
            }

            RippleButton {
                buttonRadius: Appearance.rounding.normal
                height: 40
                width: 160
                colBackground: Appearance.m3colors.m3surfaceVariant
                colBackgroundHover: Appearance.m3colors.m3surfaceVariant
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Cancel")
                    color: Appearance.m3colors.m3onSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                onClicked: {
                    root.newEventData = {
                        title: "",
                        start: "",
                        end: "",
                        date: "",
                        allDay: false
                    };
                    root.editMode = false;
                    root.addingFinished();
                }
            }
        }
    }

    Rectangle {
        id: datePickerDialog
        anchors.fill: parent
        color: Appearance.colors.colSurfaceContainer
        visible: false
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Rectangle {
            id: dateDialogContent
            width: 480
            height: 540
            anchors.centerIn: parent
            radius: Appearance.rounding.large
            color: Appearance.m3colors.m3background

            Item {
                id: datePicker
                anchors.fill: parent
                anchors.margins: 16

                property int displayYear:  new Date().getFullYear()
                property int displayMonth: new Date().getMonth()

                property string monthLabel: {
                    const d = new Date(displayYear, displayMonth, 1);
                    return Qt.formatDate(d, "MMMM yyyy");
                }

                property int daysInMonth: new Date(displayYear, displayMonth + 1, 0).getDate()
                property int firstDayOfWeek: new Date(displayYear, displayMonth, 1).getDay()

                Column {
                    anchors.fill: parent
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 40

                        RippleButton {
                            height: 40; width: 40
                            buttonRadius: 20
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.m3colors.m3surfaceVariant
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                text: "‹"
                                font.pixelSize: Appearance.font.pixelSize.title
                                color: Appearance.m3colors.m3onBackground
                                horizontalAlignment: Text.AlignHCenter
                            }
                            onClicked: {
                                if (datePicker.displayMonth === 0) {
                                    datePicker.displayMonth = 11;
                                    datePicker.displayYear -= 1;
                                } else {
                                    datePicker.displayMonth -= 1;
                                }
                            }
                        }

                        StyledText {
                            text: datePicker.monthLabel
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.Medium
                            color: Appearance.m3colors.m3onBackground
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            width: parent.width - 80
                            height: 40
                        }

                        RippleButton {
                            height: 40; width: 40
                            buttonRadius: 20
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.m3colors.m3surfaceVariant
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                text: "›"
                                font.pixelSize: Appearance.font.pixelSize.title
                                color: Appearance.m3colors.m3onBackground
                                horizontalAlignment: Text.AlignHCenter
                            }
                            onClicked: {
                                if (datePicker.displayMonth === 11) {
                                    datePicker.displayMonth = 0;
                                    datePicker.displayYear += 1;
                                } else {
                                    datePicker.displayMonth += 1;
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 28
                        Repeater {
                            model: ["Su","Mo","Tu","We","Th","Fr","Sa"]
                            StyledText {
                                width: datePicker.width / 7
                                text: modelData
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.m3colors.m3outline
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 7
                        rowSpacing: 2
                        columnSpacing: 0

                        Repeater {
                            model: 42
                            delegate: Item {
                                width: datePicker.width / 7
                                height: datePicker.width / 7

                                property int dayNumber: index - datePicker.firstDayOfWeek + 1
                                property bool isValid: dayNumber >= 1 && dayNumber <= datePicker.daysInMonth
                                property bool isSelected: {
                                    if (!isValid) return false;
                                    const s = root.selectedDate;
                                    return s.getFullYear() === datePicker.displayYear &&
                                           s.getMonth()    === datePicker.displayMonth &&
                                           s.getDate()     === dayNumber;
                                }
                                property bool isToday: {
                                    if (!isValid) return false;
                                    const t = new Date();
                                    return t.getFullYear() === datePicker.displayYear &&
                                           t.getMonth()    === datePicker.displayMonth &&
                                           t.getDate()     === dayNumber;
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - 4
                                    height: parent.height - 4
                                    radius: (parent.width - 4) / 2
                                    color: isSelected ? Appearance.colors.colPrimary
                                         : isToday    ? Appearance.m3colors.m3secondaryContainer
                                         :              "transparent"
                                    visible: isValid
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: isValid ? dayNumber : ""
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: isSelected ? Appearance.colors.colOnPrimary
                                         : isToday    ? Appearance.m3colors.m3onSecondaryContainer
                                         :              Appearance.m3colors.m3onBackground
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: isValid
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedDate = new Date(
                                            datePicker.displayYear,
                                            datePicker.displayMonth,
                                            dayNumber
                                        );
                                    }
                                }
                            }
                        }
                    }
                }
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
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                onClicked: datePickerDialog.visible = false
            }
        }
    }

    // Time selector dialog
    Rectangle {
        id: timePickerDialog
        anchors.fill: parent
        color: Appearance.colors.colSurfaceContainer
        visible: false
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Rectangle {
            id: dialogContent
            width: 400
            height: 500
            anchors.centerIn: parent
            radius: Appearance.rounding.large
            color: Appearance.m3colors.m3background

            TimePicker {
                id: timePicker
                anchors.centerIn: parent
                is24h: DateTime.is24Hour
                hour: 12
                minute: 0
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
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
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
}
