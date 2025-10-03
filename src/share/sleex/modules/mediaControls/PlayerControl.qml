import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Item { // Player instance
    id: playerController
    required property MprisPlayer player

    // art props
    property string artUrl: player?.trackArtUrl || ""
    property color artDominantColor: Appearance.m3colors.m3secondaryContainer
    property bool artLoaded: false

    // visualizer properties (kept)
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000
    property int visualizerSmoothing: 2

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    component TrackChangeButton: RippleButton {
        implicitWidth: 24
        implicitHeight: 24

        property var iconName
        colBackground: ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
        colBackgroundHover: blendedColors.colSecondaryContainerHover
        colRipple: blendedColors.colSecondaryContainerActive

        contentItem: MaterialSymbol {
            iconSize: Appearance.font.pixelSize.huge
            fill: 1
            horizontalAlignment: Text.AlignHCenter
            color: blendedColors.colOnSecondaryContainer
            text: iconName

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    Timer { // Force update for prevision
        running: playerController.player?.playbackState == MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: {
            playerController.player.positionChanged()
        }
    }

    // react when player.trackArtUrl changes
    onArtUrlChanged: {
        // console.log("[playerController] artUrl changed ->", artUrl)
        artLoaded = false
        // set image.source below in mediaArt/blurredArt (they read playerController.artUrl)
        // ColorQuantizer.source is driven by mediaArt.source when artLoaded is true
    }

    // ColorQuantizer: only run when mediaArt has loaded
    ColorQuantizer {
        id: colorQuantizer
        // set source only when artLoaded so it doesn't spin on invalid URL
        source: playerController.artLoaded ? mediaArt.source : ""
        depth: 0
        rescaleSize: 1

        onColorsChanged: {
            if (colors && colors.length > 0) {
                playerController.artDominantColor = colors[0]
                // console.log("[colorQuantizer] dominant color:", colors[0])
            } else {
                playerController.artDominantColor = Appearance.m3colors.m3secondaryContainer
            }
        }
    }

    property bool backgroundIsDark: (artDominantColor && artDominantColor.hslLightness) ? (artDominantColor.hslLightness < 0.5) : true

    property QtObject blendedColors: QtObject {
        property color colLayer0: ColorUtils.mix(Appearance.colors.colLayer0, artDominantColor, (backgroundIsDark && Appearance.m3colors.darkmode) ? 0.6 : 0.5)
        property color colLayer1: ColorUtils.mix(Appearance.colors.colLayer1, artDominantColor, 0.5)
        property color colOnLayer0: ColorUtils.mix(Appearance.colors.colOnLayer0, artDominantColor, 0.5)
        property color colOnLayer1: ColorUtils.mix(Appearance.colors.colOnLayer1, artDominantColor, 0.5)
        property color colSubtext: ColorUtils.mix(Appearance.colors.colOnLayer1, artDominantColor, 0.5)
        property color colPrimary: ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.colors.colPrimary, artDominantColor), artDominantColor, 0.5)
        property color colPrimaryHover: ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.colors.colPrimaryHover, artDominantColor), artDominantColor, 0.3)
        property color colPrimaryActive: ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.colors.colPrimaryActive, artDominantColor), artDominantColor, 0.3)
        property color colSecondaryContainer: ColorUtils.mix(Appearance.m3colors.m3secondaryContainer, artDominantColor, 0.15)
        property color colSecondaryContainerHover: ColorUtils.mix(Appearance.colors.colSecondaryContainerHover, artDominantColor, 0.3)
        property color colSecondaryContainerActive: ColorUtils.mix(Appearance.colors.colSecondaryContainerActive, artDominantColor, 0.5)
        property color colOnPrimary: ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.m3colors.m3onPrimary, artDominantColor), artDominantColor, 0.5)
        property color colOnSecondaryContainer: ColorUtils.mix(Appearance.m3colors.m3onSecondaryContainer, artDominantColor, 0.5)
    }

    Rectangle { // Background
        id: background
        anchors.fill: parent
        color: blendedColors.colLayer0
        radius: Appearance.rounding.normal

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        Image {
            id: blurredArt
            anchors.fill: parent

            // use artUrl directly (QML Image handles http(s) and file://)
            source: playerController.artUrl && playerController.artUrl.length > 0 ? playerController.artUrl : ""
            cache: true
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: background.width
            sourceSize.height: background.height
            antialiasing: true

            onStatusChanged: {
                if (status === Image.Ready) {
                    // console.log("[blurredArt] loaded:", source)
                    // do not set artLoaded here — prefer mediaArt (higher-res square) to control quantizer
                } else if (status === Image.Error) {
                    console.warn("[blurredArt] failed to load:", source, "error:", errorString)
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                source: blurredArt
                saturation: 0.2
                blurEnabled: true
                blurMax: 100
                blur: 1
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(blendedColors.colLayer0, 0.25)
                radius: root.popupRounding
            }
        }

        WaveVisualizer {
            id: visualizerCanvas
            anchors.fill: parent
            live: playerController.player?.isPlaying
            points: playerController.visualizerPoints
            maxVisualizerValue: playerController.maxVisualizerValue
            smoothing: playerController.visualizerSmoothing
            color: blendedColors.colPrimary
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.contentPadding
            spacing: 15

            Rectangle { // Art background
                id: artBackground
                Layout.fillHeight: true
                implicitWidth: height
                radius: root.artRounding
                color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artBackground.width
                        height: artBackground.height
                        radius: artBackground.radius
                    }
                }

                Image { // Art image (square album art)
                    id: mediaArt
                    property int size: parent.height
                    anchors.fill: parent
                    width: size
                    height: size
                    sourceSize.width: size
                    sourceSize.height: size
                    fillMode: Image.PreserveAspectCrop
                    antialiasing: true
                    asynchronous: true
                    cache: true

                    // prefer playerController.artUrl; if empty, keep blank
                    source: playerController.artUrl && playerController.artUrl.length > 0 ? playerController.artUrl : ""

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            // console.log("[mediaArt] loaded:", source)
                            // mark art as loaded so ColorQuantizer will run
                            playerController.artLoaded = true
                        } else if (status === Image.Error) {
                            playerController.artLoaded = false
                            console.warn("[mediaArt] failed to load:", source, "error:", errorString)
                        } else if (status === Image.Loading) {
                            playerController.artLoaded = false
                        }
                    }
                }
            }

            ColumnLayout { // Info & controls
                Layout.fillHeight: true
                spacing: 2

                StyledText {
                    id: trackTitle
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: blendedColors.colOnLayer0
                    elide: Text.ElideRight
                    text: StringUtils.cleanMusicTitle(playerController.player?.trackTitle) || "Untitled"
                }
                StyledText {
                    id: trackArtist
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: playerController.player?.trackArtist
                }
                Item { Layout.fillHeight: true }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: trackTime.implicitHeight + sliderRow.implicitHeight

                    StyledText {
                        id: trackTime
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        anchors.left: parent.left
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: blendedColors.colSubtext
                        elide: Text.ElideRight
                        text: `${StringUtils.friendlyTimeForSeconds(playerController.player?.position)} / ${StringUtils.friendlyTimeForSeconds(playerController.player?.length)}`
                    }
                    RowLayout {
                        id: sliderRow
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        TrackChangeButton {
                            iconName: "skip_previous"
                            onClicked: playerController.player?.previous()
                        }
                        Item {
                            id: progressBarContainer
                            Layout.fillWidth: true
                            implicitHeight: 4

                            StyledProgressBar {
                                id: progressBar
                                anchors.fill: parent
                                highlightColor: blendedColors.colPrimary
                                trackColor: blendedColors.colSecondaryContainer
                                value: playerController.player?.position / playerController.player?.length
                                sperm: playerController.player?.isPlaying
                            }
                        }
                        TrackChangeButton {
                            iconName: "skip_next"
                            onClicked: playerController.player?.next()
                        }
                    }

                    RippleButton {
                        id: playPauseButton
                        anchors.right: parent.right
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        property real size: 44
                        implicitWidth: size
                        implicitHeight: size
                        onClicked: playerController.player.togglePlaying();

                        buttonRadius: playerController.player?.isPlaying ? Appearance?.rounding.normal : size / 2
                        colBackground: playerController.player?.isPlaying ? blendedColors.colPrimary : blendedColors.colSecondaryContainer
                        colBackgroundHover: playerController.player?.isPlaying ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover
                        colRipple: playerController.player?.isPlaying ? blendedColors.colPrimaryActive : blendedColors.colSecondaryContainerActive

                        contentItem: MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.huge
                            fill: 1
                            horizontalAlignment: Text.AlignHCenter
                            color: playerController.player?.isPlaying ? blendedColors.colOnPrimary : blendedColors.colOnSecondaryContainer
                            text: playerController.player?.isPlaying ? "pause" : "play_arrow"

                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }
                    }
                }
            }
        }
    }
}
