import qs
import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    required property Item targetSection
    required property var barRoot

    property real popupHeight: 320
    property bool open: barRoot ? barRoot.centerPopupOpen : false
    property bool isAnimating: false

    readonly property real bottomRadius: Appearance.rounding.screenRounding
    property real widthOffset: 40

    property real cardWidth: targetSection ? targetSection.width - 100 : 400

    width: cardWidth + (bottomRadius * 2)
    height: popupHeight

    anchors {
        horizontalCenter: parent.horizontalCenter
        top: parent.top
        topMargin: root.open ? Appearance.sizes.barHeight : Appearance.sizes.barHeight - root.popupHeight
    }

    Behavior on anchors.topMargin {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    z: -2
    visible: root.open || root.isAnimating || opacity > 0

    Behavior on width {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    Timer {
        id: animTimer
        interval: Appearance.animation.elementMove.duration + 50
        onTriggered: {
            root.isAnimating = false
        }
    }

    onOpenChanged: {
        root.isAnimating = true
        animTimer.restart()
        if (root.open) {
            searchInput.forceActiveFocus()
            searchInput.selectAll()
        } else {
            searchInput.text = ""
        }
    }

    opacity: root.open ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
        }
    }

    RoundCorner {
        id: leftInvertedCorner
        anchors.right: popupCard.left
        anchors.top: parent.top
        size: root.bottomRadius
        corner: cornerEnum.topRight
        color: Appearance.colors.colLayer0
        visible: true
    }

    RoundCorner {
        id: rightInvertedCorner
        anchors.left: popupCard.right
        anchors.top: parent.top
        size: root.bottomRadius
        corner: cornerEnum.topLeft
        color: Appearance.colors.colLayer0
        visible: true
    }

    Item {
        id: popupCard
        width: root.cardWidth
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter

        MouseArea {
            id: popupMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            Item {
                id: popupVisualBackground
                anchors.fill: parent

                Shape {
                    id: popupShape
                    anchors.fill: parent
                    antialiasing: true

                    property color bgColor: Appearance.colors.colLayer0

                    ShapePath {
                        fillColor: popupShape.bgColor
                        strokeWidth: 0

                        startX: 0
                        startY: 0

                        PathLine { x: popupShape.width; y: 0 }
                        PathLine { x: popupShape.width; y: popupShape.height - root.bottomRadius }
                        PathQuad {
                            x: popupShape.width - root.bottomRadius
                            y: popupShape.height
                            controlX: popupShape.width
                            controlY: popupShape.height
                        }
                        PathLine { x: root.bottomRadius; y: popupShape.height }
                        PathQuad {
                            x: 0
                            y: popupShape.height - root.bottomRadius
                            controlX: 0
                            controlY: popupShape.height
                        }
                        PathLine { x: 0; y: 0 }
                    }
                }
            }

            // Popup Content
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: searchInput.text === "" ? "apps" : "search"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colPrimary
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: qsTr("Search applications...")
                        color: Appearance.m3colors.m3onSurface
                        placeholderTextColor: Appearance.m3colors.m3outline
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.family: Appearance.font.family.main
                        renderType: Text.NativeRendering
                        background: null
                        focus: root.open

                        onAccepted: {
                            if (appsRepeater.count > 0) {
                                var firstApp = appsRepeater.itemAt(0);
                                if (firstApp && firstApp.executeApp) {
                                    firstApp.executeApp();
                                }
                            }
                        }

                        Keys.onEscapePressed: {
                            barRoot.centerPopupOpen = false;
                        }
                    }

                    RippleButton {
                        Layout.rightMargin: 4
                        implicitWidth: 35
                        implicitHeight: 35
                        buttonRadius: Appearance.rounding.full
                        colBackgroundHover: Appearance.colors.colSecondaryContainer
                        colRipple: Appearance.colors.colSecondaryContainerActive

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "grid_view"
                            font.pixelSize: 18
                            color: Appearance.m3colors.m3onSurface
                        }

                        onClicked: {
                            barRoot.centerPopupOpen = false;
                            GlobalStates.overviewOpen = true;
                        }

                        StyledToolTip {
                            text: "Switch to Overview"
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                    opacity: 0.3
                }

                // Apps grid
                StyledFlickable {
                    id: appsFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: appsGrid.implicitHeight

                    GridLayout {
                        id: appsGrid
                        width: appsFlickable.width
                        rowSpacing: 10
                        columnSpacing: 10
                        columns: Math.max(1, Math.floor((width + columnSpacing) / (60 + columnSpacing)))

                        Repeater {
                            id: appsRepeater
                            model: searchInput.text === "" ? AppSearch.list : AppSearch.fuzzyQuery(searchInput.text)

                            Rectangle {
                                width: 60
                                height: 75
                                radius: Appearance.rounding.normal
                                color: "transparent"
                                
                                property bool isHovered: appMouseArea.containsMouse
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Appearance.rounding.normal
                                    color: Appearance.colors.colSecondaryContainer
                                    opacity: parent.isHovered ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 4
                                    
                                    IconImage {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitSize: 32
                                        source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                    }
                                    
                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.name
                                        font.pixelSize: Appearance.font.pixelSize.tiny
                                        horizontalAlignment: Text.AlignHCenter
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                        color: Appearance.colors.colOnLayer0
                                    }
                                }
                                
                                MouseArea {
                                    id: appMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modelData.execute();
                                        barRoot.centerPopupOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
