import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "./ai"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    color: "transparent"
    clip: true

    AiChat {
        anchors.fill: parent
    }
}