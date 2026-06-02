import QtQuick
import QtMultimedia

Item {
    id: root

    property string source:   ""
    property int    fillMode: Image.PreserveAspectCrop
    property bool   playing:  true

    readonly property bool isReady: _isAnimated 
        ? animImg.status === AnimatedImage.Ready
        : _isVideo
            ? mediaplayer.status === MediaPlayer.LoadedMedia
            : staticImg.status === Image.Ready
    
    readonly property bool _isAnimated: {
        const s = source.toLowerCase()
        return s.endsWith(".gif") || s.endsWith(".webp") || s.endsWith(".apng")
    }

    readonly property bool _isVideo: {
        console.log("Checking if source is video:", source)
        const s = source.toLowerCase()
        return s.endsWith(".mp4") || s.endsWith(".mkv") || s.endsWith(".webm")
    }

    onPlayingChanged: {
        if (_isVideo) {
            playing ? mediaplayer.play() : mediaplayer.pause()
        }
    }

    Image {
        id: staticImg
        anchors.fill: parent
        fillMode: root.fillMode
        source: root._isAnimated || root._isVideo ? "" : root.source
        sourceSize: Qt.size(Screen.width * Screen.devicePixelRatio, Screen.height * Screen.devicePixelRatio)
        visible: !root._isAnimated && !root._isVideo
        cache: false
    }

    AnimatedImage {
        id: animImg
        anchors.fill: parent
        fillMode: root.fillMode
        source: root._isAnimated ? root.source : ""
        sourceSize: Qt.size(Screen.width * Screen.devicePixelRatio, Screen.height * Screen.devicePixelRatio)
        visible: root._isAnimated
        playing: root._isAnimated && root.playing
        cache: false
    }

    MediaPlayer {
        id: mediaplayer
        source: root._isVideo ? (root.source.startsWith("/") ? "file://" + root.source : root.source) : ""
        loops: MediaPlayer.Infinite
        videoOutput: videoOutput

        onErrorOccurred: (error, errorString) => {
            console.log("ERROR Multimedia:", error, errorString)
        }
        
        audioOutput: AudioOutput {
            muted: true 
        }

        onSourceChanged: if (root.playing && root._isVideo) play()
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: root._isVideo
    }
}