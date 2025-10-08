import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.services

// System version watermark display
Item {
    id: root
    property bool visibleQuote: true
    property int marginLeft: 30
    property int marginBottom: 30
    
    // Set explicit size to contain the content
    width: quoteContent.implicitWidth
    height: quoteContent.implicitHeight
    
    anchors {
        left: parent.left
        bottom: parent.bottom
        leftMargin: marginLeft
        bottomMargin: marginBottom
    }
    
    visible: visibleQuote
    
    RowLayout {
        id: quoteContent
        spacing: 16
        
        anchors {
            left: parent.left
            bottom: parent.bottom
        }
        
        ColumnLayout {
            spacing: 2
            
            Text {
                text: Quotes.quote
                color: "#40ffffff"
                font.pointSize: 14
                font.weight: Font.DemiBold
            }
            
            Text {
                text: "- " + Quotes.author
                color: "#30ffffff"
                font.pointSize: 10
                font.weight: Font.Medium
                visible: text.length > 0
            }
        }
    }
}