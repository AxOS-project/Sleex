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
            property var textHorizontalAlignment: clockX < screen.width / 3 ? Text.AlignLeft : (clockX > screen.width * 2 / 3 ? Text.AlignRight : Text.AlignHCenter)
            property color dominantColor: Appearance.colors.colPrimary
            property color colText: Config.options.background.clockMode == "light" ? Appearance.colors.colPrimary : ColorUtils.colorWithLightness(Appearance.colors.colPrimary, 0.12)

            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell:background"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            Item {
                id: wallpaperContainer
                anchors.fill: parent
                clip: true
                property string currentPath: ""
                
                property string transitionType: Config.options.background.wallpaperTransition

                AnimatedImage {
                    id: previousWallpaper
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    opacity: 1
                    playing: true
                }

                AnimatedImage {
                    id: currentWallpaper
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    opacity: 1
                    playing: true
                }

                states: State {
                    name: "animating"
                    PropertyChanges { target: currentWallpaper; opacity: 1.0; scale: 1.0 }
                    PropertyChanges { target: previousWallpaper; opacity: 0.0 }
                }

                transitions: Transition {
                    to: "animating"
                    ParallelAnimation {
                        NumberAnimation { target: currentWallpaper; property: "opacity"; from: 0; to: 1; duration: Config.options.background.transitionDuration }
                        NumberAnimation { target: previousWallpaper; property: "opacity"; from: 1; to: 0; duration: Config.options.background.transitionDuration }
                        
                        NumberAnimation { 
                            target: currentWallpaper; property: "scale"
                            from: wallpaperContainer.transitionType === "scale" ? 1.15 : 1.0
                            to: 1.0; duration: Config.options.background.transitionDuration; easing.type: Easing.OutCubic 
                        }
                    }
                }

                Connections {
                    target: bgRoot
                    function onWallpaperPathChanged() {
                        var path = bgRoot.wallpaperPath
                        if (path === wallpaperContainer.currentPath) return
                        
                        previousWallpaper.source = wallpaperContainer.currentPath
                        currentWallpaper.source = path
                        
                        currentWallpaper.playing = false
                        currentWallpaper.playing = true
                        
                        wallpaperContainer.state = ""
                        wallpaperContainer.state = "animating"
                        wallpaperContainer.currentPath = path
                    }
                }

                Component.onCompleted: {
                    currentWallpaper.source = bgRoot.wallpaperPath
                    wallpaperContainer.currentPath = bgRoot.wallpaperPath
                    wallpaperContainer.state = "animating"
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
                onClockPositionChanged: function(x, y) { bgRoot.clockX = x; bgRoot.clockY = y }
                onFixedPositionToggled: function() { Config.options.background.fixedClockPosition = !root.fixedClockPosition }
            }

            Watermark { visibleWatermark: Config.options.background.showWatermark }
            Quote { visibleQuote: Config.options.background.enableQuote }
        }
    }
}
