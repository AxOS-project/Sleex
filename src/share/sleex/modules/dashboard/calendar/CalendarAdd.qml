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

    property var newEventData: {
        content: ""
        start: undefined
        end: undefined
        date: undefined
        allDay: false
    }

    anchors.fill: parent
    color: Appearance.m3colors.m3surface
    radius: Appearance.rounding.large
    z: 100
    visible: root.editMode
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    MouseArea { anchors.fill: parent }

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

        TextField {
            id: eventTimeStartInput
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            implicitWidth: 200
            padding: 10
            color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
            renderType: Text.NativeRendering
            selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
            selectionColor: Appearance.colors.colSecondaryContainer
            placeholderText: qsTr("Start Time (HH:MM)")
            placeholderTextColor: Appearance.m3colors.m3outline

            background: Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.verysmall
                border.width: 2
                border.color: eventTimeStartInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                color: "transparent"
            }

            cursorDelegate: Rectangle {
                width: 1
                color: eventTimeStartInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                radius: 1
            }
        }

        TextField {
            id: eventTimeEndInput
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            implicitWidth: 200
            padding: 10
            color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
            renderType: Text.NativeRendering
            selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
            selectionColor: Appearance.colors.colSecondaryContainer
            placeholderText: qsTr("End Time (HH:MM)")
            placeholderTextColor: Appearance.m3colors.m3outline

            background: Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.verysmall
                border.width: 2
                border.color: eventTimeEndInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                color: "transparent"
            }

            cursorDelegate: Rectangle {
                width: 1
                color: eventTimeEndInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                radius: 1
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
                        const startStr = eventTimeStartInput.text.trim();
                        const endStr = eventTimeEndInput.text.trim();
                        
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
                        eventTimeStartInput.text = "";
                        eventTimeEndInput.text = "";
                        allDaySwitch.checked = false;
                        root.editMode = false;
                    } catch (e) {
                        console.error("Error adding event:", e);
                    }
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
                }
            }
        }
    }
}