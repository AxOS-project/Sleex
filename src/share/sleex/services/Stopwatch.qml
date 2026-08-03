pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool running: false
    property int elapsedTime: 0 // In milliseconds
    property var laps: []

    readonly property string formattedTime: formatTime(elapsedTime)

    function formatTime(ms) {
        let totalTenths = Math.floor(ms / 100)
        let tenths = totalTenths % 10
        let totalSeconds = Math.floor(totalTenths / 10)
        let minutes = Math.floor(totalSeconds / 60)
        let seconds = totalSeconds % 60

        let mStr = minutes < 10 ? "0" + minutes : minutes
        let sStr = seconds < 10 ? "0" + seconds : seconds
        return mStr + ":" + sStr + "." + tenths
    }

    function start() {
        running = true
    }

    function pause() {
        running = false
    }

    function toggle() {
        running = !running
    }

    function reset() {
        running = false
        elapsedTime = 0
        laps = []
    }

    function recordLap() {
        if (elapsedTime <= 0) return
        let lapNum = laps.length + 1
        let currentFormatted = formattedTime
        let previousTotalMs = laps.length > 0 ? laps[0].rawTotalMs : 0
        let lapDurationMs = elapsedTime - previousTotalMs
        let lapDurationFormatted = formatTime(lapDurationMs)

        let newLap = {
            "number": lapNum,
            "lapTime": lapDurationFormatted,
            "totalTime": currentFormatted,
            "rawTotalMs": elapsedTime
        }
        let updatedLaps = [newLap].concat(laps)
        laps = updatedLaps
    }

    Timer {
        id: tickTimer
        interval: 100
        repeat: true
        running: root.running

        onTriggered: {
            root.elapsedTime += 100
        }
    }
}
