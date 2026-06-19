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

    property bool isLockscreen: false

    readonly property bool lyricsButtonEnabled:
    typeof Config !== "undefined"
    && Config?.options?.dashboard?.enableLyrics === true

    readonly property real contentPadding: 12
    readonly property real artRounding: 8
    readonly property real popupRounding: 8
    readonly property real defaultRounding: Appearance?.rounding?.normal ?? 8
    implicitWidth: 400
    implicitHeight: 120

    // ---- artwork cross-fade ----
    property string artUrl: player?.trackArtUrl || ""
    property string effectiveArtUrl: ""
    property string lastLoadedArtUrl: ""
    property bool artShowingA: true
    property bool crossFadeActive: false
    property string artSourceA: ""
    property string artSourceB: ""
    property bool initialArtLoaded: false

    onEffectiveArtUrlChanged: {
        if (effectiveArtUrl) {
            colorStable = false
            ++quantizerRequestId
        }
    }

    Timer {
        id: crossFadeTimer
        interval: 50
        repeat: true
        property string waitForUrl: ""
        property string imageToLoad: ""
        property int attempts: 0
        onTriggered: {
            if (imageToLoad === "A" && artImage1.status === Image.Ready) {
                attempts = 0; stop(); doCrossFade()
            } else if (imageToLoad === "B" && artImage2.status === Image.Ready) {
                attempts = 0; stop(); doCrossFade()
            } else if (++attempts > 20) {
                attempts = 0; stop(); doCrossFade()
            }
        }
    }

    Timer {
        id: cleanupTimer
        interval: 600
        repeat: false
        property string cleanupImage: ""
        onTriggered: {
            if (cleanupImage === "A") artSourceA = ""
                else if (cleanupImage === "B") artSourceB = ""
                    crossFadeActive = false
                    lastLoadedArtUrl = playerController.artUrl
                    if (effectiveArtUrl !== lastLoadedArtUrl)
                        effectiveArtUrl = lastLoadedArtUrl
        }
    }

    function startArtCrossFade(newUrl) {
        crossFadeActive = true
        crossFadeTimer.attempts = 0
        if (artShowingA) {
            artSourceB = newUrl
            crossFadeTimer.imageToLoad = "B"
        } else {
            artSourceA = newUrl
            crossFadeTimer.imageToLoad = "A"
        }
        crossFadeTimer.waitForUrl = newUrl
        crossFadeTimer.start()
    }

    function doCrossFade() {
        if (artShowingA) {
            artImage1.opacity = 0.0; artImage2.opacity = 1.0
            blurredArt1.opacity = 0.0; blurredArt2.opacity = 1.0
        } else {
            artImage1.opacity = 1.0; artImage2.opacity = 0.0
            blurredArt1.opacity = 1.0; blurredArt2.opacity = 0.0
        }
        artShowingA = !artShowingA
        cleanupTimer.cleanupImage = artShowingA ? "B" : "A"
        cleanupTimer.start()
    }

    function loadInitialArt(url) {
        if (!url || url.length === 0) return
            artSourceA = url
            artImage1.opacity = 1.0; blurredArt1.opacity = 1.0
            artSourceB = ""
            artImage2.opacity = 0.0; blurredArt2.opacity = 0.0
            artShowingA = true
            lastLoadedArtUrl = url
            if (effectiveArtUrl !== url) effectiveArtUrl = url
                initialArtLoaded = true
    }

    function resetCrossFadeState() {
        crossFadeTimer.stop()
        cleanupTimer.stop()
        if (artShowingA) {
            artImage1.opacity = 1.0; blurredArt1.opacity = 1.0
            artImage2.opacity = 0.0; blurredArt2.opacity = 0.0
            artSourceB = ""
        } else {
            artImage2.opacity = 1.0; blurredArt2.opacity = 1.0
            artImage1.opacity = 0.0; blurredArt1.opacity = 0.0
            artSourceA = ""
        }
        crossFadeActive = false
    }

    function forceCrossFade(newUrl) {
        if (newUrl === lastLoadedArtUrl && !crossFadeActive) return
            resetCrossFadeState()
            effectiveArtUrl = newUrl
            startArtCrossFade(newUrl)
    }

    property string currentTrackIdForArt: ""

    onArtUrlChanged: {
        if (!artUrl || artUrl.length === 0) return
            var newTrackId = player?.trackId || (player?.trackTitle + "|" + player?.trackArtist)
            if (newTrackId !== currentTrackIdForArt) {
                currentTrackIdForArt = newTrackId
                if (!initialArtLoaded) {
                    loadInitialArt(artUrl)
                } else {
                    forceCrossFade(artUrl)
                }
            }
    }

    onPlayerChanged: {
        currentTrackIdForArt = ""
        initialArtLoaded = false
        crossFadeActive = false
        lastLoadedArtUrl = ""
        artSourceA = ""
        artSourceB = ""
        effectiveArtUrl = ""
        colorStable = false
        ++quantizerRequestId
        updateStableLength()
        resetAndFetchLyrics()
    }

    // ---- color extraction ----
    property color artDominantColor: Appearance.m3colors.m3secondaryContainer
    property int quantizerRequestId: 0
    property bool colorStable: true

    Behavior on artDominantColor {
        ColorAnimation { duration: 400; easing.type: Easing.InOutCubic }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: playerController.effectiveArtUrl
        depth: 0
        rescaleSize: 1
        property int capturedRequestId: 0
        onSourceChanged: capturedRequestId = playerController.quantizerRequestId
        onColorsChanged: {
            if (capturedRequestId !== playerController.quantizerRequestId) return
                if (playerController.colorStable) return
                    if (colors && colors.length > 0) {
                        artDominantColor = colors[0]
                        colorStable = true
                    }
        }
    }

    property bool backgroundIsDark: artDominantColor.hslLightness < 0.5

    // Blend UI colors with art dominant color
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

    // ---- lyrics ----
    property var lyricsLines: []
    property int currentLyricIndex: -1
    property bool lyricsViewVisible: false
    property bool fetchingLyrics: false
    property bool lyricsLoading: false
    property int lyricsRequestId: 0
    property var currentLyricsRequest: null
    property var lyricsCache: ({})
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000
    property int visualizerSmoothing: 2
    property real stableLength: 0
    property string currentTrackIdForLength: ""

    Component.onDestruction: {
        if (currentLyricsRequest) currentLyricsRequest.abort()
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

    function resetLyricsState() {
        if (currentLyricsRequest) currentLyricsRequest.abort()
            ++lyricsRequestId
            lyricsLines = []
            currentLyricIndex = -1
            fetchingLyrics = false
            lyricsLoading = false
    }

    function resetAndFetchLyrics() {
        if (!lyricsButtonEnabled) return
            if (currentLyricsRequest) currentLyricsRequest.abort()
                ++lyricsRequestId
                lyricsLines = []
                currentLyricIndex = -1
                lyricsLoading = true
                fetchingLyrics = true
                fetchLyrics()
    }

    function fetchLyrics() {
        if (!lyricsButtonEnabled || !player) return
            const title = player.trackTitle || ""
            const artist = player.trackArtist || ""
            if (!title || !artist) {
                lyricsLines = []; lyricsLoading = false; fetchingLyrics = false; return
            }
            const cacheKey = artist + "|" + title
            if (lyricsCache.hasOwnProperty(cacheKey) && lyricsCache[cacheKey].length > 0) {
                lyricsLines = lyricsCache[cacheKey]
                lyricsLoading = false; fetchingLyrics = false
                if (lyricsViewVisible && lyricsLines.length && lyricsLines[0].timestamp >= 0)
                    updateCurrentLyricFromPosition()
                    return
            }
            const thisRequestId = ++lyricsRequestId
            const url = `https://lrclib.net/api/get?artist_name=${encodeURIComponent(artist)}&track_name=${encodeURIComponent(title)}`
            const http = new XMLHttpRequest()
            currentLyricsRequest = http
            http.open("GET", url)
            http.onreadystatechange = function() {
                if (http.readyState !== XMLHttpRequest.DONE) return
                    if (thisRequestId !== lyricsRequestId) return
                        if (currentLyricsRequest === http) currentLyricsRequest = null
                            fetchingLyrics = false
                            if (http.status === 200) {
                                try {
                                    const data = JSON.parse(http.responseText)
                                    if (data.syncedLyrics) parseSyncedLyrics(data.syncedLyrics)
                                        else lyricsLines = []
                                            if (lyricsLines.length) lyricsCache[cacheKey] = lyricsLines
                                } catch(e) { lyricsLines = [] }
                            } else { lyricsLines = [] }
                            lyricsLoading = false
                            if (lyricsViewVisible && lyricsLines.length && lyricsLines[0].timestamp >= 0)
                                updateCurrentLyricFromPosition()
            }
            http.onerror = http.ontimeout = function() {
                if (thisRequestId !== lyricsRequestId) return
                    if (currentLyricsRequest === http) currentLyricsRequest = null
                        fetchingLyrics = false
                        lyricsLoading = false
                        lyricsLines = []
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
        running: lyricsViewVisible
        && lyricsLines.length > 0 && lyricsLines[0].timestamp >= 0
        && player?.isPlaying === true
        repeat: true
        onTriggered: updateCurrentLyricFromPosition()
    }

    onLyricsViewVisibleChanged: {
        if (lyricsViewVisible && lyricsLines.length
            && lyricsLines[0].timestamp >= 0)
            updateCurrentLyricFromPosition()
    }

    // ---- control buttons with single resume timer ----
    property bool pendingResumePlay: false

    Timer {
        id: resumeTimer
        interval: 150
        onTriggered: {
            if (pendingResumePlay && player && !player.isPlaying) player.play()
                pendingResumePlay = false
        }
    }

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
            if (btnAction === "previous") player?.previous()
                else if (btnAction === "next") player?.next()
                    if (player) {
                        pendingResumePlay = player.isPlaying
                        resumeTimer.restart()
                    }
        }
    }

    Timer {
        running: player?.playbackState == MprisPlaybackState.Playing
        interval: 100; repeat: true
        onTriggered: player.positionChanged()
    }

    // ---- main UI ----
    Item {
        id: normalPlayerContainer
        anchors.fill: parent
        visible: true

        Rectangle {
            id: sharedBackground
            anchors.fill: parent
            color: blendedColors.colLayer0
            radius: playerController.defaultRounding
            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: sharedBackground.width; height: sharedBackground.height
                    radius: sharedBackground.radius
                }
            }

            Image {
                id: blurredArt1
                anchors.fill: parent
                source: playerController.artSourceA
                cache: true; asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 512; sourceSize.height: 512
                antialiasing: true
                opacity: artShowingA ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }
                layer.enabled: true
                layer.effect: MultiEffect {
                    source: blurredArt1; saturation: 0.2
                    blurEnabled: true; blurMax: 100; blur: 1
                }
            }

            Image {
                id: blurredArt2
                anchors.fill: parent
                source: playerController.artSourceB
                cache: true; asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 512; sourceSize.height: 512
                antialiasing: true
                opacity: artShowingA ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }
                layer.enabled: true
                layer.effect: MultiEffect {
                    source: blurredArt2; saturation: 0.2
                    blurEnabled: true; blurMax: 100; blur: 1
                }
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(blendedColors.colLayer0, 0.25)
                radius: playerController.popupRounding
            }

            WaveVisualizer {
                id: visualizerCanvas
                anchors.fill: parent
                live: player?.isPlaying
                points: playerController.visualizerPoints
                maxVisualizerValue: playerController.maxVisualizerValue
                smoothing: playerController.visualizerSmoothing
                color: blendedColors.colPrimary
            }
        }

        RowLayout {
            id: controlsLayout
            anchors.fill: parent
            anchors.margins: playerController.contentPadding
            spacing: 15
            opacity: lyricsViewVisible ? 0 : 1
            enabled: !lyricsViewVisible
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Rectangle {
                id: artBackground
                Layout.fillHeight: true; implicitWidth: height
                radius: playerController.artRounding
                color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artBackground.width; height: artBackground.height
                        radius: artBackground.radius
                    }
                }

                Image {
                    id: artImage1
                    anchors.fill: parent
                    width: parent.height; height: parent.height
                    sourceSize.width: 512; sourceSize.height: 512
                    fillMode: Image.PreserveAspectCrop
                    smooth: false; mipmap: true; antialiasing: true
                    asynchronous: true; cache: true
                    source: playerController.artSourceA
                    opacity: 1.0
                    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }
                }

                Image {
                    id: artImage2
                    anchors.fill: parent
                    width: parent.height; height: parent.height
                    sourceSize.width: 512; sourceSize.height: 512
                    fillMode: Image.PreserveAspectCrop
                    smooth: false; mipmap: true; antialiasing: true
                    asynchronous: true; cache: true
                    source: playerController.artSourceB
                    opacity: 0.0
                    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }
                }
            }

            ColumnLayout {
                Layout.fillHeight: true; spacing: 2

                StyledText {
                    id: trackTitle; Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: blendedColors.colOnLayer0
                    elide: Text.ElideRight
                    text: StringUtils.cleanMusicTitle(player?.trackTitle) || "Untitled"
                }
                StyledText {
                    id: trackArtist; Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: player?.trackArtist
                }
                Item { Layout.fillHeight: true }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: trackTime.implicitHeight + sliderRow.implicitHeight

                    StyledText {
                        id: trackTime
                        anchors.bottom: sliderRow.top; anchors.bottomMargin: 5
                        anchors.left: parent.left
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: blendedColors.colSubtext
                        text: {
                            const len = playerController.stableLength
                            if (len <= 0) return "0:00 / --:--"
                                const pos = seekMouseArea.dragging
                                ? seekMouseArea.dragFraction * len : (player?.position ?? 0)
                                return `${StringUtils.friendlyTimeForSeconds(pos)} / ${StringUtils.friendlyTimeForSeconds(len)}`
                        }
                    }
                    RowLayout {
                        id: sliderRow; anchors.bottom: parent.bottom
                        anchors.left: parent.left; anchors.right: parent.right
                        TrackChangeButton { btnIcon: "skip_previous"; btnAction: "previous" }
                        Item {
                            id: progressBarContainer; Layout.fillWidth: true; implicitHeight: 24
                            StyledProgressBar {
                                id: progressBar
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 4
                                highlightColor: blendedColors.colPrimary
                                trackColor: blendedColors.colSecondaryContainer
                                value: seekMouseArea.dragging
                                ? seekMouseArea.dragFraction
                                : (playerController.stableLength > 0 ? (player?.position ?? 0) / playerController.stableLength : 0)
                                sperm: player?.isPlaying
                                antialiasing: true
                                Behavior on value {
                                    enabled: !seekMouseArea.dragging
                                    NumberAnimation { duration: 100; easing.type: Easing.Linear }
                                }
                            }
                            MouseArea {
                                id: seekMouseArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                property bool dragging: false
                                property real dragFraction: 0
                                Timer {
                                    id: dragReleaseTimer
                                    interval: 60; repeat: false
                                    onTriggered: seekMouseArea.dragging = false
                                }
                                function seekTo(mouseX: real) {
                                    if (playerController.stableLength <= 0) return
                                        dragFraction = Math.max(0, Math.min(1, mouseX / width))
                                }
                                onPressed: (mouse) => {
                                    if (dragReleaseTimer.running) dragReleaseTimer.stop()
                                        dragging = true; seekTo(mouse.x)
                                }
                                onPositionChanged: (mouse) => {
                                    if (dragging) seekTo(mouse.x)
                                }
                                onReleased: {
                                    const newPos = dragFraction * playerController.stableLength
                                    if (player) {
                                        if (typeof player.setPosition === "function")
                                            player.setPosition(newPos)
                                            else
                                                player.position = newPos
                                    }
                                    dragReleaseTimer.start()
                                }
                            }
                        }
                        TrackChangeButton { btnIcon: "skip_next"; btnAction: "next" }
                    }

                    RippleButton {
                        id: playPauseButton
                        anchors.right: parent.right; anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        property real size: 44; implicitWidth: size; implicitHeight: size
                        onClicked: player.togglePlaying()
                        buttonRadius: player?.isPlaying
                        ? playerController.defaultRounding : size / 2
                        colBackground:      player?.isPlaying
                        ? blendedColors.colPrimary : blendedColors.colSecondaryContainer
                        colBackgroundHover: player?.isPlaying
                        ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover
                        colRipple:          player?.isPlaying
                        ? blendedColors.colPrimaryActive : blendedColors.colSecondaryContainerActive
                        contentItem: MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.huge; fill: 1
                            horizontalAlignment: Text.AlignHCenter
                            color: player?.isPlaying
                            ? blendedColors.colOnPrimary : blendedColors.colOnSecondaryContainer
                            text: player?.isPlaying ? "pause" : "play_arrow"
                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }
                    }
                }
            }
        }

        RippleButton {
            id: lyricsButton
            anchors {
                top: parent.top; right: parent.right
                topMargin: 12; rightMargin: 16
            }
            visible: lyricsButtonEnabled && !lyricsViewVisible
            opacity: visible ? 1 : 0
            enabled: visible
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            implicitWidth: 32; implicitHeight: 32
            buttonRadius: playerController.popupRounding
            colBackground: ColorUtils.transparentize(blendedColors.colSecondaryContainer, 0.7)
            colBackgroundHover: blendedColors.colSecondaryContainerHover
            colRipple: blendedColors.colSecondaryContainerActive
            contentItem: MaterialSymbol {
                iconSize: 20; fill: 1; horizontalAlignment: Text.AlignHCenter
                color: blendedColors.colOnSecondaryContainer; text: "lyrics"
            }
            onClicked: {
                lyricsViewVisible = !lyricsViewVisible
                if (lyricsViewVisible && lyricsLines.length === 0
                    && !lyricsLoading && !fetchingLyrics)
                    resetAndFetchLyrics()
            }
        }

        // ---- lyrics overlay ----
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
                implicitWidth: 32; implicitHeight: 32
                buttonRadius: playerController.popupRounding
                colBackground: ColorUtils.transparentize(blendedColors.colSecondaryContainer, 0.8)
                colBackgroundHover: blendedColors.colSecondaryContainerHover
                contentItem: MaterialSymbol {
                    iconSize: 20; fill: 1
                    color: blendedColors.colOnSecondaryContainer; text: "close"
                }
                onClicked: lyricsViewVisible = false
            }

            Column {
                anchors {
                    top: parent.top; horizontalCenter: parent.horizontalCenter
                    topMargin: 12
                }
                spacing: 4
                visible: lyricsLines.length > 0 && lyricsLines[0].timestamp >= 0
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: Appearance.font.pixelSize.large * 0.9
                    color: blendedColors.colSubtext
                    text: player?.trackTitle || ""
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: Appearance.font.pixelSize.smaller * 0.9
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
                            return lyricsLines[0].text
                }
                property string _lastLine: ""

                Text {
                    id: oldLineText
                    anchors.centerIn: parent
                    width: parent.width
                    font.pixelSize: (text === "Loading lyrics..." || text === "No synced lyrics found")
                    ? Appearance.font.pixelSize.huge
                    : Appearance.font.pixelSize.large * 1.1
                    font.weight: Font.Bold
                    color: ColorUtils.mix(blendedColors.colOnPrimary, "#FFFFFF", 0.3)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    opacity: 0; y: 0
                }

                Text {
                    id: newLineText
                    anchors.centerIn: parent
                    width: parent.width
                    font.pixelSize: (text === "Loading lyrics..." || text === "No synced lyrics found")
                    ? Appearance.font.pixelSize.huge
                    : Appearance.font.pixelSize.large * 1.1
                    font.weight: Font.Bold
                    color: ColorUtils.mix(blendedColors.colOnPrimary, "#FFFFFF", 0.3)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    opacity: 1; y: 0; scale: 1.0
                }

                Binding {
                    target: newLineText
                    property: "text"
                    value: lyricContainer.currentLine
                }

                SequentialAnimation {
                    id: crossFadeAnim
                    ParallelAnimation {
                        NumberAnimation {
                            target: oldLineText; property: "opacity"; to: 0; duration: 200
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: oldLineText; property: "y"; to: -15; duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: newLineText; property: "opacity"; to: 1; duration: 200
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: newLineText; property: "y"; from: 15; to: 0; duration: 200
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: newLineText; property: "scale"; from: 0.95; to: 1.0; duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                onCurrentLineChanged: {
                    if (_lastLine === "") {
                        _lastLine = currentLine
                        newLineText.opacity = 1; newLineText.y = 0; newLineText.scale = 1.0
                        return
                    }
                    if (currentLine === _lastLine) return

                        if (crossFadeAnim.running) {
                            crossFadeAnim.stop()
                            oldLineText.opacity = 0; oldLineText.y = 0
                            newLineText.opacity = 1; newLineText.y = 0; newLineText.scale = 1.0
                            _lastLine = currentLine
                            return
                        }

                        oldLineText.text = _lastLine
                        oldLineText.opacity = 1; oldLineText.y = 0

                        newLineText.y = 15; newLineText.opacity = 0; newLineText.scale = 0.95

                        _lastLine = currentLine
                        crossFadeAnim.start()
                }
            }
        }
    }

    function refreshColorization() {
        if (!effectiveArtUrl) return
            colorStable = false
            ++quantizerRequestId
    }
}
