pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool running: false
    property int defaultDuration: 25 * 60
    property int totalDuration: defaultDuration
    property int timeRemaining: defaultDuration

    readonly property real progress: totalDuration > 0 ? (1.0 - (timeRemaining / totalDuration)) : 0
    readonly property string formattedTime: formatTime(timeRemaining)

    signal timerFinished()

    function formatTime(seconds) {
        let m = Math.floor(seconds / 60)
        let s = seconds % 60
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
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
        timeRemaining = totalDuration
    }

    function addMinutes(mins) {
        let delta = mins * 60
        let newTime = Math.max(60, timeRemaining + delta)

        if (!running) {
            totalDuration = newTime
            timeRemaining = newTime
        } else {
            timeRemaining = newTime
            if (delta > 0) {
                totalDuration += delta
            } else {
                totalDuration = Math.max(timeRemaining, totalDuration + delta)
            }
        }
    }

    function setCustomMinutes(mins) {
        running = false
        totalDuration = Math.max(60, mins * 60)
        timeRemaining = totalDuration
    }

    function sendNotification() {
        Quickshell.execDetached(["notify-send", "Timer Finished!", "Your timer has completed.", "-a", "Sleex"])
        Audio.playSound("assets/sounds/battery/pomodoro_end.mp3")
    }

    Timer {
        id: countTimer
        interval: 1000
        repeat: true
        running: root.running

        onTriggered: {
            if (root.timeRemaining > 1) {
                root.timeRemaining--
            } else {
                root.timeRemaining = 0
                root.running = false
                root.sendNotification()
                root.timerFinished()
            }
        }
    }
}
