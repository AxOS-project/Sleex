import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    clip: true
    
    property alias text: contentText.text
    property alias font: contentText.font
    property alias color: contentText.color
    property alias style: contentText.style
    property alias styleColor: contentText.styleColor
    property alias horizontalAlignment: contentText.horizontalAlignment
    property alias verticalAlignment: contentText.verticalAlignment
    
    implicitWidth: contentText.implicitWidth
    implicitHeight: contentText.implicitHeight

    property bool scrolling: contentText.width > root.width && root.width > 0
    property int scrollSpeed: 40
    property int scrollDelay: 2000

    property int index

    StyledText {
        id: contentText
        anchors.verticalCenter: parent.verticalCenter
        x: root.scrolling ? 0 : (parent.width - width) / 2

        text: contentText.text.slice(0, index++)
        
        wrapMode: Text.NoWrap
        
        color: Appearance?.m3colors.m3onBackground ?? "black"

        SequentialAnimation {
            id: scrollAnim
            running: root.scrolling && contentText.width > root.width && root.width > 0
            loops: Animation.Infinite
            alwaysRunToEnd: true

            onRunningChanged: {
                if (!running) contentText.x = 0
            }

            PauseAnimation { duration: root.scrollDelay }
            
            NumberAnimation {
                target: contentText
                property: "x"
                from: 0
                to: root.width - contentText.width
                duration: contentText.width / root.scrollSpeed * 1000
                easing.type: Easing.Linear
            }
            
            PropertyAction {
                target: contentText
                property: "x"
                value: root.width
            }
        }
    }
}