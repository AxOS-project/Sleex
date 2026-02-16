import QtQuick
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
    property var detectedKbdLayouts: []
    property string lastSession: ""
    property bool showUserInput: false
    property int selectedDE: 0
    property bool wrongPassword: false

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

    Process {
        id: getKbdLayoutsProcess
        running: true
        command: ["bash", "-c", "localectl list-x11-keymap-layouts 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split('\n').filter(l => l.length > 0)
                root.detectedKbdLayouts = lines
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

        RippleButton {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 20
            width: statusRow.width + 20
            height: statusRow.height + 10
            buttonRadius: 20
            colBackground: Appearance.m3colors.m3error
            visible: !Greetd.available
            z: 1000
            hoverEnabled: true
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
            onClicked: {
                Qt.quit()
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

        // Error message wrapper
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: bottomBar.top
            anchors.bottomMargin: 20
            width: statusText.implicitWidth + 40
            height: 40
            radius: Appearance.rounding.full
            color: Appearance.m3colors.m3errorContainer
            visible: statusText.text !== "" && statusText.text !== "Authenticating..." && statusText.text !== "Launching..."

            StyledText {
                id: statusText
                anchors.centerIn: parent
                font.pixelSize: 13
                color: Appearance.m3colors.m3onErrorContainer
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: bottomBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50
            height: 70

            // Center Pill: Password Input
            Rectangle {
                id: passwordContainer
                anchors.centerIn: parent
                width: 400
                height: 70
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                // Shake mechanics
                property int shakeOffset: 0
                transform: Translate { x: passwordContainer.shakeOffset }

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: -10; duration: 50 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: 10; duration: 50 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: -5; duration: 50 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: 5; duration: 50 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: 0; duration: 50 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RippleButton {
                        colBackground: Appearance.colors.colLayer1
                        Layout.fillHeight: true
                        implicitWidth: height
                        buttonRadius: Appearance.rounding.full

                        MaterialSymbol {
                            text: passwordInput.echoMode === TextInput.Password ? "visibility" : "visibility_off"
                            iconSize: 20
                            color: Appearance.colors.colOnLayer0
                            anchors.centerIn: parent
                        }

                        onClicked: {
                            passwordInput.echoMode = passwordInput.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password
                            passwordInput.forceActiveFocus()
                        }
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        color: Appearance.colors.colLayer2
                        radius: Appearance.rounding.full
                        clip: true
                        
                        border.color: root.wrongPassword ? Appearance.m3colors.m3error : "transparent"
                        border.width: 1

                        MaterialTextField {
                            id: usernameInput
                            visible: false
                            text: root.detectedUsers.length > 0 ? root.detectedUsers[0] : ""
                        }

                        StyledTextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.margins: 12
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            focus: true
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: 15
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData

                            onTextChanged: root.wrongPassword = false
                            onAccepted: submitLogin()

                            StyledText {
                                anchors.centerIn: parent
                                text: qsTr("Enter password")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: 15
                                visible: parent.text.length === 0
                            }
                        }

                        NumberAnimation on border.color {
                            duration: 300
                            easing.type: Easing.InOutQuad
                        }
                    }

                    RippleButton {
                        id: loginButton
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryContainer
                        Layout.fillHeight: true
                        implicitWidth: height
                        buttonRadius: Appearance.rounding.full
                        enabled: statusText.text === "" || statusText.text.includes("Failed")

                        MaterialSymbol {
                            text: "arrow_forward"
                            iconSize: 24
                            color: Appearance.colors.colOnPrimary
                            anchors.centerIn: parent
                        }

                        onClicked: submitLogin()
                    }
                }
            }

            // Left Pill: User & Session
            Rectangle {
                id: leftPill
                anchors.right: passwordContainer.left
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                height: 70
                width: leftLayout.implicitWidth + 24 
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                RowLayout {
                    id: leftLayout
                    anchors.centerIn: parent
                    spacing: 4

                    IconComboBox {
                        id: userComboBox
                        icon: "account_circle"
                        model: root.detectedUsers
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < root.detectedUsers.length) {
                                usernameInput.text = root.detectedUsers[currentIndex]
                            }
                        }
                    }

                    IconComboBox {
                        id: deComboBox
                        icon: "call_to_action" 
                        model: root.detectedDEs
                        currentIndex: root.detectedDEs.includes("Sleex") ? root.detectedDEs.indexOf("Sleex") : 0
                        onCurrentIndexChanged: {
                            root.selectedDE = deComboBox.currentIndex
                        }
                    }

                    // IconComboBox {
                    //     id: kbdComboBox
                    //     icon: "keyboard"
                    //     model: root.detectedKbdLayouts
                    // }
                }
            }

            // Right Pill: Power Controls
            Rectangle {
                id: sysControls
                anchors.left: passwordContainer.right
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                height: 70
                width: suspendButton.width + rebootButton.width + poweroffButton.width + 40
                color: Appearance.colors.colLayer0
                radius: Appearance.rounding.full

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    RippleButton {
                        id: suspendButton
                        colBackground: Appearance.colors.colLayer1
                        Layout.fillHeight: true
                        implicitWidth: height
                        buttonRadius: Appearance.rounding.full
                        MaterialSymbol {
                            text: "bedtime"
                            iconSize: 20
                            color: Appearance.colors.colOnLayer0
                            anchors.centerIn: parent
                        }
                        onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                    }
                    
                    RippleButton {
                        id: rebootButton
                        colBackground: Appearance.colors.colLayer1
                        Layout.fillHeight: true
                        implicitWidth: height
                        buttonRadius: Appearance.rounding.full
                        MaterialSymbol {
                            text: "restart_alt"
                            iconSize: 20
                            anchors.centerIn: parent
                            color: Appearance.colors.colOnLayer0
                        }
                        onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                    }

                    RippleButton {
                        id: poweroffButton
                        colBackground: Appearance.colors.colLayer1
                        colBackgroundHover: Appearance.colors.colErrorContainer
                        Layout.fillHeight: true
                        implicitWidth: height
                        buttonRadius: Appearance.rounding.full
                        MaterialSymbol {
                            text: "power_settings_new"
                            iconSize: 20
                            anchors.centerIn: parent
                            color: Appearance.colors.colOnLayer0
                        }
                        onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                    }
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
            root.wrongPassword = true
            shakeAnim.start()

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