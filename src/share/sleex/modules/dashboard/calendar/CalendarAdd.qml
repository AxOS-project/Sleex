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
    property string startTime: DateTime.is24Hour ? 
        String(startHour).padStart(2, '0') + ":" + String(startMinute).padStart(2, '0') : 
        ((startHour % 12) || 12) + ":" + String(startMinute).padStart(2, '0') + (startHour >= 12 ? " PM" : " AM")
    property string endTime: DateTime.is24Hour ? 
        String(endHour).padStart(2, '0') + ":" + String(endMinute).padStart(2, '0') : 
        ((endHour % 12) || 12) + ":" + String(endMinute).padStart(2, '0') + (endHour >= 12 ? " PM" : " AM")

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

        TextField {
            id: eventTitleInput
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            implicitWidth: 200
            padding: 10
            color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
            renderType: Text.NativeRendering
            selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
            selectionColor: Appearance.colors.colSecondaryContainer
            placeholderText: qsTr("Title")
            placeholderTextColor: Appearance.m3colors.m3outline
            validator: RegularExpressionValidator {
                // Allow any non-empty string
                regularExpression: /^(?!\s*$).+/
            }

            background: Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.verysmall
                border.width: 2
                border.color: eventTitleInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                color: "transparent"
            }

            cursorDelegate: Rectangle {
                width: 1
                color: eventTitleInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                radius: 1
            }
        }

        TextField {
            id: eventDateInput
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            implicitWidth: 200
            padding: 10
            color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
            renderType: Text.NativeRendering
            selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
            selectionColor: Appearance.colors.colSecondaryContainer
            placeholderText: qsTr("Date (YYYY-MM-DD)")
            placeholderTextColor: Appearance.m3colors.m3outline
            validator: RegularExpressionValidator {
                // Simple regex for YYYY-MM-DD format
                regularExpression: /^\d{4}-\d{2}-\d{2}$/
            }

            background: Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.verysmall
                border.width: 2
                border.color: eventDateInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                color: "transparent"
            }

            cursorDelegate: Rectangle {
                width: 1
                color: eventDateInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                radius: 1
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
                        const dateStr = eventDateInput.text.trim();
                        // Use the selected start/end times from this dialog (not missing inputs)
                        const startStr = startTime;
                        const endStr = endTime;
                        
                        if (!title) {
                            console.error("Event title is required");
                            return;
                        }
                        
                        let eventDate;
                        try {
                            // Check if date is in YYYY-MM-DD format
                            const dateParts = dateStr.split('-');
                            if (dateParts.length === 3) {
                                eventDate = new Date(
                                    parseInt(dateParts[0]), 
                                    parseInt(dateParts[1]) - 1, 
                                    parseInt(dateParts[2])
                                );
                            } else {
                                eventDate = new Date();
                                console.log("Invalid date format, using today's date.");
                            }
                        } catch (e) {
                            eventDate = new Date();
                            console.log("Using today's date:", eventDate);
                        }
                        
                        const formattedDate = Qt.formatDate(eventDate, "yyyy-MM-dd");

                        root.newEventData = {
                            content: title,
                            date: formattedDate,
                            start: startStr || "", 
                            end: endStr || "",
                            allDay: allDaySwitch.checked
                        };
                        
                        console.log("Adding event:", JSON.stringify(root.newEventData));
                        CalendarService.addItem(root.newEventData);

                        eventTitleInput.text = "";
                        eventDateInput.text = "";
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