import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import qs.services
import qs.modules.common

ContentPage {
    id: root
    forceSingleColumn: true

    property var howdyModels: []
    property bool howdyLoading: false
    property bool howdyBusy: false
    property string howdyStatus: ""
    property string howdyListOutput: ""
    property string howdyActionOutput: ""
    property string newHowdyLabel: ""

    function refreshHowdyModels() {
        if (howdyLoading || howdyBusy) return

        howdyLoading = true
        howdyStatus = qsTr("Loading face models...")
        howdyListOutput = ""
        howdyListProcess.command = [
            "pkexec", "/usr/bin/howdy", "--plain", "-U", SystemInfo.username, "list"
        ]
        howdyListProcess.running = true
    }

    function addHowdyModel() {
        const label = newHowdyLabel.trim().slice(0, 24)
        if (label.length === 0) {
            howdyStatus = qsTr("Enter a label for the new model.")
            return
        }

        howdyBusy = true
        howdyStatus = qsTr("Creating face model... Please look at the camera !")
        howdyActionOutput = ""
        howdyActionProcess.command = [
            "pkexec", "/usr/bin/howdy", "--plain", "-U", SystemInfo.username, "add", "-y", label
        ]
        howdyActionProcess.running = true
    }

    function removeHowdyModel(modelId, modelLabel) {
        howdyBusy = true
        howdyStatus = qsTr("Removing face model %1 (%2)...").arg(modelId).arg(modelLabel)
        howdyActionOutput = ""
        howdyActionProcess.command = [
            "pkexec", "/usr/bin/howdy", "--plain", "-U", SystemInfo.username, "remove", "-y", String(modelId)
        ]
        howdyActionProcess.running = true
    }

    function parseHowdyList(output) {
        const lines = output.trim().split("\n").filter(line => line.trim().length > 0)
        const models = []

        for (const line of lines) {
            const parts = line.split(",")
            if (parts.length < 3) continue

            models.push({
                id: parts[0].trim(),
                created: parts[1].trim(),
                label: parts.slice(2).join(",").trim(),
            })
        }

        howdyModels = models
        howdyStatus = models.length > 0
            ? qsTr("Found %1 face model(s). ").arg(models.length)
            : qsTr("No face models found.")
    }

    Component.onCompleted: refreshHowdyModels()

    Process {
        id: howdyListProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.howdyListOutput = text
                root.parseHowdyList(text)
            }
        }
        onExited: (exitCode) => {
            root.howdyLoading = false
            if (exitCode !== 0 && root.howdyModels.length === 0) {
                root.howdyStatus = root.howdyListOutput.trim().length > 0
                    ? root.howdyListOutput.trim()
                    : qsTr("Howdy models could not be loaded.")
            }
        }
    }

    Process {
        id: howdyActionProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.howdyActionOutput = text
                if (text.trim().length > 0) {
                    root.howdyStatus = text.trim()
                }
            }
        }
        onExited: (exitCode) => {
            root.howdyBusy = false
            if (exitCode === 0) {
                root.newHowdyLabel = ""
                root.howdyStatus = qsTr("Face models updated.")
                root.refreshHowdyModels()
                return
            }

            if (root.howdyActionOutput.trim().length > 0) {
                root.howdyStatus = root.howdyActionOutput.trim()
            } else if (root.howdyStatus.length === 0) {
                root.howdyStatus = qsTr("Howdy command failed.")
            }
        }
    }
    
    ContentSection {
        title: "Lock"
        icon: "lock"

        Rectangle {
            Layout.fillWidth: true
            height: warnChildren.height + 40
            color: Appearance.colors.colPrimaryContainer
            radius: 6

            RowLayout {
                id: warnChildren
                anchors.fill: parent
                anchors.margins: 10

                Label {
                    text: "⚠️"
                    font.pixelSize: 16 // Slightly smaller icon
                    Layout.alignment: Qt.AlignVCenter
                    rightPadding: 6
                }

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "<b>IMPORTANT:</b> Face authentication will never be as secure as a traditional password.\nThis is a convenience feature."
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }
        }

        ConfigSwitch {
            id: enableFaceAuthSwitch
            text: "Enable Face Authentication"
            checked: Config.options.lockscreen.enableFaceAuth
            onClicked: checked = !checked;
            onCheckedChanged: {
                Config.options.lockscreen.enableFaceAuth = checked
            }
            StyledToolTip { text: "Uses Howdy for face authentication.\nIR camera is recommended." }
        }   
    }

    ContentSection {
        title: "Face Models"
        icon: "face"

        visible: Config.options.lockscreen.enableFaceAuth

        StyledText {
            Layout.fillWidth: true
            text: root.howdyLoading
                ? qsTr("Loading model list from howdy --plain...")
                : (root.howdyStatus.length > 0 ? root.howdyStatus : qsTr("Manage face models without leaving the app."))
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialTextField {
                id: newModelLabelInput
                Layout.fillWidth: true
                placeholderText: qsTr("New model label")
                text: root.newHowdyLabel
                enabled: !root.howdyBusy && !root.howdyLoading
                onTextChanged: root.newHowdyLabel = text
                onAccepted: root.addHowdyModel()
            }

            RippleButtonWithIcon {
                enabled: !root.howdyBusy && !root.howdyLoading
                materialIcon: "add"
                materialIconFill: false
                mainText: qsTr("Add")
                onClicked: root.addHowdyModel()
            }

            RippleButtonWithIcon {
                enabled: !root.howdyBusy && !root.howdyLoading
                materialIcon: "refresh"
                materialIconFill: false
                mainText: qsTr("Refresh")
                onClicked: root.refreshHowdyModels()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.howdyModels

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Model %1").arg(modelData.id)
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.created + "  ·  " + modelData.label
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                            }
                        }

                        RippleButtonWithIcon {
                            enabled: !root.howdyBusy && !root.howdyLoading
                            materialIcon: "delete"
                            materialIconFill: false
                            mainText: qsTr("Remove")
                            onClicked: root.removeHowdyModel(modelData.id, modelData.label)
                        }
                    }
                }
            }

            StyledText {
                visible: root.howdyModels.length === 0 && !root.howdyLoading
                text: qsTr("No face models are configured yet.")
                color: Appearance.colors.colSubtext
            }
        }
    }

    ContentSection {
        title: "Face Authentication Engine (Howdy)"
        icon: "face"

        visible: Config.options.lockscreen.enableFaceAuth

        RowLayout {
            anchors.margins: 10
            spacing: 10

            Layout.fillWidth: true
            Layout.preferredHeight: 64

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Edit Howdy configuration file (advanced)")
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSecondaryContainer
            }

            RippleButtonWithIcon {
                materialIcon: "edit"
                materialIconFill: false
                mainText: qsTr("Edit")
                onClicked: Quickshell.execDetached(["/usr/bin/xdg-open", "/etc/howdy/config.ini"])
                StyledToolTip { text: qsTr("May require administrator privileges.\n") }
            }
        }
    }
}
