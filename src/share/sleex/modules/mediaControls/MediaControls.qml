import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property var realPlayers: Mpris.players.values.filter(player => isRealPlayer(player))
    readonly property var meaningfulPlayers: filterDuplicatePlayers(realPlayers)
    readonly property real osdWidth: Appearance.sizes.osdWidth
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real contentPadding: 13
    property real popupRounding: Appearance.rounding.screenRounding
    property real artRounding: Appearance.rounding.verysmall
    property list<real> visualizerPoints: []

    property bool hasPlasmaIntegration: false

    function isRealPlayer(player) {
        return (
            !(hasPlasmaIntegration && player.dbusName.startsWith('org.mpris.MediaPlayer2.firefox')) &&
            !(hasPlasmaIntegration && player.dbusName.startsWith('org.mpris.MediaPlayer2.chromium')) &&
            !player.dbusName?.startsWith('org.mpris.MediaPlayer2.playerctld') &&
            !(player.dbusName?.endsWith('.mpd') && !player.dbusName.endsWith('MediaPlayer2.mpd'))
        );
    }

    function filterDuplicatePlayers(players) {
        let filtered = [];
        let used = new Set();

        for (let i = 0; i < players.length; ++i) {
            if (used.has(i)) continue;
            let p1 = players[i];
            let group = [i];

            for (let j = i + 1; j < players.length; ++j) {
                let p2 = players[j];
                if (p1.trackTitle && p2.trackTitle &&
                    (p1.trackTitle.includes(p2.trackTitle) || p2.trackTitle.includes(p1.trackTitle))) {
                    group.push(j);
                }
            }

            let chosenIdx = group.find(idx => players[idx].trackArtUrl && players[idx].trackArtUrl.length > 0);
            if (chosenIdx === undefined) chosenIdx = group[0];

            filtered.push(players[chosenIdx]);
            group.forEach(idx => used.add(idx));
        }
        return filtered;
    }

    Process {
        id: cavaProc
        running: root.visible
        onRunningChanged: {
            if (!cavaProc.running) {
                root.visualizerPoints = [];
            }
        }
        command: ["cava", "-p", `/usr/share/sleex/scripts/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                let points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                root.visualizerPoints = points;
            }
        }
    }

    Component.onDestruction: {
        if (cavaProc.running) {
            cavaProc.running = false
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        PlayerControlBlank {
            anchors.fill: parent
            artDominantColor: Appearance.m3colors.m3secondaryContainer
            visible: root.meaningfulPlayers.length === 0
        }
        

        Loader {
            active: root.meaningfulPlayers.length > 0
            visible: active
            sourceComponent: PlayerControl {
                player: root.meaningfulPlayers[0]
                visualizerPoints: root.visualizerPoints;
            }
        }
    }
}