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
    property var event: {
        uid: ""
        title: ""
        start: ""
        end: ""
        date: ""
    }

    signal editingFinished()

    property var newEventData: {
        title: ""
        start: ""
        end: ""
        date: ""
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
            text: qsTr("Edit an event.")
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
            text: root.event?.title || ""
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
            text: root.event?.date || ""
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
            text: root.event?.start || ""
            placeholderTextColor: Appearance.m3colors.m3outline
            validator: RegularExpressionValidator {
                // Simple regex for HH:MM format (24-hour)
                regularExpression: /^([01]\d|2[0-3]):([0-5]\d)$/
            }

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
            text: root.event?.end || ""
            placeholderTextColor: Appearance.m3colors.m3outline
            validator: RegularExpressionValidator {
                // Simple regex for HH:MM format (24-hour)
                regularExpression: /^([01]\d|2[0-3]):([0-5]\d)$/
            }

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
                        };

                        console.log("Editing event:", JSON.stringify(root.newEventData));
                        CalendarService.editItem(root.event.uid, root.newEventData);

                        eventTitleInput.text = "";
                        eventDateInput.text = "";
                        eventTimeStartInput.text = "";
                        eventTimeEndInput.text = "";
                        root.editMode = false;
                    } catch (e) {
                        console.error("Error adding event:", e);
                    }
                    root.editingFinished();
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
                    };
                    root.editMode = false;
                    root.editingFinished(); 
                }
            }
        }
    }
}