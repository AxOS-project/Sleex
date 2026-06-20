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
            visible: MprisController.activePlayer && Config.options.lockscreen.showLyricsOnLockScreen
            isLockscreen: true

            property bool hasCustomPos: (Config.options.lockscreen.lockscreenMediaX ?? -1) >= 0

            width: (Config.options.lockscreen.lockscreenMediaWidth ?? 0) > 0 ? Config.options.lockscreen.lockscreenMediaWidth : bottomBar.width
            height: (Config.options.lockscreen.lockscreenMediaHeight ?? 0) > 0 ? Config.options.lockscreen.lockscreenMediaHeight : 200

            anchors.bottom: hasCustomPos ? undefined : bottomBar.top
            anchors.bottomMargin: hasCustomPos ? 0 : 15
            anchors.horizontalCenter: hasCustomPos ? undefined : bottomBar.horizontalCenter

            x: hasCustomPos ? Config.options.lockscreen.lockscreenMediaX : 0
            y: hasCustomPos ? Config.options.lockscreen.lockscreenMediaY : 0

            opacity: root.unlocking ? 0 : (root.visualsReady ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: 600 } }

            function safeDisconnectAnchors() {
                if (mediaWidget.anchors.bottom !== undefined || mediaWidget.anchors.horizontalCenter !== undefined) {
                    let currentX = mediaWidget.x
                    let currentY = mediaWidget.y
                    mediaWidget.anchors.bottom = undefined
                    mediaWidget.anchors.horizontalCenter = undefined
                    mediaWidget.x = currentX
                    mediaWidget.y = currentY
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                z: -1
                enabled: Config.options.lockscreen.resizableLockScreenWidget
                property real dragStartX
                property real dragStartY

                onPressed: (mouse) => {
                    mediaWidget.safeDisconnectAnchors()
                    let mapped = mapToItem(root, mouse.x, mouse.y)
                    dragStartX = mapped.x - mediaWidget.x
                    dragStartY = mapped.y - mediaWidget.y
                    mouse.accepted = true
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                        let mapped = mapToItem(root, mouse.x, mouse.y)
                        mediaWidget.x = mapped.x - dragStartX
                        mediaWidget.y = mapped.y - dragStartY
                }
                onReleased: {
                    Config.options.lockscreen.lockscreenMediaX = mediaWidget.x
                    Config.options.lockscreen.lockscreenMediaY = mediaWidget.y
                }
            }

            Loader {
                id: resizeLoader
                active: Config.options.lockscreen.resizableLockScreenWidget
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

                    component EdgeResizeHandle: Rectangle {
                        property string direction: "vertical"
                        property bool invert: false
                        color: "transparent"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: direction === "vertical" ? Qt.SizeVerCursor : Qt.SizeHorCursor
                            property real startPos
                            property real startSize
                            property real startWidgetPos

                            onPressed: (mouse) => {
                                mediaWidget.safeDisconnectAnchors()
                                let mapped = mapToItem(root, mouse.x, mouse.y)
                                startPos = direction === "vertical" ? mapped.y : mapped.x
                                startSize = direction === "vertical" ? mediaWidget.height : mediaWidget.width
                                startWidgetPos = direction === "vertical" ? mediaWidget.y : mediaWidget.x
                                mouse.accepted = true
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed) return
                                    let mapped = mapToItem(root, mouse.x, mouse.y)
                                    let currentPos = direction === "vertical" ? mapped.y : mapped.x
                                    let delta = currentPos - startPos

                                    if (direction === "vertical") {
                                        if (invert) {
                                            let newHeight = Math.max(120, startSize - delta)
                                            mediaWidget.height = newHeight
                                            mediaWidget.y = startWidgetPos + (startSize - newHeight)
                                        } else {
                                            mediaWidget.height = Math.max(120, startSize + delta)
                                        }
                                    } else {
                                        if (invert) {
                                            let newWidth = Math.max(200, startSize - delta)
                                            mediaWidget.width = newWidth
                                            mediaWidget.x = startWidgetPos + (startSize - newWidth)
                                        } else {
                                            mediaWidget.width = Math.max(200, startSize + delta)
                                        }
                                    }
                            }
                            onReleased: {
                                Config.options.lockscreen.lockscreenMediaWidth = mediaWidget.width
                                Config.options.lockscreen.lockscreenMediaHeight = mediaWidget.height
                                Config.options.lockscreen.lockscreenMediaX = mediaWidget.x
                                Config.options.lockscreen.lockscreenMediaY = mediaWidget.y
                            }
                        }
                    }

                    EdgeResizeHandle {
                        width: parent.width - 2 * parent.cornerSize
                        height: parent.edgeSize
                        x: parent.cornerSize; y: 0
                        direction: "vertical"; invert: true
                    }
                    EdgeResizeHandle {
                        width: parent.width - 2 * parent.cornerSize
                        height: parent.edgeSize
                        x: parent.cornerSize; y: parent.height - parent.edgeSize
                        direction: "vertical"; invert: false
                    }
                    EdgeResizeHandle {
                        width: parent.edgeSize
                        height: parent.height - 2 * parent.cornerSize
                        x: 0; y: parent.cornerSize
                        direction: "horizontal"; invert: true
                    }
                    EdgeResizeHandle {
                        width: parent.edgeSize
                        height: parent.height - 2 * parent.cornerSize
                        x: parent.width - parent.edgeSize; y: parent.cornerSize
                        direction: "horizontal"; invert: false
                    }

                    component CornerResizeHandle: Rectangle {
                        property int xSign: 1
                        property int ySign: 1
                        width: parent.cornerSize; height: parent.cornerSize
                        color: "transparent"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: (xSign === ySign) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                            property real startX
                            property real startY
                            property real startWidth
                            property real startHeight
                            property real startWidgetX
                            property real startWidgetY

                            onPressed: (mouse) => {
                                mediaWidget.safeDisconnectAnchors()
                                let mapped = mapToItem(root, mouse.x, mouse.y)
                                startX = mapped.x
                                startY = mapped.y
                                startWidth = mediaWidget.width
                                startHeight = mediaWidget.height
                                startWidgetX = mediaWidget.x
                                startWidgetY = mediaWidget.y
                                mouse.accepted = true
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed) return
                                    let mapped = mapToItem(root, mouse.x, mouse.y)
                                    let dx = mapped.x - startX
                                    let dy = mapped.y - startY

                                    if (xSign === -1) {
                                        let newWidth = Math.max(200, startWidth - dx)
                                        mediaWidget.width = newWidth
                                        mediaWidget.x = startWidgetX + (startWidth - newWidth)
                                    } else {
                                        mediaWidget.width = Math.max(200, startWidth + dx)
                                    }

                                    if (ySign === -1) {
                                        let newHeight = Math.max(120, startHeight - dy)
                                        mediaWidget.height = newHeight
                                        mediaWidget.y = startWidgetY + (startHeight - newHeight)
                                    } else {
                                        mediaWidget.height = Math.max(120, startHeight + dy)
                                    }
                            }
                            onReleased: {
                                Config.options.lockscreen.lockscreenMediaWidth = mediaWidget.width
                                Config.options.lockscreen.lockscreenMediaHeight = mediaWidget.height
                                Config.options.lockscreen.lockscreenMediaX = mediaWidget.x
                                Config.options.lockscreen.lockscreenMediaY = mediaWidget.y
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
