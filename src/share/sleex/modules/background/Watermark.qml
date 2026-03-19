import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.services

// System version watermark display
Item {
    id: watermarkItem
    property bool visibleWatermark: true
    property int marginRight: 40
    property int marginBottom: 10
    
    // Set explicit size to contain the content
    width: systemInfoContent.implicitWidth
    height: systemInfoContent.implicitHeight
    
    anchors {
        right: parent.right
        bottom: parent.bottom
        rightMargin: marginRight
        bottomMargin: marginBottom
    }
    
    visible: visibleWatermark
    
    RowLayout {
        id: systemInfoContent
        spacing: 16
        
        anchors {
            right: parent.right
            bottom: parent.bottom
        }
        
        // OS information
        ColumnLayout {
            spacing: 2
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            
            Text {
                text: SystemInfo.distroName
                color: "#40ffffff"
                font.pointSize: 16
                font.weight: Font.DemiBold
                font.letterSpacing: -0.4
                Layout.alignment: Qt.AlignRight
            }
            
            Text {
                text: {
                    if (SystemInfo.distroId === "axos") {
                        return SystemInfo.axosVersion ? SystemInfo.axosVersion : "";
                    }
                    return SystemInfo.osReleaseVersion ? SystemInfo.osReleaseVersion : "";
                }
                color: "#30ffffff"
                font.pointSize: 10
                font.weight: Font.Medium
                visible: text.length > 0
                Layout.alignment: Qt.AlignRight
            }
        }
        
        Text {
            text: "│"
            color: "#20ffffff"
            font.pointSize: 14
            font.weight: Font.Light
            Layout.alignment: Qt.AlignVCenter // Changed to AlignVCenter
        }
        
        // Sleex information
        ColumnLayout {
            spacing: 2
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            
            Text {
                text: "Sleex"
                color: "#40ffffff"
                font.pointSize: 16
                font.weight: Font.DemiBold
                font.letterSpacing: -0.4
                Layout.alignment: Qt.AlignRight
            }
            
            Text {
                text: SystemInfo.sleexVersion
                color: "#30ffffff"
                font.pointSize: 10
                font.weight: Font.Medium
                visible: text.length > 0
                Layout.alignment: Qt.AlignRight
            }
        }
    }
}