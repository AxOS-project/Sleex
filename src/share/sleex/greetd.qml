import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.bar

ShellRoot {
    id: root

    property var detectedUsers: []
    property var detectedDEs: []
    property var detectedDECommands: []
    property string lastSession: ""
    property bool showUserInput: false
    property int selectedDE: 0

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()        
    }

    Process {
        id: getUsersProcess
        running: true
        command: ["bash", "-c", "getent passwd | grep -E ':[0-9]{4}:' | cut -d: -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var userList = text.trim().split('\n').filter(u => u.length > 0)
                root.detectedUsers = userList

                const dummyUsers = ["alice", "bob", "charlie"]
                // Append dummy to test UI with more users
                for (var i = 0; i < dummyUsers.length; i++) {
                    if (!root.detectedUsers.includes(dummyUsers[i])) {
                        root.detectedUsers.push(dummyUsers[i])
                    }
                }
            }
        }
    }

    Process {
        id: getDEsProcess
        running: true
        command: ["bash", "-c", "find /usr/share/wayland-sessions/ -name '*.desktop' 2>/dev/null | while read f; do name=$(grep '^Name=' \"$f\" | cut -d= -f2); exec=$(grep '^Exec=' \"$f\" | cut -d= -f2); echo \"$name|||$exec\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split('\n').filter(l => l.length > 0)
                var names = []
                var commands = []

                if (lines.length === 0) {
                    names = ["Default Session"]
                    commands = ["bash"]
                } else {
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].split('|||')
                        if (parts.length === 2) {
                            names.push(parts[0])
                            commands.push(parts[1])
                        }
                    }
                }

                root.detectedDEs = names
                root.detectedDECommands = commands
            }
        }
    }

    PanelWindow {
        id: bgWindow
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        Image {
            id: backgroundImage
            anchors.fill: parent
            source: Config.options.background.wallpaperPath
            fillMode: Image.PreserveAspectCrop

            GaussianBlur {
                anchors.fill: parent
                source: backgroundImage
                radius: 10
                opacity: parent.opacity
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 20
            width: statusRow.width + 20
            height: statusRow.height + 10
            radius: 20
            color:  Appearance.m3colors.m3error
            visible: !Greetd.available
            RowLayout {
                id: statusRow
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    text: 'error'
                    color: Appearance.m3colors.m3onError
                }

                StyledText {
                    color: Appearance.m3colors.m3onError
                    text: "Greetd is not running!"
                    font.pixelSize: 10
                }
            }
        }

        StyledText {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 100
            color: Appearance.colors.colPrimary
            text: DateTime.time
            font.pixelSize: 96
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: timeText.bottom
            color: Appearance.colors.colOnSurfaceVariant
            text: DateTime.date
            font.bold: true
            font.pixelSize: 32
        }
    }

    PanelWindow {
        id: loginWindow
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        RippleButtonWithIcon {
            mainText: "exit"
            materialIcon: "exit_to_app"
            onClicked: Qt.quit()
            visible: !Greetd.available
        }
        
        Item {
            width: things.width
            height: things.height
            anchors {
                right: parent.right
                top: parent.top
                margins: 20
            }
            RowLayout {
                id: things
                spacing: 10

                BluetoothIndicator {}
                BatteryIndicator {}
            }
        }

        Item {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 40
            width: 440
            height: loginBox.height

            Rectangle {
                id: loginBox
                anchors.centerIn: parent
                width: parent.width
                height: content.height + 60
                radius: 20
                color: Appearance.colors.colSurfaceContainerLow

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowOpacity: 0.3
                    shadowColor: Appearance.colors.colShadow
                    shadowBlur: 1
                    shadowScale: 1
                }

                ColumnLayout {
                    id: content
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    anchors.margins: 30
                    spacing: 20
                    ColumnLayout {
                        // anchors {
                        //     left: parent.left
                        //     right: parent.right
                        //     top: parent.top
                        // }
                        Layout.fillWidth: true
                        spacing: 20
                    }
                    ColumnLayout {
                        // anchors {
                        //     left: parent.left
                        //     right: parent.right
                        //     top: parent.top
                        // }
                        Layout.fillWidth: true
                        spacing: 20

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: !root.showUserInput

                            StyledText {
                                text: "User"
                                font.pixelSize: 14
                                font.family: "Outfit Medium"
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledComboBox {
                                id: userComboBox
                                Layout.fillWidth: true
                                model: root.detectedUsers

                                onModelChanged: {
                                    if (root.detectedUsers.length > 0) {
                                        currentIndex = 0
                                        usernameInput.text = root.detectedUsers[0]
                                    }
                                }

                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0 && currentIndex < root.detectedUsers.length) {
                                        usernameInput.text = root.detectedUsers[currentIndex]
                                    }
                                    root.showUserInput = false
                                    passwordInput.forceActiveFocus()
                                }
                            }

                            RippleButtonWithIcon {
                                Layout.fillWidth: true
                                mainText: "Other user"
                                materialIcon: "person_add"
                                onClicked: {
                                    root.showUserInput = true
                                    usernameInput.forceActiveFocus()
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.showUserInput

                            StyledText {
                                text: "Username"
                                font.pixelSize: 14
                                font.family: "Outfit Medium"
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                RippleButton {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    onClicked: root.showUserInput = false

                                    MaterialSymbol {
                                        text: "arrow_back"
                                        iconSize: 24
                                        color: Appearance.colors.colOnSurfaceVariant
                                        anchors.centerIn: parent
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    MaterialTextField {
                                        id: usernameInput
                                        Layout.fillWidth: true
                                        placeholderText: "Enter username"
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: usernameInput.text.length > 0

                            StyledText {
                                text: "Password"
                                font.pixelSize: 14
                                font.family: "Outfit Medium"
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            MaterialTextField {
                                id: passwordInput
                                Layout.fillWidth: true
                                placeholderText: "Enter password"
                                echoMode: TextField.Password

                                Keys.onReturnPressed: submitLogin()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: usernameInput.text.length > 0

                            StyledText {
                                text: "Session"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledComboBox {
                                id: deComboBox
                                Layout.fillWidth: true
                                model: root.detectedDEs
                                currentIndex: root.selectedDE

                                onCurrentIndexChanged: {
                                    root.selectedDE = deComboBox.currentIndex
                                }
                            }
                        }

                        StyledText {
                            id: statusText
                            Layout.fillWidth: true
                            font.pixelSize: 13
                            color: statusText.text.includes("Failed") || statusText.text.includes("Error")
                                ? Appearance.m3colors.m3error
                                : Appearance.colors.colPrimary
                            wrapMode: Text.WordWrap
                            visible: text !== ""
                            horizontalAlignment: Text.AlignHCenter
                        }

                        RippleButton {
                            id: loginButton
                            Layout.fillWidth: true
                            visible: usernameInput.text.length > 0

                            onClicked: submitLogin()
                            enabled: statusText.text === "" || statusText.text.includes("Failed")

                            colBackground: Appearance.colors.colPrimary
                            colBackgroundHover: Appearance.colors.colPrimaryContainer

                            Row {
                                anchors.centerIn: parent
                                anchors.margins: 12

                                StyledText {
                                    visible: statusText.text === ""
                                    text: "Login"
                                    color: Appearance.colors.colOnPrimary
                                    font.pixelSize: 16
                                    font.family: "Outfit Medium"
                                }

                                MaterialSymbol {
                                    text: "login"
                                    iconSize: 24
                                    color: Appearance.colors.colOnPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 16
                                    visible: statusText.text === ""
                                }

                                StyledBusyIndicator {
                                    visible: statusText.text !== ""
                                    running: statusText.text !== ""
                                    implicitSize: 29
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 20
            spacing: 12

            RippleButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                colBackground: Appearance.colors.colSurfaceContainerLow
                colBackgroundHover: Appearance.colors.colSurfaceContainerLow
                buttonRadius: Appearance.rounding.full
                onClicked: {
                    Quickshell.execDetached({ command: ["systemctl", "poweroff" ]})
                }

                MaterialSymbol {
                    text: "power_settings_new"
                    iconSize: 24
                    color: Appearance.colors.colOnSurface
                    anchors.centerIn: parent
                }
            }

            RippleButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                colBackground: Appearance.colors.colSurfaceContainerLow
                colBackgroundHover: Appearance.colors.colSurfaceContainerLow
                buttonRadius: Appearance.rounding.full
                onClicked: {
                    Quickshell.execDetached({ command: ["systemctl", "reboot" ]})
                }

                MaterialSymbol {
                    text: "restart_alt"
                    iconSize: 24
                    color: Appearance.colors.colOnSurface
                    anchors.centerIn: parent
                }
            }
        }
    }

    function submitLogin() {
        if (usernameInput.text.length > 0 && passwordInput.text.length > 0) {
            loginButton.enabled = false
            statusText.text = "Authenticating..."
            Greetd.createSession(usernameInput.text)
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            statusText.text = message

            if (responseRequired) {
                passwordInput.forceActiveFocus()
                if (passwordInput.text.length > 0) {
                    Greetd.respond(passwordInput.text)
                }
            }
        }

        function onAuthFailure(message) {
            statusText.text = "Failed: " + message
            passwordInput.text = ""
            loginButton.enabled = true
        }

        function onReadyToLaunch() {
            statusText.text = "Launching..."

            var command = ["bash"]
            if (root.selectedDE < root.detectedDECommands.length)
                command = [root.detectedDECommands[root.selectedDE]]

            console.log("greetd.qml", "Launching command: " + command)
            Greetd.launch(command)
        }

        function onError(error) {
            statusText.text = "Error: " + error
            loginButton.enabled = true
        }
    }
}