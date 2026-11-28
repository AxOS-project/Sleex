pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance

Item {
    id: root

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool effectivelyVisible: visible && (Window.window?.visible ?? false)
    readonly property color dominantColor: artDominantColor

    property color artDominantColor: Appearance.m3colors.m3primary
    property real stableLength: 0
    property string currentTrackId: ""

    implicitWidth: 440
    implicitHeight: 104

    Behavior on artDominantColor {
        ColorAnimation {
            duration: 500
            easing.type: Easing.InOutCubic
        }
    }

    function updateStableLength() {
        const trackKey = player?.trackId || ((player?.trackTitle ?? "") + "|" + (player?.trackArtist ?? ""));
        if (trackKey !== currentTrackId) {
            currentTrackId = trackKey;
            stableLength = 0;
        }
        const len = player?.length ?? 0;
        if (len > stableLength) {
            stableLength = len;
        }
    }

    onPlayerChanged: {
        artDominantColor = Appearance.m3colors.m3primary;
        updateStableLength();
    }

    onEffectivelyVisibleChanged: {
        if (effectivelyVisible) {
            updateStableLength();
            if (player?.isPlaying) {
                player.positionChanged();
            }
        }
    }

    Connections {
        target: root.player
        function onLengthChanged() { root.updateStableLength(); }
        function onTrackIdChanged() { root.updateStableLength(); }
        function onTrackTitleChanged() { root.updateStableLength(); }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.player?.trackArtUrl || ""
        depth: 0
        rescaleSize: 1
        onColorsChanged: {
            if (colors && colors.length > 0) {
                root.artDominantColor = colors[0];
            } else {
                root.artDominantColor = Appearance.m3colors.m3primary;
            }
        }
    }

    readonly property QtObject blendedColors: QtObject {
        property color primary: ColorUtils.mix(Appearance.m3colors.m3primary, root.artDominantColor, 0.5)
        property color track: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3secondaryContainer, root.artDominantColor, 0.35), 0.55)
        property color onSurface: Appearance.m3colors.m3onSurface
        property color subtext: Appearance.m3colors.m3onSurfaceVariant
    }

    Timer {
        interval: 250
        repeat: true
        running: root.effectivelyVisible && (root.player?.isPlaying ?? false)
        onTriggered: root.player?.positionChanged()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 16

        ClippingRectangle {
            Layout.preferredWidth: 104
            Layout.preferredHeight: 104
            radius: Appearance.rounding.large
            color: ColorUtils.mix("#121216", root.artDominantColor, 0.25)

            MaterialSymbol {
                anchors.centerIn: parent
                text: "music_note"
                iconSize: 40
                color: root.blendedColors.primary
                visible: coverArt.status !== Image.Ready
            }

            Image {
                id: coverArt
                anchors.fill: parent
                source: root.player?.trackArtUrl || ""
                sourceSize: Qt.size(256, 256)
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            RowLayout {
                spacing: 6
                MaterialSymbol {
                    text: "graphic_eq"
                    iconSize: 16
                    color: root.blendedColors.primary
                }
                StyledText {
                    text: qsTr("Now Playing")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: root.blendedColors.primary
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || qsTr("Untitled")
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Bold
                color: root.blendedColors.onSurface
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist || qsTr("Unknown Artist")
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.blendedColors.subtext
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    valueBarHeight: 4
                    highlightColor: root.blendedColors.primary
                    trackColor: root.blendedColors.track
                    value: root.stableLength > 0
                        ? Math.max(0, Math.min(1, (root.player?.position ?? 0) / root.stableLength))
                        : 0
                    sperm: (root.player?.isPlaying ?? false) && root.effectivelyVisible
                    animateSperm: root.effectivelyVisible
                }

                StyledText {
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.blendedColors.subtext
                    text: {
                        const len = root.stableLength;
                        if (len <= 0) return "0:00";
                        const pos = root.player?.position ?? 0;
                        return `${StringUtils.friendlyTimeForSeconds(pos)} / ${StringUtils.friendlyTimeForSeconds(len)}`;
                    }
                }
            }
        }
    }
}
