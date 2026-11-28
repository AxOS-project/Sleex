pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance

Item {
    id: root

    required property real screenWidth
    required property real screenHeight

    readonly property real margin: 64
    readonly property real availW: Math.max(0, screenWidth - width - margin * 2)
    readonly property real availH: Math.max(0, screenHeight - height - margin * 2)

    property real normX: 0.5
    property real normY: 0.5

    readonly property real centerX: x + width / 2
    readonly property real centerY: y + height / 2
    readonly property color activeAccentColor: (mediaLoader.status === Loader.Ready && mediaLoader.item)
        ? mediaLoader.item.dominantColor
        : Appearance.m3colors.m3primary

    width: contentLayout.implicitWidth
    height: contentLayout.implicitHeight
    x: Math.round(margin + availW * normX)
    y: Math.round(margin + availH * normY)
    opacity: 0

    function pickNewRandomPosition() {
        let nextX = Math.random();
        let nextY = Math.random();

        // Ensure noticeable displacement so pixels actually rest
        for (let attempt = 0; attempt < 8; attempt++) {
            if (Math.hypot(nextX - normX, nextY - normY) >= 0.35) break;
            nextX = Math.random();
            nextY = Math.random();
        }

        normX = nextX;
        normY = nextY;
    }

    Component.onCompleted: introAnim.start()

    NumberAnimation {
        id: introAnim
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 600
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: teleportSequence

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0.0
            duration: 600
            easing.type: Easing.InOutQuad
        }
        ScriptAction {
            script: root.pickNewRandomPosition()
        }
        NumberAnimation {
            target: root
            property: "opacity"
            to: 1.0
            duration: 600
            easing.type: Easing.InOutQuad
        }
    }

    Timer {
        interval: Math.max(15, Config.options.screensaver.moveInterval ?? 60) * 1000
        repeat: true
        running: root.visible
        onTriggered: teleportSequence.restart()
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: 20

        // M3 Expressive Clock & Date Pill
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: DateTime.time
                font.family: Config.options.background.clockFontFamily || Appearance.font.family.expressive
                font.pixelSize: 112
                font.weight: Font.Bold
                color: Appearance.m3colors.m3primary
                style: Text.Raised
                styleColor: Appearance.colors.colShadow
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: dateRow.implicitWidth + 28
                implicitHeight: dateRow.implicitHeight + 14
                radius: Appearance.rounding.full
                color: ColorUtils.mix("#000000", Appearance.m3colors.m3secondaryContainer, 0.5)
                border.width: 1
                border.color: ColorUtils.transparentize(Appearance.m3colors.m3outlineVariant, 0.65)

                RowLayout {
                    id: dateRow
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialSymbol {
                        text: "calendar_today"
                        iconSize: 16
                        fill: 1
                        color: Appearance.m3colors.m3onSecondaryContainer
                    }

                    StyledText {
                        text: DateTime.longDateFormat
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.m3colors.m3onSecondaryContainer
                    }
                }
            }
        }

        // Optional Weather Card
        Loader {
            id: weatherLoader
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: (Config.options.dashboard.enableWeather ?? false)
                && (Config.options.screensaver.enableWeather ?? true)
            visible: active && status === Loader.Ready
            sourceComponent: ScreensaverWeatherCard {}
        }

        // Optional Media Player Card (only when music is playing)
        Loader {
            id: mediaLoader
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: (Config.options.screensaver.enableMedia ?? true) && MprisController.isPlaying
            visible: active && status === Loader.Ready
            sourceComponent: ScreensaverMediaCard {}
        }
    }
}
