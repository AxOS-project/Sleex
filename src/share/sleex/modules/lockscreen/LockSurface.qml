import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.bar
import qs.modules.mediaControls

FocusScope {
    id: root
    required property var context

    property bool unlocking: false
    property bool wrongPassword: context.showFailure
    property bool visualsReady: false

    anchors.fill: parent
    focus: true

    Component.onCompleted: {
        visualsReady = true
        passwordInput.forceActiveFocus()
    }

    Keys.onEscapePressed: context.currentText = ""
    Keys.onPressed: (event) => passwordInput.forceActiveFocus()

    Connections {
        target: context
        function onAnimate() { root.unlocking = true; unlockSequence.start() }
        function onUnlockInProgressChanged() {
            if (!context.unlockInProgress && root.unlocking)
                unlockSequence.start()
        }
    }

    WallpaperDisplay {
        id: wallpaper
        anchors.fill: parent
        source: Config.options.background.wallpaperPath
        opacity: root.visualsReady ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        GaussianBlur {
            anchors.fill: parent
            source: wallpaper
            radius: 15
            opacity: parent.opacity
        }
        MouseArea { anchors.fill: parent; onClicked: passwordInput.forceActiveFocus() }
    }

    Rectangle {
        id: scrim
        anchors.fill: wallpaper
        color: "black"
        opacity: (root.visualsReady && Config.options.lockscreen.enableScrim) ? 0.6 : 0
        Behavior on opacity { NumberAnimation { duration: 800 } }
    }

    Item {
        id: uiLayer
        anchors.fill: parent
        opacity: root.unlocking ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InCubic } }

        ColumnLayout {
            id: clockWidget
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root.unlocking ? -200 : (root.visualsReady ? 40 : -200)
            spacing: 8
            Behavior on anchors.topMargin { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.family: Config.options.background.clockFontFamily ?? "Sans Serif"
                font.pixelSize: 95
                color: Appearance.colors.colPrimary
                style: Text.Raised; styleColor: Appearance.colors.colShadow
                text: DateTime.time
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.family: Config.options.background.clockFontFamily ?? "Sans Serif"
                font.pixelSize: 25
                color: Appearance.colors.colPrimary
                style: Text.Raised; styleColor: Appearance.colors.colShadow
                text: DateTime.date
            }
            RowLayout {
                visible: Config.options.dashboard.enableWeather
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                Text { text: "cloud"; font.family: "Material Symbols Outlined"; font.pixelSize: 28; color: Appearance.colors.colPrimary }
                Text { text: Weather.temperature || qsTr("--"); font.pixelSize: 18; color: Appearance.colors.colPrimary }
            }
        }

        BatteryIndicator {
            anchors { top: parent.top; right: parent.right; margins: 10 }
            visible: UPower.displayDevice.isLaptopBattery
            opacity: root.unlocking ? 0 : (root.visualsReady ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: 600 } }
        }

        MediaControls {
            id: mediaWidget
            visible: MprisController.activePlayer && Config.options.dashboard.showLyricsOnLockScreen
            isLockscreen: true
            width: Config.options.dashboard.lockscreenMediaWidth
            height: Config.options.dashboard.lockscreenMediaHeight
            anchors { centerIn: parent; bottom: passwordContainer.top }
            opacity: root.unlocking ? 0 : (root.visualsReady ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: 600 } }

            Loader {
                id: resizeLoader
                active: Config.options.dashboard.resizableLockScreenWidget
                sourceComponent: resizeComponent
                anchors.fill: parent
            }

            Component {
                id: resizeComponent
                Item {
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: "transparent"
                        border.width: 2
                        border.color: Appearance.colors.colPrimary
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0; verticalOffset: 0
                            radius: 12; samples: 24
                            color: Appearance.colors.colPrimary; opacity: 0.6
                            transparentBorder: true
                        }
                    }

                    readonly property int edgeSize: 8
                    readonly property int cornerSize: 16

                    // Reusable edge handle
                    component EdgeResizeHandle: Rectangle {
                        property string direction: "vertical" // "vertical" or "horizontal"
                        property bool invert: false
                        color: "transparent"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: direction === "vertical" ? Qt.SizeVerCursor : Qt.SizeHorCursor
                            property real start
                            property real startSize
                            onPressed: (mouse) => {
                                start = direction === "vertical" ? mouse.y : mouse.x
                                startSize = direction === "vertical" ? mediaWidget.height : mediaWidget.width
                                mouse.accepted = true
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed) return
                                    let delta = (direction === "vertical" ? mouse.y : mouse.x) - start
                                    if (invert) delta = -delta
                                        let newSize = Math.max(direction === "vertical" ? 120 : 200, startSize + delta)
                                        if (direction === "vertical") {
                                            if (invert) {
                                                let dy = startSize - newSize
                                                mediaWidget.height = newSize
                                                mediaWidget.y += dy
                                            } else {
                                                mediaWidget.height = newSize
                                            }
                                            Config.options.dashboard.lockscreenMediaHeight = newSize
                                        } else {
                                            if (invert) {
                                                let dx = startSize - newSize
                                                mediaWidget.width = newSize
                                                mediaWidget.x += dx
                                            } else {
                                                mediaWidget.width = newSize
                                            }
                                            Config.options.dashboard.lockscreenMediaWidth = newSize
                                        }
                            }
                        }
                    }

                    // Top edge
                    EdgeResizeHandle {
                        width: parent.width - 2 * parent.cornerSize
                        height: parent.edgeSize
                        x: parent.cornerSize; y: 0
                        direction: "vertical"; invert: true
                    }
                    // Bottom edge
                    EdgeResizeHandle {
                        width: parent.width - 2 * parent.cornerSize
                        height: parent.edgeSize
                        x: parent.cornerSize; y: parent.height - parent.edgeSize
                        direction: "vertical"; invert: false
                    }
                    // Left edge
                    EdgeResizeHandle {
                        width: parent.edgeSize
                        height: parent.height - 2 * parent.cornerSize
                        x: 0; y: parent.cornerSize
                        direction: "horizontal"; invert: true
                    }
                    // Right edge
                    EdgeResizeHandle {
                        width: parent.edgeSize
                        height: parent.height - 2 * parent.cornerSize
                        x: parent.width - parent.edgeSize; y: parent.cornerSize
                        direction: "horizontal"; invert: false
                    }

                    // Reusable corner handle (diagonal)
                    component CornerResizeHandle: Rectangle {
                        property int xSign: 1   // -1 for left, 1 for right
                        property int ySign: 1   // -1 for top, 1 for bottom
                        width: parent.cornerSize; height: parent.cornerSize
                        color: "transparent"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: (xSign === ySign) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                            property real startX
                            property real startY
                            property real startWidth
                            property real startHeight
                            onPressed: (mouse) => {
                                startX = mouse.x; startY = mouse.y
                                startWidth = mediaWidget.width; startHeight = mediaWidget.height
                                mouse.accepted = true
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed) return
                                    let dx = (mouse.x - startX) * xSign
                                    let dy = (mouse.y - startY) * ySign
                                    let newWidth = Math.max(200, startWidth + dx)
                                    let newHeight = Math.max(120, startHeight + dy)
                                    let dw = startWidth - newWidth
                                    let dh = startHeight - newHeight
                                    mediaWidget.width = newWidth
                                    mediaWidget.height = newHeight
                                    if (xSign === -1) mediaWidget.x += dw
                                        if (ySign === -1) mediaWidget.y += dh
                                            Config.options.dashboard.lockscreenMediaWidth = newWidth
                                            Config.options.dashboard.lockscreenMediaHeight = newHeight
                            }
                        }
                    }

                    CornerResizeHandle { x: 0; y: 0; xSign: -1; ySign: -1 }
                    CornerResizeHandle { x: parent.width - parent.cornerSize; y: 0; xSign: 1; ySign: -1 }
                    CornerResizeHandle { x: 0; y: parent.height - parent.cornerSize; xSign: -1; ySign: 1 }
                    CornerResizeHandle { x: parent.width - parent.cornerSize; y: parent.height - parent.cornerSize; xSign: 1; ySign: 1 }
                }
            }
        }

        RowLayout {
            id: bottomBar
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.unlocking ? -150 : (root.visualsReady ? 50 : -150)
            spacing: 15
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Rectangle {
                id: passwordContainer
                Layout.preferredWidth: 400
                Layout.preferredHeight: 70
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                RowLayout {
                    id: passwordRow
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    property int shakeOffset: 0
                    anchors.horizontalCenterOffset: shakeOffset

                    SequentialAnimation {
                        id: shakeAnim
                        running: root.wrongPassword
                        loops: 1
                        NumberAnimation { target: passwordRow; property: "shakeOffset"; to: -10; duration: 50 }
                        NumberAnimation { target: passwordRow; property: "shakeOffset"; to: 10; duration: 50 }
                        NumberAnimation { target: passwordRow; property: "shakeOffset"; to: -5; duration: 50 }
                        NumberAnimation { target: passwordRow; property: "shakeOffset"; to: 5; duration: 50 }
                        NumberAnimation { target: passwordRow; property: "shakeOffset"; to: 0; duration: 50 }
                    }

                    RippleButton {
                        colBackground: Appearance.colors.colLayer1
                        Layout.fillHeight: true; implicitWidth: height
                        buttonRadius: Appearance.rounding.full
                        enabled: !context.unlockInProgress && !root.unlocking
                        MaterialSymbol {
                            text: passwordInput.echoMode === TextInput.Password ? "visibility" : "visibility_off"
                            iconSize: 20; color: Appearance.colors.colOnLayer0; anchors.centerIn: parent
                        }
                        onClicked: passwordInput.echoMode = passwordInput.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password
                    }

                    Rectangle {
                        Layout.fillHeight: true; Layout.fillWidth: true
                        color: Appearance.colors.colLayer2
                        radius: Appearance.rounding.full
                        clip: true
                        border.color: root.wrongPassword ? Appearance.colors.colError : "transparent"
                        border.width: 1
                        StyledTextInput {
                            id: passwordInput
                            anchors.fill: parent; anchors.margins: 12
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            focus: true
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: 15
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData
                            enabled: !context.unlockInProgress && !root.unlocking
                            text: context.currentText
                            onTextChanged: context.currentText = text
                            onAccepted: if (!root.unlocking) context.tryUnlock()
                            StyledText {
                                anchors.centerIn: parent
                                text: qsTr("Enter password")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: 15
                                visible: parent.text.length === 0
                            }
                        }
                    }

                    RippleButton {
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryContainer
                        Layout.fillHeight: true; implicitWidth: height
                        buttonRadius: Appearance.rounding.full
                        enabled: !context.unlockInProgress && !root.unlocking
                        MaterialSymbol {
                            text: "arrow_forward"; iconSize: 24
                            color: Appearance.colors.colOnPrimary; anchors.centerIn: parent
                        }
                        onClicked: context.tryUnlock()
                    }
                }
            }

            Rectangle {
                id: sysControls
                Layout.preferredHeight: 70
                Layout.preferredWidth: (height - 20) * 3 + 10 + 20
                color: Appearance.colors.colLayer0
                radius: Appearance.rounding.full
                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 5
                    RippleButton {
                        colBackground: Appearance.colors.colLayer1
                        Layout.fillHeight: true; Layout.fillWidth: true
                        buttonRadius: Appearance.rounding.full
                        MaterialSymbol { text: "bedtime"; iconSize: 20; anchors.centerIn: parent; color: Appearance.colors.colOnLayer0 }
                        onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                    }
                    RippleButton {
                        colBackground: Appearance.colors.colLayer1
                        colBackgroundHover: Appearance.colors.colErrorContainer
                        Layout.fillHeight: true; Layout.fillWidth: true
                        buttonRadius: Appearance.rounding.full
                        MaterialSymbol { text: "power_settings_new"; iconSize: 20; anchors.centerIn: parent; color: Appearance.colors.colOnLayer0 }
                        onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                    }
                    RippleButton {
                        colBackground: Appearance.colors.colLayer1
                        Layout.fillHeight: true; Layout.fillWidth: true
                        buttonRadius: Appearance.rounding.full
                        MaterialSymbol { text: "restart_alt"; iconSize: 20; anchors.centerIn: parent; color: Appearance.colors.colOnLayer0 }
                        onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: unlockSequence
        NumberAnimation { target: scrim; property: "opacity"; to: 0; duration: 200 }
        NumberAnimation { target: wallpaper; property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: uiLayer; property: "opacity"; to: 0; duration: 100; easing.type: Easing.InCubic }
        ScriptAction { script: { context.unlocked(); root.unlocking = false } }
    }
}
