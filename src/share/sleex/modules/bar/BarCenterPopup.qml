import qs
import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
        enabled: root.visible
        animation: NumberAnimation {
    duration: Appearance.animation.elementResize.duration
    easing.type: Appearance.animation.elementResize.type
    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
}
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

            Rectangle {
                id: popupVisualBackground
                anchors.fill: parent
                antialiasing: true
                color: Appearance.colors.colLayer0
                bottomLeftRadius: root.bottomRadius
                bottomRightRadius: root.bottomRadius
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
                            if (appsLoader.item && appsLoader.item.count > 0) {
                                let firstChild = appsLoader.item.itemAtIndex(0);
                                if (firstChild && firstChild.executeApp) {
                                    firstChild.executeApp();
                                    return;
                                }
                            }
                            const currentModel = appsLoader.item ? appsLoader.item.model
                                : (searchInput.text === "" ? AppSearch.list : AppSearch.fuzzyQuery(searchInput.text));
                            if (currentModel && currentModel.length > 0 && currentModel[0]) {
                                currentModel[0].execute();
                                barRoot.centerPopupOpen = false;
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
                Loader {
                    id: appsLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.visible
                    asynchronous: true
                    sourceComponent: GridView {
                        id: appsGrid
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        maximumFlickVelocity: 3500
                        cacheBuffer: 170

                        readonly property int columns: Math.max(1, Math.floor((width + 10) / 70))
                        cellWidth: width / columns
                        cellHeight: 85

                        model: searchInput.text === "" ? AppSearch.list : AppSearch.fuzzyQuery(searchInput.text)
                        onModelChanged: contentY = 0

                        delegate: Item {
                            id: appDelegate
                            required property var modelData
                            width: GridView.view.cellWidth
                            height: GridView.view.cellHeight

                            property var executeApp: () => {
                                appDelegate.modelData.execute();
                                barRoot.centerPopupOpen = false;
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
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
                                        asynchronous: true
                                        source: Quickshell.iconPath(appDelegate.modelData.icon, "application-x-executable")
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignHCenter
                                        text: appDelegate.modelData.name
                                        font.pixelSize: Appearance.font.pixelSize.smaller
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
                                    onClicked: appDelegate.executeApp()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
