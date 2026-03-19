import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Sleex.Core
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
    id: root

    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        if (list.length === 0) return null;
        return list.find(p => p.isPlaying) ?? list[0];
    }

    property string _lastTrack: ""

    function resetState() {
        pill.animWidth   = 110;
        pill.animY       = -112;
        pill.animScale   = 1.0;
        pill.animOpacity = 1.0;
        contentRow.opacity = 0;
    }

    function runPlayerctl(cmd) {
        playerctlProc.running = false;
        playerctlProc.command = ["playerctl", cmd];
        playerctlProc.running = true;
    }

    Process { id: playerctlProc }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            if (!Config.options?.overlays?.mediaOverlayEnabled) return;
            const t = root.player?.trackTitle ?? "";
            if (t && t !== root._lastTrack) {
                root._lastTrack = t;
                win.triggerShow();
            }
        }
    }

    PanelWindow {
        id: win
        visible: false
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        mask: visible ? maskRegion : emptyRegion

        Region { id: emptyRegion }
        Region { id: maskRegion; item: bgRect }

        anchors { top: true; left: true; right: true }
        margins.top: 0
        width:  620
        height: 64 + 110 + 120
        color:  "transparent"

        function triggerShow() {
            if (visible) { holdTimer.restart(); return; }
            hideAnim.stop();
            showAnim.restart();
            holdTimer.restart();
        }

        Timer {
            id: holdTimer
            interval: 5000
            onTriggered: if (!pillArea.containsMouse) hideAnim.start()
        }

        SequentialAnimation {
            id: showAnim
            ScriptAction { script: { root.resetState(); win.visible = true; } }
            PauseAnimation { duration: 16 }
            NumberAnimation {
                target: pill; property: "animY"
                to: 0; duration: 420; easing.type: Easing.OutExpo
            }
            PauseAnimation { duration: 90 }
            ParallelAnimation {
                NumberAnimation {
                    target: pill; property: "animWidth"
                    to: 620; duration: 700; easing.type: Easing.OutQuart
                }
                SequentialAnimation {
                    PauseAnimation { duration: 400 }
                    NumberAnimation {
                        target: contentRow; property: "opacity"
                        to: 1; duration: 260; easing.type: Easing.OutCubic
                    }
                }
            }
        }

        SequentialAnimation {
            id: hideAnim
            ParallelAnimation {
                NumberAnimation {
                    target: contentRow; property: "opacity"
                    to: 0; duration: 210; easing.type: Easing.InCubic
                }
                SequentialAnimation {
                    PauseAnimation { duration: 150 }
                    NumberAnimation {
                        target: pill; property: "animWidth"
                        to: 110; duration: 620; easing.type: Easing.InOutQuart
                    }
                }
            }
            PauseAnimation { duration: 60 }
            ParallelAnimation {
                NumberAnimation {
                    target: pill; property: "animScale"
                    to: 0.0; duration: 520; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: pill; property: "animOpacity"
                    to: 0.0; duration: 380; easing.type: Easing.OutCubic
                }
            }
            ScriptAction { script: { win.visible = false; root.resetState(); } }
        }

        Item {
            id: pill
            width:  620
            height: 110
            y:      64
            anchors.horizontalCenter: parent.horizontalCenter

            property real animWidth:   110
            property real animY:      -112
            property real animScale:   1.0
            property real animOpacity: 1.0

            MouseArea {
                id: pillArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                propagateComposedEvents: true
                onContainsMouseChanged: {
                    if (containsMouse) {
                        holdTimer.stop();
                        if (hideAnim.running) {
                            hideAnim.stop();
                            pill.animWidth   = 620;
                            pill.animY       = 0;
                            pill.animScale   = 1.0;
                            pill.animOpacity = 1.0;
                            contentRow.opacity = 1;
                        }
                    } else if (win.visible) {
                        holdTimer.restart();
                    }
                }
            }

            StyledRectangularShadow { target: bgRect; opacity: pill.animOpacity }

            Rectangle {
                id: bgRect
                width:   pill.animWidth
                height:  110
                x:       (620 - width) / 2
                y:       pill.animY
                opacity: pill.animOpacity
                clip:    true

                transform: Scale {
                    xScale: pill.animScale; yScale: pill.animScale
                    origin.x: bgRect.width / 2; origin.y: 55
                }

                radius: {
                    const t = Math.max(0, Math.min(1, (pill.animWidth - 80) / 540));
                    return 55 + (Appearance.rounding.verylarge - 55) * t;
                }

                color: Qt.rgba(
                    Appearance.m3colors.m3surfaceContainerHigh.r,
                    Appearance.m3colors.m3surfaceContainerHigh.g,
                    Appearance.m3colors.m3surfaceContainerHigh.b,
                    Config.options?.appearance?.opacity ?? 1.0
                )
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                Item {
                    width: 80; height: 80
                    x: 15; y: 15

                    Rectangle {
                        anchors.fill: parent
                        radius: 40
                        color: Appearance.colors.colLayer2
                        visible: !artCanvas.hasArt
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "music_note"
                            font.pixelSize: 32
                            color: Appearance.colors.colOnLayer2
                        }
                    }

                    Canvas {
                        id: artCanvas
                        anchors.fill: parent
                        readonly property string artUrl: root.player?.trackArtUrl ?? ""
                        readonly property bool   hasArt: artUrl !== ""
                        visible: hasArt
                        onArtUrlChanged: artUrl ? loadImage(artUrl) : requestPaint()
                        onImageLoaded:   requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, 80, 80);
                            if (artUrl && isImageLoaded(artUrl)) {
                                ctx.save();
                                ctx.beginPath();
                                ctx.arc(40, 40, 40, 0, 2 * Math.PI);
                                ctx.clip();
                                ctx.drawImage(artUrl, 0, 0, 80, 80);
                                ctx.restore();
                            }
                        }
                    }
                }

                RowLayout {
                    id: contentRow
                    anchors {
                        top: parent.top; bottom: parent.bottom
                        left: parent.left; right: parent.right
                        leftMargin: 115; rightMargin: 15
                    }
                    spacing: 20
                    opacity: 0

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2
                        StyledText {
                            Layout.fillWidth: true
                            text: root.player ? (root.player.trackTitle || "Unknown") : "Nothing playing"
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnLayer2
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.player?.trackArtist ?? ""
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        spacing: 12
                        Layout.alignment: Qt.AlignVCenter
                        ControlBtn { symbol: "skip_previous";                                 onClicked: root.runPlayerctl("previous")   }
                        ControlBtn { symbol: root.player?.isPlaying ? "pause" : "play_arrow"; onClicked: root.runPlayerctl("play-pause"); isMain: true }
                        ControlBtn { symbol: "skip_next";                                     onClicked: root.runPlayerctl("next")       }
                    }
                }
            }
        }
    }

    component ControlBtn : Rectangle {
        property string symbol: ""
        property bool   isMain: false
        signal clicked()

        Layout.preferredWidth:  isMain ? 60 : 48
        Layout.preferredHeight: Layout.preferredWidth
        radius: Layout.preferredWidth / 2

        color: btnArea.pressed       ? Appearance.colors.colLayer2Hover
             : btnArea.containsMouse ? Appearance.colors.colLayer2
             :                         "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: parent.symbol
            font.pixelSize: parent.isMain ? 36 : 28
            color: Appearance.colors.colPrimary
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
