import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.UPower
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.bar
import qs.modules.mediaControls

MouseArea {
    id: root
    required property LockContext context
    property bool active: false
    property bool showInputField: active || context.currentText.length > 0
    property bool unlocking: false
    property bool lastUnlockInProgress: false

    function forceFieldFocus() {
        passwordBox.forceActiveFocus();
    }

    Component.onCompleted: {
        forceFieldFocus();
        context.animate.connect(() => unlockAnimationSequence.start())

    }

    // Monitor unlock progress to detect when unlock starts/ends
    onLastUnlockInProgressChanged: {
        if (lastUnlockInProgress && !context.unlockInProgress) {
            // Unlock just finished - start animation
            unlocking = true;
            unlockAnimationSequence.start();
        }
    }

    // Watch for unlock progress changes
    Connections {
        target: context
        function onUnlockInProgressChanged() {
            console.log("unlockInProgress changed to:", context.unlockInProgress);
            root.lastUnlockInProgress = context.unlockInProgress;
        }
    }

    // Unlock animation sequence
    SequentialAnimation {
        id: unlockAnimationSequence
        
        ParallelAnimation {
            // Fade out background
            NumberAnimation {
                target: backgroundImage
                property: "opacity"
                from: 1
                to: 0
                duration: 300
                easing.type: Easing.InCubic
            }
            
            // Slide clock/weather up and out
            NumberAnimation {
                target: clockWeather
                property: "anchors.topMargin"
                from: 40
                to: -200
                duration: 400
                easing.type: Easing.InCubic
            }
            
            // Slide media controls down and out
            NumberAnimation {
                target: mediaControlsContainer
                property: "anchors.bottomMargin"
                from: 20
                to: -200
                duration: 400
                easing.type: Easing.InCubic
            }
            
            // Slide password box down and out
            NumberAnimation {
                target: passwordBoxContainer
                property: "anchors.bottomMargin"
                from: 20
                to: -100
                duration: 400
                easing.type: Easing.InCubic
            }
            
            // Fade out battery indicator
            NumberAnimation {
                target: batteryIndicator
                property: "opacity"
                from: 1
                to: 0
                duration: 300
                easing.type: Easing.InCubic
            }
            
            // Fade out system controls
            NumberAnimation {
                target: systemControls
                property: "opacity"
                from: systemControls.opacity
                to: 0
                duration: 200
                easing.type: Easing.InCubic
            }
        }
        
        // Call the actual unlock after animations complete
        ScriptAction {
            script: {
                root.context.unlocked();
                root.unlocking = false; // Reset unlocking state
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.context.currentText = ""
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            // Handle Enter key even when password box is hidden
            if (!unlocking) {
                root.context.tryUnlock();
            }
            event.accepted = true;
        }
        forceFieldFocus();
    }

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: (mouse) => {
        forceFieldFocus();
    }
    onPositionChanged: (mouse) => {
        forceFieldFocus();
    }

    anchors.fill: parent

    // // Test button - remove this after testing
    // Rectangle {
    //     anchors.top: parent.top
    //     anchors.left: parent.left
    //     anchors.margins: 20
    //     width: 120
    //     height: 40
    //     color: "red"
    //     radius: 5
    //     z: 1000
        
    //     MouseArea {
    //         anchors.fill: parent
    //         onClicked: {
    //             root.context.unlocked();
    //         }
    //     }
        
    //     Text {
    //         anchors.centerIn: parent
    //         text: "Help, I'm stuck!"
    //         color: "white"
    //         font.pixelSize: 12
    //     }
    // }

    // Background
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: Config.options.background.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        z: -1
        opacity: 0

        Component.onCompleted: {
            if (!unlocking) {
                fadeInAnim.start()
            }
        }

        NumberAnimation {
            id: fadeInAnim
            target: backgroundImage
            property: "opacity"
            from: 0
            to: 1
            duration: 600
            easing.type: Easing.OutCubic
        }

        FastBlur {
            anchors.fill: parent
            source: backgroundImage
            radius: 10
            opacity: parent.opacity
        }
    }

    ColumnLayout {
        id: clockWeather
        visible: true
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: -200
        spacing: 8

        Component.onCompleted: {
            if (!unlocking) {
                animIn.running = true
            }
        }

        NumberAnimation {
            id: animIn
            target: clockWeather
            property: "anchors.topMargin"
            from: -200
            to: 40
            duration: 600
            easing.type: Easing.OutCubic
        }
        
        // Clock
        StyledText {
            id: timeText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            font.family: Config.options.background.clockFontFamily ?? "Sans Serif"
            font.pixelSize: 95
            color: Appearance.colors.colPrimary
            style: Text.Raised
            styleColor: Appearance.colors.colShadow
            text: DateTime.time
        }
        StyledText {
            id: dateText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            font.family: Config.options.background.clockFontFamily ?? "Sans Serif"
            font.pixelSize: 25
            color: Appearance.colors.colPrimary
            style: Text.Raised
            styleColor: Appearance.colors.colShadow
            text: DateTime.date
        }

        // Weather info
        RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            visible: weatherData

            Text {
                text: Weather.weatherCode ? materialSymbolForCode(Weather.weatherCode) : "cloud"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 28
                color: Appearance.colors.colPrimary
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                text: Weather.temperature || qsTr("--")
                font.pixelSize: 18
                color: Appearance.colors.colPrimary
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Battery indicator
    BatteryIndicator {
        id: batteryIndicator
        Layout.alignment: Qt.AlignTop | Qt.AlignRight
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        implicitWidth: 75
        implicitHeight: 23
        borderless: true
        visible: UPower.displayDevice.isLaptopBattery
        opacity: 1
    }

    // Hover trigger area (bottom right corner)
    Rectangle {
        id: hoverTrigger
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 80
        height: 200
        color: "transparent"
        
        MouseArea {
            id: triggerArea
            anchors.fill: parent
            hoverEnabled: true
            
            // System control buttons (bottom right)
            ColumnLayout {
                id: systemControls
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 32
                spacing: 12
                
                opacity: triggerArea.containsMouse ? 1 : 0
                visible: opacity > 0
                
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                
                // Shutdown
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    color: shutdownArea.containsMouse ? "#53ffb3ab" : "transparent"
                    border.color: Appearance.m3colors.m3error
                    border.width: 1
                    
                    MouseArea {
                        id: shutdownArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Qt.createQmlObject('import Quickshell.Io; Process { command: ["shutdown", "-h", "now"]; running: true }', lock);
                        }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 24
                        color: Appearance.m3colors.m3error
                    }
                }
                
                // Reboot
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    color: rebootArea.containsMouse ? "#3ed1e8d5" : "transparent"
                    border.color: "#ffD1E8D5"
                    border.width: 1
                    
                    MouseArea {
                        id: rebootArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Qt.createQmlObject('import Quickshell.Io; Process { command: ["reboot"]; running: true }', lock);
                        }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 24
                        color: "#ffD1E8D5"
                    }
                }
                
                // Logout
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    color: logoutArea.containsMouse ? "#4e6d98d5" : "transparent"
                    border.color: "#6d99cd"
                    border.width: 1
                    
                    MouseArea {
                        id: logoutArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Qt.createQmlObject('import Quickshell.Io; Process { command: ["loginctl", "terminate-user", "' + Quickshell.env("USER") + '"]; running: true }', lock);
                        }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "exit_to_app"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 24
                        color: "#6d99cd"
                    }
                }
            }
        }
    }
    
    // Media controls
    MediaControls {
        id: mediaControlsContainer
        implicitHeight: 150
        implicitWidth: 450
        visible: MprisController.activePlayer
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: passwordBoxContainer.top
            bottomMargin: -200
        }

        Component.onCompleted: {
            if (!unlocking) {
                mediaAnimIn.running = true
            }
        }

        NumberAnimation {
            id: mediaAnimIn
            target: mediaControlsContainer
            property: "anchors.bottomMargin"
            from: -200
            to: 20
            duration: 600
            easing.type: Easing.OutCubic
        }
    }

    // Tooltips text
    StyledText {
        id: tooltipText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: mediaControlsContainer.top
        anchors.bottomMargin: 20
        visible: !root.showInputField
        text: qsTr("Enter password to unlock")
        color: Appearance.colors.colSubtext
        font.pixelSize: 14
        opacity: root.showInputField ? 0 : 1
        
        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    // Password entry
    Rectangle {
        id: passwordBoxContainer
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: root.showInputField ? 20 : -height
        }
        Behavior on anchors.bottomMargin {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        radius: Appearance.rounding.full
        color: Appearance.m3colors.m3surfaceContainer
        implicitWidth: 200
        implicitHeight: 50

        StyledTextInput {
            id: passwordBox

            anchors {
                fill: parent
                margins: 10
            }
            clip: true
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            focus: true
            onFocusChanged: root.forceFieldFocus();
            color: Appearance.colors.colOnLayer2
            font {
                pixelSize: 15
            }

            // Password
            enabled: !root.context.unlockInProgress && !unlocking
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData

            // Synchronizing (across monitors) and unlocking
            onTextChanged: root.context.currentText = this.text
            onAccepted: {
                if (!unlocking) {
                    root.context.tryUnlock();
                }
            }
            Connections {
                target: root.context
                function onCurrentTextChanged() {
                    passwordBox.text = root.context.currentText;
                }
            }
        }
    }
}