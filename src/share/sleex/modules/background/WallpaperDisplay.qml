import QtQuick

Item {
    id: root

    property string source:   ""
    property int    fillMode: Image.PreserveAspectCrop
    property bool   playing:  true

    readonly property bool isReady: _isAnimated 
        ? animImg.status === AnimatedImage.Ready 
        : staticImg.status === Image.Ready
    
    readonly property bool _isAnimated: {
        const s = source.toLowerCase()
        return s.endsWith(".gif") || s.endsWith(".webp") || s.endsWith(".apng")
    }

    Image {
        id: staticImg
        anchors.fill: parent
        fillMode:     root.fillMode
        source:       root._isAnimated ? "" : root.source
        visible:      !root._isAnimated
        cache:        false
    }

    AnimatedImage {
        id: animImg
        anchors.fill: parent
        fillMode:     root.fillMode
        source:       root._isAnimated ? root.source : ""
        visible:      root._isAnimated
        playing:      root._isAnimated && root.playing
        cache:        false

        onSourceChanged: {
            if (root._isAnimated) {
                playing = false
                playing = true
            }
        }
    }
}
