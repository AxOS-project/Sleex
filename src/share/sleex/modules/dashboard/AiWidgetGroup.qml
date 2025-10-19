import qs.modules.dashboard.ai
import QtQuick

Rectangle {
    id: root
    color: "transparent"
    clip: true

    AiChat {
        anchors.fill: parent
    }
}