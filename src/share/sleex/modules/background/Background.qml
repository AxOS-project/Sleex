pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    readonly property bool fixedClockPosition: Config.options.background.fixedClockPosition
    readonly property real fixedClockX: Config.options.background.clockX
    readonly property real fixedClockY: Config.options.background.clockY

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: bgRoot
            required property var modelData
            property string wallpaperPath: Config.options.background.wallpaperPath

            property real clockX: Config.options.background.clockX !== 0 ? Config.options.background.clockX : modelData.width / 2
            property real clockY: Config.options.background.clockY !== 0 ? Config.options.background.clockY : modelData.height / 2
            property var textHorizontalAlignment: clockX < screen.width / 3 ? Text.AlignLeft :
                (clockX > screen.width * 2 / 3 ? Text.AlignRight : Text.AlignHCenter)

            property color dominantColor: Appearance.colors.colPrimary
            property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
            property color colText: Config.options.background.clockMode == "light" ? Appearance.colors.colPrimary : ColorUtils.colorWithLightness(Appearance.colors.colPrimary, 0.12)

            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell:background"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            // Animated wallpaper container
            Item {
                id: wallpaperContainer
                anchors.fill: parent
                property string currentPath: ""

                AnimatedImage {
                    id: currentWallpaper
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    opacity: 1.0
                }

                AnimatedImage {
                    id: previousWallpaper
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.0
                }

                states: [
                    State {
                        name: "showingCurrent"
                        // Don't mind the qml warnings, this is safe because currentWallpaper 
                        // and previousWallpaper are static ids, not evaluated bindings.
                        PropertyChanges { target: currentWallpaper; opacity: 1.0 }
                        PropertyChanges { target: previousWallpaper; opacity: 0.0 }
                    },
                    State {
                        name: "showingPrevious"
                        PropertyChanges { target: currentWallpaper; opacity: 0.0 }
                        PropertyChanges { target: previousWallpaper; opacity: 1.0 }
                    },
                    State {
                        name: "crossfading"
                        // no forced change here
                    }
                ]

                transitions: [
                    Transition {
                        from: "*" 
                        to: "crossfading"
                        ParallelAnimation {
                            id: crossfadeAnim
                            NumberAnimation { target: currentWallpaper; property: "opacity"; from: 0; to: 1; duration: 500; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: previousWallpaper; property: "opacity"; from: 1; to: 0; duration: 500; easing.type: Easing.InOutQuad }

                            onStopped: {
                                currentWallpaper.opacity = 1.0
                                previousWallpaper.opacity = 0.0
                                wallpaperContainer.state = "showingCurrent"
                            }
                        }
                    }
                ]

                Connections {
                    target: bgRoot
                    function onWallpaperPathChanged() {
                        var newPath = bgRoot.wallpaperPath

                        if (wallpaperContainer.currentPath !== "" && wallpaperContainer.currentPath !== newPath) {
                            // If a crossfade is already happening, throw it in a wall
                            if (wallpaperContainer.state === "crossfading") {
                                crossfadeAnim.stop()
                                wallpaperContainer.state = "showingCurrent"
                            }

                            previousWallpaper.source = wallpaperContainer.currentPath
                            currentWallpaper.source = newPath

                            currentWallpaper.opacity = 0
                            previousWallpaper.opacity = 1

                            wallpaperContainer.state = "crossfading"
                        } else {
                            currentWallpaper.source = newPath
                            wallpaperContainer.state = "showingCurrent"
                        }

                        wallpaperContainer.currentPath = newPath
                    }
                }

                Component.onCompleted: {
                    currentWallpaper.source = bgRoot.wallpaperPath
                    currentPath = bgRoot.wallpaperPath
                    currentWallpaper.opacity = 1
                    previousWallpaper.opacity = 0
                    wallpaperContainer.state = "showingCurrent"
                }
            }


            Clock {
                id: clock
                z: 1
                screenWidth: bgRoot.screen.width
                screenHeight: bgRoot.screen.height
                clockX: bgRoot.clockX
                clockY: bgRoot.clockY
                clockSizeMultiplier: Config.options.background.clockSizeMultiplier
                fixedClockPosition: root.fixedClockPosition
                textColor: bgRoot.colText
                textHorizontalAlignment: bgRoot.textHorizontalAlignment

                onClockPositionChanged: function(newX, newY) {
                    bgRoot.clockX = newX
                    bgRoot.clockY = newY
                }

                onFixedPositionToggled: {
                    Config.options.background.fixedClockPosition = !root.fixedClockPosition
                }
            }

            Watermark {
                visibleWatermark: Config.options.background.showWatermark
            }
            Quote {
                visibleQuote: Config.options.background.enableQuote
            }
        }
    }
}