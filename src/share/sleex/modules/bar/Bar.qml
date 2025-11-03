import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth

import Sleex.Services

Scope {
    id: bar

    readonly property int barHeight: Appearance.sizes.barHeight
    readonly property int osdHideMouseMoveThreshold: 20

    property bool barBackground: Config.options.bar.background

    component VerticalBarSeparator: Rectangle {
        Layout.topMargin: barHeight / 3
        Layout.bottomMargin: barHeight / 3
        Layout.fillHeight: true
        implicitWidth: 1
        color: Appearance.colors.colOutlineVariant
    }

    Variants { // For each monitor
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        PanelWindow { // Bar window
            id: barRoot
            screen: modelData

            property ShellScreen modelData
            property var brightnessMonitor: Brightness.getMonitorForScreen(modelData)
            property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen.width) ? 2 :
                (Appearance.sizes.barShortenScreenWidthThreshold >= screen.width) ? 1 : 0
            readonly property int centerSideModuleWidth:
                (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened :
                (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened :
                    Appearance.sizes.barCenterSideModuleWidth

            WlrLayershell.namespace: "quickshell:bar"
            WlrLayershell.layer: WlrLayer.Top
            implicitHeight: barHeight + Appearance.rounding.screenRounding
            exclusiveZone: barHeight
            mask: Region {
                item: barContent
            }
            color: "transparent"

            anchors {
                top: !Config.options.bar.bottom
                bottom: Config.options.bar.bottom
                left: true
                right: true
            }

            Rectangle { // Bar background
                id: barContent
                anchors {
                    right: parent.right
                    left: parent.left
                    top: !Config.options.bar.bottom ? parent.top : undefined
                    bottom: Config.options.bar.bottom ? parent.bottom : undefined
                }
                color: barBackground ? Appearance.colors.colLayer2 : "transparent"
                height: barHeight

                MouseArea { // Left side | scroll to change brightness
                    id: barLeftSideMouseArea
                    anchors.left: parent.left
                    implicitHeight: barHeight
                    width: (barRoot.width - middleSection.width) / 2
                    property bool hovered: false
                    property real lastScrollX: 0
                    property real lastScrollY: 0
                    property bool trackingScroll: false
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onEntered: (event) => {
                        barLeftSideMouseArea.hovered = true
                    }
                    onExited: (event) => {
                        barLeftSideMouseArea.hovered = false
                        barLeftSideMouseArea.trackingScroll = false
                    }
                    onPressed: (event) => {
                        if (event.button === Qt.LeftButton) {
                            GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
                        }
                    }

                    // Scroll to change brightness
                    WheelHandler {
                        onWheel: (event) => {
                            if (event.angleDelta.y < 0)
                                barRoot.brightnessMonitor.setBrightness(barRoot.brightnessMonitor.brightness - 0.05);
                            else if (event.angleDelta.y > 0)
                                barRoot.brightnessMonitor.setBrightness(barRoot.brightnessMonitor.brightness + 0.05);
                            // Store the mouse position and start tracking
                            barLeftSideMouseArea.lastScrollX = event.x;
                            barLeftSideMouseArea.lastScrollY = event.y;
                            barLeftSideMouseArea.trackingScroll = true;
                        }
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    }

                    Item {  // Left section
                        anchors.fill: parent
                        implicitHeight: leftSectionRowLayout.implicitHeight
                        implicitWidth: leftSectionRowLayout.implicitWidth


                        ScrollHint {
                            reveal: barLeftSideMouseArea.hovered
                            icon: "light_mode"
                            tooltipText: qsTr("Scroll to change brightness")
                            side: "left"
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                        }

                        RowLayout { // Content
                            id: leftSectionRowLayout
                            anchors.fill: parent
                            spacing: 10
                            visible: Config.options.bar.showTitle

                            ActiveWindow {
                                visible: barRoot.useShortenedForm === 0
                                Layout.leftMargin: Appearance.rounding.screenRounding
                                Layout.rightMargin: Appearance.rounding.screenRounding
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                bar: barRoot
                            }
                        }
                    }
                }

                // Background Rectangle - completely outside the RowLayout
                Rectangle {
                    id: middleBg
                    anchors.centerIn: parent
                    anchors.horizontalCenter: middleSection.horizontalCenter
                    anchors.verticalCenter: middleSection.verticalCenter
                    width: middleSection.width
                    height: middleSection.height
                    color: "transparent"
                    antialiasing: true
                    z: -1

                    property int bottomRadius: Appearance.rounding.screenRounding
                    property int topRadius: 0

                    Canvas {
                        anchors.fill: parent
                        z: 1
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.beginPath();
                            ctx.moveTo(0, 0);
                            ctx.lineTo(width, 0);
                            ctx.lineTo(width, height - middleBg.bottomRadius);
                            ctx.quadraticCurveTo(width, height, width - middleBg.bottomRadius, height);
                            ctx.lineTo(middleBg.bottomRadius, height);
                            ctx.quadraticCurveTo(0, height, 0, height - middleBg.bottomRadius);
                            ctx.lineTo(0, 0);
                            ctx.closePath();
                            ctx.fillStyle = Appearance.colors.colLayer0;
                            ctx.fill();
                        }
                    }
                    visible: true
                }

                RowLayout { // Middle section - NO Rectangle inside here
                    id: middleSection
                    anchors.centerIn: parent
                    spacing: 0

                    Revealer {
                        reveal: Config.options.bar.showRessources
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        BarGroupL {
                            id: leftCenterGroup
                            Layout.fillHeight: true

                            Resources {
                                alwaysShowAllResources: barRoot.useShortenedForm === 2
                                Layout.fillWidth: barRoot.useShortenedForm === 2
                            }
                        }
                    }

                    MaterialSymbol {
                        text: Config.options.bar.showRessources ? "chevron_right" : "chevron_left"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer0
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: Config.options.bar.showRessources ? 0 : Appearance.rounding.screenRounding

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            hoverEnabled: true
                            onClicked: (event) => {
                                if (event.button === Qt.LeftButton) {
                                    Config.options.bar.showRessources = !Config.options.bar.showRessources;
                                }
                            }
                        }
                    }

                    BarGroupCenter {
                        id: middleCenterGroup
                        padding: workspacesWidget.widgetPadding
                        Layout.fillHeight: true
                        visible: Config.options.bar.showWorkspaces

                        RoundCorner {
                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                            size: Appearance.rounding.screenRounding
                            corner: cornerEnum.topRight
                            color: Appearance.colors.colLayer1
                        }

                        Workspaces {
                            id: workspacesWidget
                            bar: barRoot
                            Layout.fillHeight: true

                            MouseArea { // Right-click to toggle overview
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton

                                onPressed: (event) => {
                                    if (event.button === Qt.RightButton) {
                                        GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                                    }
                                }
                            }

                            Canvas {
                                id: workspacesBgCanvas
                                anchors.fill: parent
                                z: -1

                                property color bgColor: Appearance.colors.colLayer1
                                
                                onBgColorChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    ctx.beginPath();
                                    ctx.moveTo(0, 0);
                                    ctx.lineTo(width, 0);
                                    ctx.lineTo(width, height - 20);
                                    ctx.quadraticCurveTo(width, height, width - 20, height); // bottom-right
                                    ctx.lineTo(20, height);
                                    ctx.quadraticCurveTo(0, height, 0, height - 20);         // bottom-left
                                    ctx.lineTo(0, 0);
                                    ctx.closePath();

                                    // Build an explicit rgba() color string from the QML color components so alpha is preserved
                                    var cr = Math.round(bgColor.r * 255);
                                    var cg = Math.round(bgColor.g * 255);
                                    var cb = Math.round(bgColor.b * 255);
                                    var ca = bgColor.a;
                                    ctx.fillStyle = "rgba(" + cr + "," + cg + "," + cb + "," + ca + ")";

                                    ctx.fill();
                                }

                            }
                        }

                        RoundCorner {
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            size: Appearance.rounding.screenRounding
                            corner: cornerEnum.topLeft
                            color: Appearance.colors.colLayer1
                        }

                    }

                    MaterialSymbol {
                        text: Config.options.bar.showClock ? "chevron_left" : "chevron_right"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer0
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: Config.options.bar.showClock ? 0 : Appearance.rounding.screenRounding

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            hoverEnabled: true
                            onClicked: (event) => {
                                if (event.button === Qt.LeftButton) {
                                    Config.options.bar.showClock = !Config.options.bar.showClock;
                                }
                            }
                        }
                    }

                    Revealer {
                        reveal: Config.options.bar.showClock
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        BarGroupR {
                            id: rightCenterGroup
                            Layout.fillHeight: true

                            ClockWidget {
                                showDate: (Config.options.bar.verbose && barRoot.useShortenedForm < 2)
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                            }
                        }
                    }

                    //AudioOsd {}
                }

                BrightnessOsd {
                    anchors.right: middleSection.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: middleSection.verticalCenter
                    z: 10
                }

                // AudioOsd - positioned absolutely on the right side
                AudioOsd {
                    anchors.left: middleSection.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: middleSection.verticalCenter
                    z: 10
                }

                RoundCorner {
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    anchors.right: middleSection.right
                    size: Appearance.rounding.screenRounding
                    corner: cornerEnum.topLeft
                    color: Appearance.colors.colLayer0
                    anchors.margins: -Appearance.rounding.screenRounding
                    visible: barBackground ? Config.options.appearance.transparency ? true : false : !barBackground ? true : false
                }

                RoundCorner {
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    anchors.left: middleSection.left
                    size: Appearance.rounding.screenRounding
                    corner: cornerEnum.topRight
                    color: Appearance.colors.colLayer0
                    anchors.margins: -Appearance.rounding.screenRounding
                    visible: barBackground ? Config.options.appearance.transparency ? true : false : !barBackground ? true : false
                }


                MouseArea { // Right side | scroll to change volume
                    id: barRightSideMouseArea

                    anchors.right: parent.right
                    implicitHeight: barHeight
                    width: (barRoot.width - middleSection.width) / 2

                    property bool hovered: false
                    property real lastScrollX: 0
                    property real lastScrollY: 0
                    property bool trackingScroll: false

                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onEntered: (event) => {
                        barRightSideMouseArea.hovered = true
                    }
                    onExited: (event) => {
                        barRightSideMouseArea.hovered = false
                        barRightSideMouseArea.trackingScroll = false
                    }
                    onPressed: (event) => {
                        if (event.button === Qt.LeftButton) {
                            GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen
                        }
                        else if (event.button === Qt.RightButton) {
                            MprisController.activePlayer.next()
                        }
                    }
                    // Scroll to change volume
                    WheelHandler {
                        onWheel: (event) => {
                            const currentVolume = Audio.value;
                            const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
                            if (event.angleDelta.y < 0)
                                Audio.sink.audio.volume -= step;
                            else if (event.angleDelta.y > 0)
                                Audio.sink.audio.volume = Math.min(1, Audio.sink.audio.volume + step);
                            // Store the mouse position and start tracking
                            barRightSideMouseArea.lastScrollX = event.x;
                            barRightSideMouseArea.lastScrollY = event.y;
                            barRightSideMouseArea.trackingScroll = true;
                        }
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    }

                    Item {
                        anchors.fill: parent
                        implicitHeight: rightSectionRowLayout.implicitHeight
                        implicitWidth: rightSectionRowLayout.implicitWidth

                        ScrollHint {
                            reveal: barRightSideMouseArea.hovered
                            icon: "volume_up"
                            tooltipText: qsTr("Scroll to change volume")
                            side: "right"
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        RowLayout {
                            id: rightSectionRowLayout
                            anchors.fill: parent
                            spacing: 5
                            layoutDirection: Qt.RightToLeft
                            visible: Config.options.bar.showTrayAndIcons


                            RippleButton { // Right sidebar button
                                id: rightSidebarButton
                                Layout.margins: 4
                                Layout.rightMargin: Appearance.rounding.screenRounding
                                Layout.fillHeight: true
                                implicitWidth: indicatorsRowLayout.implicitWidth + 10*2
                                buttonRadius: Appearance.rounding.full
                                colBackground: barRightSideMouseArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                colRipple: Appearance.colors.colLayer1Active
                                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                                toggled: GlobalStates.dashboardOpen
                                property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0

                                Behavior on colText {
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }

                                onPressed: {
                                    GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen
                                }

                                RowLayout {
                                    id: indicatorsRowLayout
                                    anchors.centerIn: parent
                                    property real realSpacing: 15
                                    spacing: 0

                                    Revealer {
                                        reveal: Notifications.list.length > 0
                                        Layout.fillHeight: true
                                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                                        Behavior on Layout.rightMargin {
                                            NumberAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                        NotifIndicator {}
                                    }

                                    HyprlandXkbIndicator {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.rightMargin: indicatorsRowLayout.realSpacing
                                    }


                                    Revealer {
                                        reveal: Audio.sink?.audio?.muted ?? false
                                        Layout.fillHeight: true
                                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                                        Behavior on Layout.rightMargin {
                                            NumberAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                        MaterialSymbol {
                                            text: "volume_off"
                                            iconSize: Appearance.font.pixelSize.larger
                                            color: rightSidebarButton.colText
                                        }
                                    }
                                    Revealer {
                                        reveal: Audio.source?.audio?.muted ?? false
                                        Layout.fillHeight: true
                                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                                        Behavior on Layout.rightMargin {
                                            NumberAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                        MaterialSymbol {
                                            text: "mic_off"
                                            iconSize: Appearance.font.pixelSize.larger
                                            color: rightSidebarButton.colText
                                        }
                                    }
                                    MaterialSymbol {
                                        Layout.rightMargin: indicatorsRowLayout.realSpacing
                                        text: Network.wifiEnabled ? Network.getNetworkIcon(Network.active?.strength ?? 0) : "signal_wifi_off"
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: rightSidebarButton.colText
				                    }

                                    BluetoothIndicator {}

                                    BatteryIndicator {
                                        id: batIndicator
                                        visible: (barRoot.useShortenedForm < 2 && UPower.displayDevice.isLaptopBattery)
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                            }

                            SysTray {
                                Layout.fillWidth: false
                                Layout.fillHeight: true
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }
                        }
                    }
                }
            }

        }

    }

}
