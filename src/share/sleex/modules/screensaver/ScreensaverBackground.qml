pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance

Item {
    id: root

    required property real clusterCenterX
    required property real clusterCenterY
    required property color accentColor
    required property bool active

    readonly property string mode: Config.options.screensaver.backgroundMode ?? "aura"

    // Pure pitch black OLED base
    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    // Mode 1: Ambient Aura localized behind the cluster
    Loader {
        active: root.active && root.mode === "aura"
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent

            Item {
                id: auraSource
                width: 720
                height: 720
                x: root.clusterCenterX - width / 2
                y: root.clusterCenterY - height / 2

                Rectangle {
                    width: 420
                    height: 420
                    radius: width / 2
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -60
                    anchors.verticalCenterOffset: -30
                    color: ColorUtils.transparentize(root.accentColor, 0.72)

                    SequentialAnimation on scale {
                        running: root.active && root.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.92; to: 1.12; duration: 6000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.12; to: 0.92; duration: 6000; easing.type: Easing.InOutSine }
                    }
                }

                Rectangle {
                    width: 360
                    height: 360
                    radius: width / 2
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 75
                    anchors.verticalCenterOffset: 45
                    color: ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.78)

                    SequentialAnimation on scale {
                        running: root.active && root.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.08; to: 0.9; duration: 7500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.9; to: 1.08; duration: 7500; easing.type: Easing.InOutSine }
                    }
                }

                RotationAnimator on rotation {
                    running: root.active && root.visible
                    from: 0
                    to: 360
                    duration: 42000
                    loops: Animation.Infinite
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 64
                    blur: 1.0
                }
            }
        }
    }

    // Mode 2: Material 3 Expressive organic morphing shapes behind the cluster
    Loader {
        active: root.active && root.mode === "shapes"
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent

            Item {
                width: 680
                height: 680
                x: root.clusterCenterX - width / 2
                y: root.clusterCenterY - height / 2

                Rectangle {
                    anchors.centerIn: parent
                    width: 460
                    height: 300
                    radius: 140
                    color: ColorUtils.transparentize(root.accentColor, 0.88)
                    border.width: 1
                    border.color: ColorUtils.transparentize(root.accentColor, 0.65)

                    RotationAnimator on rotation {
                        running: root.active && root.visible
                        from: 0
                        to: 360
                        duration: 36000
                        loops: Animation.Infinite
                    }
                    SequentialAnimation on scale {
                        running: root.active && root.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.95; to: 1.08; duration: 5000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.08; to: 0.95; duration: 5000; easing.type: Easing.InOutSine }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 340
                    height: 340
                    radius: 96
                    color: ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.90)
                    border.width: 1
                    border.color: ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.68)

                    RotationAnimator on rotation {
                        running: root.active && root.visible
                        from: 360
                        to: 0
                        duration: 28000
                        loops: Animation.Infinite
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 520
                    height: 220
                    radius: 110
                    color: ColorUtils.transparentize(Appearance.m3colors.m3secondary, 0.92)
                    border.width: 1
                    border.color: ColorUtils.transparentize(Appearance.m3colors.m3secondary, 0.72)

                    RotationAnimator on rotation {
                        running: root.active && root.visible
                        from: 45
                        to: 405
                        duration: 48000
                        loops: Animation.Infinite
                    }
                }
            }
        }
    }

    // Mode 3: Subtle floating ambient particles over pitch black
    Loader {
        active: root.active && root.mode === "particles"
        anchors.fill: parent
        sourceComponent: Item {
            id: particlesLayer
            anchors.fill: parent

            Repeater {
                model: 18
                delegate: Rectangle {
                    id: particle
                    required property int index

                    readonly property real baseX: ((index * 173 + 47) % 97) / 100.0
                    readonly property real baseY: ((index * 251 + 29) % 95) / 100.0
                    readonly property real particleSize: 5 + (index % 4) * 3
                    readonly property int cycleMs: 7000 + (index % 5) * 2200

                    width: particleSize
                    height: particleSize
                    radius: particleSize / 2
                    x: particlesLayer.width * baseX
                    y: particlesLayer.height * baseY
                    color: index % 3 === 0
                        ? root.accentColor
                        : (index % 3 === 1 ? Appearance.m3colors.m3tertiary : Appearance.m3colors.m3secondary)
                    opacity: 0.15

                    SequentialAnimation on y {
                        running: root.active && root.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: particlesLayer.height * particle.baseY
                            to: Math.max(16, particlesLayer.height * particle.baseY - 48)
                            duration: particle.cycleMs
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: Math.max(16, particlesLayer.height * particle.baseY - 48)
                            to: particlesLayer.height * particle.baseY
                            duration: particle.cycleMs
                            easing.type: Easing.InOutSine
                        }
                    }

                    SequentialAnimation on opacity {
                        running: root.active && root.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 0.08
                            to: 0.42
                            duration: particle.cycleMs * 0.5
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 0.42
                            to: 0.08
                            duration: particle.cycleMs * 0.5
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }
        }
    }

    // Mode 4: Scrimmed Wallpaper Diaporama
    Loader {
        active: root.active && root.mode === "diaporama"
        anchors.fill: parent
        sourceComponent: Item {
            id: diaporamaRoot
            anchors.fill: parent

            property var slides: []
            property int currentIndex: 0
            property bool showingA: true
            property string sourceA: ""
            property string sourceB: ""

            function refreshSlides() {
                const dir = (Config.options.screensaver.diaporamaPath || "").trim() || "/usr/share/backgrounds/sleex/";
                scanProcess.command = [
                    "find", dir, "-maxdepth", "3", "-type", "f",
                    "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", ")",
                    "-print"
                ];
                scanProcess.running = true;
            }

            function advanceSlide() {
                if (!slides || slides.length === 0) return;
                if (slides.length === 1) {
                    if (sourceA !== slides[0]) {
                        sourceA = slides[0];
                        showingA = true;
                    }
                    return;
                }
                let nextIdx = currentIndex;
                if (slides.length > 1) {
                    nextIdx = Math.floor(Math.random() * slides.length);
                    if (nextIdx === currentIndex) {
                        nextIdx = (currentIndex + 1) % slides.length;
                    }
                }
                currentIndex = nextIdx;
                if (showingA) {
                    sourceB = slides[nextIdx];
                    showingA = false;
                } else {
                    sourceA = slides[nextIdx];
                    showingA = true;
                }
            }

            Component.onCompleted: refreshSlides()

            Connections {
                target: Config.options.screensaver
                function onDiaporamaPathChanged() {
                    diaporamaRoot.refreshSlides();
                }
            }

            Process {
                id: scanProcess
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        const found = text.split("\n").map(s => s.trim()).filter(s => s.length > 0);
                        if (found.length > 0) {
                            diaporamaRoot.slides = found;
                        } else if (Config.options.background.wallpaperPath) {
                            diaporamaRoot.slides = [Config.options.background.wallpaperPath];
                        } else {
                            diaporamaRoot.slides = [];
                        }
                        if (diaporamaRoot.slides.length > 0) {
                            diaporamaRoot.currentIndex = Math.floor(Math.random() * diaporamaRoot.slides.length);
                            diaporamaRoot.sourceA = diaporamaRoot.slides[diaporamaRoot.currentIndex];
                            diaporamaRoot.showingA = true;
                        }
                    }
                }
            }

            Timer {
                interval: Math.max(5, Config.options.screensaver.diaporamaInterval ?? 30) * 1000
                repeat: true
                running: root.active && diaporamaRoot.slides.length > 1
                onTriggered: diaporamaRoot.advanceSlide()
            }

            Item {
                anchors.fill: parent

                WallpaperDisplay {
                    anchors.fill: parent
                    source: diaporamaRoot.sourceA
                    playing: root.active && diaporamaRoot.showingA
                    opacity: diaporamaRoot.showingA ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 1000; easing.type: Easing.InOutCubic }
                    }
                }

                WallpaperDisplay {
                    anchors.fill: parent
                    source: diaporamaRoot.sourceB
                    playing: root.active && !diaporamaRoot.showingA
                    opacity: diaporamaRoot.showingA ? 0.0 : 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: 1000; easing.type: Easing.InOutCubic }
                    }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 24
                    blur: 0.35
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: Math.max(0, Math.min(1, (Config.options.screensaver.diaporamaScrimOpacity ?? 70) / 100.0))
            }
        }
    }

    // Bottom full-width Cava audio wave visualizer when music is playing
    Loader {
        id: visualizerLoader
        active: root.active
            && (Config.options.screensaver.enableVisualizer ?? true)
            && MprisController.isPlaying
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 180
        sourceComponent: Item {
            id: visualizerRoot
            anchors.fill: parent

            property list<real> visualizerPoints: []

            Process {
                id: cavaProc
                running: root.active
                    && root.visible
                    && (Config.options.screensaver.enableVisualizer ?? true)
                    && MprisController.isPlaying
                onRunningChanged: {
                    if (!cavaProc.running) {
                        visualizerRoot.visualizerPoints = [];
                    }
                }
                command: ["cava", "-p", "/usr/share/sleex/scripts/cava/raw_output_config.txt"]
                stdout: SplitParser {
                    onRead: data => {
                        const points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                        visualizerRoot.visualizerPoints = points;
                    }
                }
            }

            Component.onDestruction: {
                if (cavaProc.running) {
                    cavaProc.running = false;
                }
            }

            WaveVisualizer {
                anchors.fill: parent
                live: root.active && MprisController.isPlaying
                points: visualizerRoot.visualizerPoints
                maxVisualizerValue: 1000
                smoothing: 2
                color: root.accentColor
            }
        }
    }
}
