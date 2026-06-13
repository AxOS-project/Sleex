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

Item {
    id: playerController
    required property MprisPlayer player
    property bool lyricsButtonEnabled: Config.options.dashboard.enableLyrics
    property string artUrl: player?.trackArtUrl || ""
    property color artDominantColor: Appearance.m3colors.m3secondaryContainer
    property bool artLoaded: false
    property string currentTrackId: ""
    property string effectiveArtUrl: ""
    property bool trackChanged: false
    property int quantizerRequestId: 0
    property var lyricsLines: []
    property int currentLyricIndex: -1
    property bool lyricsViewVisible: false
    property bool fetchingLyrics: false
    property bool lyricsLoading: false
    property int lyricsFetchTimeout: 15000
    property int lyricsRequestId: 0
    property var currentLyricsRequest: null
    property var lyricsCache: ({})
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000
    property int visualizerSmoothing: 2
    property real stableLength: 0
    property string currentTrackIdForLength: ""
    property bool colorStable: true

    Behavior on artDominantColor {
        ColorAnimation { duration: 200; easing.type: Easing.InOutQuad }
    }

    function updateStableLength() {
        const newId = player?.trackId || (player?.trackTitle + "|" + player?.trackArtist)
        if (newId !== currentTrackIdForLength) {
            currentTrackIdForLength = newId
            stableLength = 0
        }
        const currentLen = player?.length ?? 0
        if (currentLen > stableLength) stableLength = currentLen
    }

    Connections {
        target: player
        function onLengthChanged()      { updateStableLength() }
        function onTrackIdChanged()     { updateStableLength() }
        function onTrackTitleChanged()  { updateStableLength(); resetAndFetchLyrics() }
        function onTrackArtistChanged() { resetAndFetchLyrics() }
    }

    onPlayerChanged: {
        updateTrackId()
        artLoaded = false
        colorStable = false
        ++quantizerRequestId
        effectiveArtUrl = player?.trackArtUrl || ""
        trackChanged = false
        updateStableLength()
        resetAndFetchLyrics()
    }

    function resetLyricsState() {
        if (currentLyricsRequest) {
            currentLyricsRequest.abort()
            currentLyricsRequest = null
        }
        ++lyricsRequestId
        lyricsLines = []
        currentLyricIndex = -1
        fetchingLyrics = false
        lyricsLoading = false
        if (lyricsTimeout.running) lyricsTimeout.stop()
    }

    function resetAndFetchLyrics() {
        if (currentLyricsRequest) {
            currentLyricsRequest.abort()
            currentLyricsRequest = null
        }
        ++lyricsRequestId
        lyricsLines = []
        currentLyricIndex = -1
        lyricsLoading = true
        fetchingLyrics = true
        if (lyricsTimeout.running) lyricsTimeout.stop()

            // Delete the cached entry for this track so we re‑fetch fresh
            // (this ensures we show "Loading lyrics…" and can pick up newly added synced lyrics)
            if (player) {
                const title  = player.trackTitle  || ""
                const artist = player.trackArtist || ""
                if (title && artist) {
                    const cacheKey = artist + "|" + title
                    delete lyricsCache[cacheKey]
                }
            }

            fetchLyrics()
    }

    // Fetch synced lyrics from LRCLIB, aborting previous requests and caching results.
    function fetchLyrics() {
        if (!player) return
            const title  = player.trackTitle  || ""
            const artist = player.trackArtist || ""
            if (!title || !artist) {
                lyricsLines = []; lyricsLoading = false; fetchingLyrics = false; return
            }
            const cacheKey = artist + "|" + title
            if (lyricsCache.hasOwnProperty(cacheKey)) {
                lyricsLines = lyricsCache[cacheKey]
                lyricsLoading = false; fetchingLyrics = false
                currentLyricIndex = -1
                if (lyricsViewVisible && lyricsLines.length > 0 && lyricsLines[0].timestamp >= 0)
                    updateCurrentLyricFromPosition()
                    return
            }
            const thisRequestId = ++lyricsRequestId
            if (lyricsTimeout.running) lyricsTimeout.restart(); else lyricsTimeout.start()

                const url = `https://lrclib.net/api/get?artist_name=${encodeURIComponent(artist)}&track_name=${encodeURIComponent(title)}`
                const http = new XMLHttpRequest()
                currentLyricsRequest = http
                http.open("GET", url)
                http.onreadystatechange = function() {
                    if (http.readyState !== XMLHttpRequest.DONE) return
                        if (thisRequestId !== lyricsRequestId) return
                            if (currentLyricsRequest === http) currentLyricsRequest = null

                                fetchingLyrics = false
                                lyricsTimeout.stop()

                                if (http.status === 200) {
                                    try {
                                        const data = JSON.parse(http.responseText)
                                        if (data.syncedLyrics) {
                                            parseSyncedLyrics(data.syncedLyrics)
                                        } else {
                                            // Treat non‑synced lyrics as no lyrics
                                            lyricsLines = []
                                        }
                                        // Cache the result (even if empty)
                                        lyricsCache[cacheKey] = lyricsLines
                                    } catch(e) {
                                        console.warn("LRCLIB parse error", e)
                                        lyricsLines = []
                                        lyricsCache[cacheKey] = []  // cache error as empty
                                    }
                                } else {
                                    lyricsLines = []
                                    lyricsCache[cacheKey] = []  // cache failed fetch as empty
                                }
                                lyricsLoading = false
                                currentLyricIndex = -1
                                if (lyricsViewVisible && lyricsLines.length > 0 && lyricsLines[0].timestamp >= 0)
                                    updateCurrentLyricFromPosition()
                }
                http.send()
    }

    function parseSyncedLyrics(syncedStr) {
        const lines = []
        const regex = /\[(\d{2}):(\d{2})\.(\d{2})\](.*)/g
        let match
        while ((match = regex.exec(syncedStr)) !== null) {
            const ts = parseInt(match[1])*60 + parseInt(match[2]) + parseInt(match[3])/100
            const txt = match[4].trim()
            if (txt) lines.push({ timestamp: ts, text: txt })
        }
        lines.sort((a,b) => a.timestamp - b.timestamp)
        lyricsLines = lines
    }

    function updateCurrentLyricFromPosition() {
        if (!player || lyricsLines.length === 0 || lyricsLines[0].timestamp < 0) return
            const pos = player.position
            let newIdx = -1
            for (let i = 0; i < lyricsLines.length; i++) {
                if (lyricsLines[i].timestamp <= pos) newIdx = i
                    else break
            }
            if (newIdx !== currentLyricIndex) currentLyricIndex = newIdx
    }

    Timer {
        interval: 100
        running: lyricsViewVisible && lyricsLines.length > 0
        && lyricsLines[0].timestamp >= 0 && player?.isPlaying === true
        repeat: true
        onTriggered: updateCurrentLyricFromPosition()
    }

    Timer {
        id: lyricsTimeout
        interval: lyricsFetchTimeout
        repeat: false
        onTriggered: {
            if (lyricsLoading && currentLyricsRequest) {
                currentLyricsRequest.abort()
                currentLyricsRequest = null
            }
            if (lyricsLoading) {
                lyricsLoading  = false
                fetchingLyrics = false
                lyricsLines    = []
            }
        }
    }

    onLyricsViewVisibleChanged: {
        if (lyricsViewVisible && lyricsLines.length > 0 && lyricsLines[0].timestamp >= 0)
            updateCurrentLyricFromPosition()
    }

    implicitWidth:  widgetWidth
    implicitHeight: widgetHeight

    component TrackChangeButton: RippleButton {
        implicitWidth: 24; implicitHeight: 24
        property var btnIcon; property string btnAction
        colBackground:      ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
        colBackgroundHover: blendedColors.colSecondaryContainerHover
        colRipple:          blendedColors.colSecondaryContainerActive
        contentItem: MaterialSymbol {
            iconSize: Appearance.font.pixelSize.huge; fill: 1
            horizontalAlignment: Text.AlignHCenter
            color: blendedColors.colOnSecondaryContainer; text: btnIcon
            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
        onClicked: {
            if (btnAction === "previous") playerController.player?.previous()
                else if (btnAction === "next") playerController.player?.next()
                    if (playerController.player) {
                        resumeTimer.wasPlaying = playerController.player.isPlaying
                        resumeTimer.restart()
                    }
        }
        // If the player was playing before the track change, resume playback after a short delay.
        Timer {
            id: resumeTimer
            interval: 150
            property bool wasPlaying: false
            onTriggered: {
                if (wasPlaying && playerController.player && !playerController.player.isPlaying)
                    playerController.player.play()
            }
        }
    }

    Timer {
        running: playerController.player?.playbackState == MprisPlaybackState.Playing
        interval: 100; repeat: true
        onTriggered: playerController.player.positionChanged()
    }

    function updateTrackId() {
        const title  = playerController.player?.trackTitle  || ""
        const artist = playerController.player?.trackArtist || ""
        const newId = title + "|" + artist
        if (newId !== currentTrackId) { trackChanged = true; currentTrackId = newId }
    }

    onArtUrlChanged: {
        if (!artUrl || artUrl.length === 0) return
            updateTrackId()
            if (effectiveArtUrl === "" || trackChanged) {
                artLoaded = false
                colorStable = false
                trackChanged = false
                ++quantizerRequestId
                effectiveArtUrl = artUrl
            }
    }

    // Extract the dominant colour from the album art, ignoring results from old requests.
    ColorQuantizer {
        id: colorQuantizer
        source: playerController.effectiveArtUrl
        depth: 0
        rescaleSize: 1
        property int capturedRequestId: 0
        onSourceChanged: capturedRequestId = playerController.quantizerRequestId
        onColorsChanged: {
            if (capturedRequestId !== playerController.quantizerRequestId) return
                if (!playerController.effectiveArtUrl) return
                    if (playerController.colorStable) return
                        if (colors && colors.length > 0) {
                            const newColor = colors[0]
                            if (newColor.toString() !== playerController.artDominantColor.toString())
                                playerController.artDominantColor = newColor
                                playerController.colorStable = true
                        }
        }
    }

    property bool backgroundIsDark: artDominantColor.hslLightness < 0.5

    property QtObject blendedColors: QtObject {
        property color colLayer0:                  ColorUtils.mix(Appearance.colors.colLayer0,                                    artDominantColor, (backgroundIsDark && Appearance.m3colors.darkmode) ? 0.6 : 0.5)
        property color colLayer1:                  ColorUtils.mix(Appearance.colors.colLayer1,                                    artDominantColor, 0.5)
        property color colOnLayer0:                ColorUtils.mix(Appearance.colors.colOnLayer0,                                  artDominantColor, 0.5)
        property color colOnLayer1:                ColorUtils.mix(Appearance.colors.colOnLayer1,                                  artDominantColor, 0.5)
        property color colSubtext:                 ColorUtils.mix(Appearance.colors.colOnLayer1,                                  artDominantColor, 0.5)
        property color colPrimary:                 ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.colors.colPrimary,          artDominantColor), artDominantColor, 0.5)
        property color colPrimaryHover:            ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.colors.colPrimaryHover,     artDominantColor), artDominantColor, 0.3)
        property color colPrimaryActive:           ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.colors.colPrimaryActive,    artDominantColor), artDominantColor, 0.3)
        property color colSecondaryContainer:      ColorUtils.mix(Appearance.m3colors.m3secondaryContainer,                       artDominantColor, 0.15)
        property color colSecondaryContainerHover: ColorUtils.mix(Appearance.colors.colSecondaryContainerHover,                   artDominantColor, 0.3)
        property color colSecondaryContainerActive:ColorUtils.mix(Appearance.colors.colSecondaryContainerActive,                  artDominantColor, 0.5)
        property color colOnPrimary:               ColorUtils.mix(ColorUtils.adaptToAccent(Appearance.m3colors.m3onPrimary,       artDominantColor), artDominantColor, 0.5)
        property color colOnSecondaryContainer:    ColorUtils.mix(Appearance.m3colors.m3onSecondaryContainer,                     artDominantColor, 0.5)
    }

    Rectangle {
        id: sharedBackground
        anchors.fill: parent
        color: blendedColors.colLayer0
        radius: Appearance.rounding.normal
        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } }
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle { width: sharedBackground.width; height: sharedBackground.height; radius: sharedBackground.radius }
        }

        Image {
            id: blurredArt
            anchors.fill: parent
            source: playerController.effectiveArtUrl || ""
            cache: true; asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: parent.width * 2
            sourceSize.height: parent.height * 2
            antialiasing: true
            opacity: status === Image.Ready ? 1 : 0.3
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            layer.enabled: true
            layer.effect: MultiEffect {
                source: blurredArt; saturation: 0.2; blurEnabled: true; blurMax: 100; blur: 1
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
    }

    RowLayout {
        id: controlsLayout
        anchors.fill: parent
        anchors.margins: root.contentPadding
        spacing: 15
        opacity: lyricsViewVisible ? 0 : 1
        enabled: !lyricsViewVisible
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            id: artBackground
            Layout.fillHeight: true; implicitWidth: height
            radius: root.artRounding
            color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle { width: artBackground.width; height: artBackground.height; radius: artBackground.radius }
            }

            Image {
                id: mediaArt
                property int size: parent.height
                anchors.fill: parent; width: size; height: size
                sourceSize.width: size * 4
                sourceSize.height: size * 4
                fillMode: Image.PreserveAspectCrop
                smooth: true; mipmap: true; antialiasing: true; asynchronous: true; cache: true
                source: playerController.effectiveArtUrl
                opacity: status === Image.Ready ? 1 : 0.5
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                onStatusChanged: {
                    if (status === Image.Ready) playerController.artLoaded = true
                        else if (status === Image.Error) playerController.artLoaded = false
                }
            }
        }

        ColumnLayout {
            Layout.fillHeight: true; spacing: 2

            StyledText {
                id: trackTitle; Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.large; color: blendedColors.colOnLayer0
                elide: Text.ElideRight
                text: StringUtils.cleanMusicTitle(playerController.player?.trackTitle) || "Untitled"
                onTextChanged: playerController.updateTrackId()
            }
            StyledText {
                id: trackArtist; Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.smaller; color: blendedColors.colSubtext
                elide: Text.ElideRight
                text: playerController.player?.trackArtist
                onTextChanged: playerController.updateTrackId()
            }
            Item { Layout.fillHeight: true }

            Item {
                Layout.fillWidth: true
                implicitHeight: trackTime.implicitHeight + sliderRow.implicitHeight

                StyledText {
                    id: trackTime
                    anchors.bottom: sliderRow.top; anchors.bottomMargin: 5; anchors.left: parent.left
                    font.pixelSize: Appearance.font.pixelSize.small; color: blendedColors.colSubtext
                    text: {
                        const pos = playerController.player?.position ?? 0
                        const len = playerController.stableLength
                        return `${StringUtils.friendlyTimeForSeconds(pos)} / ${len > 0 ? StringUtils.friendlyTimeForSeconds(len) : "--:--"}`
                    }
                }
                RowLayout {
                    id: sliderRow; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                    TrackChangeButton { btnIcon: "skip_previous"; btnAction: "previous" }
                    Item {
                        id: progressBarContainer; Layout.fillWidth: true; implicitHeight: 24
                        StyledProgressBar {
                            id: progressBar; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            height: 4; highlightColor: blendedColors.colPrimary; trackColor: blendedColors.colSecondaryContainer
                            value: (playerController.stableLength > 0) ? (playerController.player?.position ?? 0) / playerController.stableLength : 0
                            sperm: playerController.player?.isPlaying; antialiasing: true
                            Behavior on value { NumberAnimation { duration: 100; easing.type: Easing.Linear } }
                        }
                        MouseArea {
                            id: seekMouseArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            property bool dragging: false
                            function seekTo(mouseX) {
                                if (playerController.stableLength <= 0) return
                                    const newPos = Math.max(0, Math.min(1, mouseX / width)) * playerController.stableLength
                                    if (!playerController.player) return
                                        if (typeof playerController.player.setPosition === "function") playerController.player.setPosition(newPos)
                                            else playerController.player.position = newPos
                            }
                            onPressed: (mouse) => { dragging = true; seekTo(mouse.x) }
                            onPositionChanged: (mouse) => { if (dragging) seekTo(mouse.x) }
                            onReleased: dragging = false
                        }
                    }
                    TrackChangeButton { btnIcon: "skip_next"; btnAction: "next" }
                }

                RippleButton {
                    id: playPauseButton; anchors.right: parent.right; anchors.bottom: sliderRow.top; anchors.bottomMargin: 5
                    property real size: 44; implicitWidth: size; implicitHeight: size
                    onClicked: playerController.player.togglePlaying()
                    buttonRadius: playerController.player?.isPlaying ? Appearance?.rounding.normal : size / 2
                    colBackground:      playerController.player?.isPlaying ? blendedColors.colPrimary : blendedColors.colSecondaryContainer
                    colBackgroundHover: playerController.player?.isPlaying ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover
                    colRipple:          playerController.player?.isPlaying ? blendedColors.colPrimaryActive : blendedColors.colSecondaryContainerActive
                    contentItem: MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.huge; fill: 1; horizontalAlignment: Text.AlignHCenter
                        color: playerController.player?.isPlaying ? blendedColors.colOnPrimary : blendedColors.colOnSecondaryContainer
                        text: playerController.player?.isPlaying ? "pause" : "play_arrow"
                        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                    }
                }
            }
        }
    }

    RippleButton {
        id: lyricsButton
        anchors { top: parent.top; right: parent.right; topMargin: 12; rightMargin: 16 }
        visible: lyricsButtonEnabled && !lyricsViewVisible
        opacity: visible ? 1 : 0
        enabled: visible
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        implicitWidth: 32; implicitHeight: 32; buttonRadius: 16
        colBackground: ColorUtils.transparentize(blendedColors.colSecondaryContainer, 0.7)
        colBackgroundHover: blendedColors.colSecondaryContainerHover
        colRipple: blendedColors.colSecondaryContainerActive
        contentItem: MaterialSymbol {
            iconSize: 20; fill: 1; horizontalAlignment: Text.AlignHCenter
            color: blendedColors.colOnSecondaryContainer; text: "lyrics"
        }
        onClicked: {
            lyricsViewVisible = !lyricsViewVisible
            if (lyricsViewVisible && lyricsLines.length === 0 && !lyricsLoading && !fetchingLyrics)
                resetAndFetchLyrics()
        }

        ToolTip {
            visible: lyricsButton.hovered && lyricsButton.enabled
            text: "Lyrics provided by LRCLIB"
            delay: 1000
        }
    }

    Item {
        id: lyricsOverlay
        anchors.fill: parent
        opacity: lyricsViewVisible ? 1 : 0
        enabled: lyricsViewVisible
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        z: 10

        RippleButton {
            anchors { top: parent.top; right: parent.right; margins: 8 }
            implicitWidth: 32; implicitHeight: 32; buttonRadius: 16
            colBackground: ColorUtils.transparentize(blendedColors.colSecondaryContainer, 0.8)
            colBackgroundHover: blendedColors.colSecondaryContainerHover
            contentItem: MaterialSymbol { iconSize: 20; fill: 1; color: blendedColors.colOnSecondaryContainer; text: "close" }
            onClicked: lyricsViewVisible = false
        }

        Column {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 12 }
            spacing: 4
            visible: lyricsLines.length > 0 && lyricsLines[0].timestamp >= 0
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Appearance.font.pixelSize.large
                color: blendedColors.colSubtext
                text: player?.trackTitle || ""
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.transparentize(blendedColors.colSubtext, 0.7)
                text: player?.trackArtist || ""
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Item {
            id: lyricContainer
            anchors.centerIn: parent
            width: parent.width - 64
            height: Math.max(oldLineText.implicitHeight, newLineText.implicitHeight)

            property string currentLine: {
                if (lyricsLoading) return "Loading lyrics..."
                    if (lyricsLines.length === 0) return "No synced lyrics found"
                        if (lyricsLines[0].timestamp >= 0) {
                            return (currentLyricIndex >= 0 && currentLyricIndex < lyricsLines.length)
                            ? lyricsLines[currentLyricIndex].text : lyricsLines[0].text
                        }
                        return lyricsLines[0].text  // fallback, should not be reached
            }
            property string _lastLine: ""

            Text {
                id: oldLineText
                anchors.centerIn: parent
                width: parent.width
                font.pixelSize: (text === "Loading lyrics..." || text === "No synced lyrics found")
                ? Appearance.font.pixelSize.huge : Appearance.font.pixelSize.large * 1.1
                font.weight: Font.Bold
                color: ColorUtils.mix(blendedColors.colOnPrimary, "#FFFFFF", 0.3)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0
                y: 0
            }

            Text {
                id: newLineText
                anchors.centerIn: parent
                width: parent.width
                font.pixelSize: (text === "Loading lyrics..." || text === "No synced lyrics found")
                ? Appearance.font.pixelSize.huge : Appearance.font.pixelSize.large * 1.1
                font.weight: Font.Bold
                color: ColorUtils.mix(blendedColors.colOnPrimary, "#FFFFFF", 0.3)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 1
                y: 0
                scale: 1.0
            }

            Binding {
                target: newLineText
                property: "text"
                value: lyricContainer.currentLine
            }

            // Cross‑fade the old lyric line upward and the new one from below with a slight scale‑up.
            SequentialAnimation {
                id: crossFadeAnim

                ParallelAnimation {
                    NumberAnimation {
                        target: oldLineText
                        property: "opacity"
                        to: 0
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: oldLineText
                        property: "y"
                        to: -20
                        duration: 200
                        easing.type: Easing.OutElastic
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: newLineText
                        property: "opacity"
                        to: 1
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: newLineText
                        property: "y"
                        from: 20
                        to: 0
                        duration: 200
                        easing.type: Easing.OutElastic
                    }
                    NumberAnimation {
                        target: newLineText
                        property: "scale"
                        from: 0.92
                        to: 1.0
                        duration: 200
                        easing.type: Easing.OutElastic
                    }
                }
            }

            onCurrentLineChanged: {
                if (_lastLine === "") {
                    _lastLine = currentLine
                    newLineText.opacity = 1
                    newLineText.y = 0
                    newLineText.scale = 1.0
                    return
                }
                if (currentLine === _lastLine) return

                    if (crossFadeAnim.running) {
                        crossFadeAnim.stop()
                        oldLineText.opacity = 0
                        oldLineText.y = 0
                        newLineText.opacity = 1
                        newLineText.y = 0
                        newLineText.scale = 1.0
                        _lastLine = currentLine
                        return
                    }

                    oldLineText.text = _lastLine
                    oldLineText.opacity = 1
                    oldLineText.y = 0

                    newLineText.y = 20
                    newLineText.opacity = 0
                    newLineText.scale = 0.92

                    _lastLine = currentLine
                    crossFadeAnim.start()
            }
        }
    }
}
