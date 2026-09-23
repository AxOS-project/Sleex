import qs
import qs.services
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    property int wppselectorPadding: 15
    property bool isUnsplash: false
    property string searchQuery: "wallpapers"
    readonly property bool missingUnsplashKey: isUnsplash && Unsplash.apiKey.length === 0

    PanelWindow {
        id: wppselectorRoot
        visible: GlobalStates.wppselectorOpen

        function hide() {
            GlobalStates.wppselectorOpen = false
        }

        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:wppselector"
        color: "transparent"

        implicitWidth: 1000
        implicitHeight: 700

        HyprlandFocusGrab {
            id: grab
            windows: [ wppselectorRoot ]
            active: GlobalStates.wppselectorOpen && !GlobalStates.tutorialMode
            onCleared: () => {
                if (!active && !GlobalStates.tutorialMode) wppselectorRoot.hide()
            }
        }

        anchors.top: true
        margins {
            top: Appearance.sizes.hyprlandGapsOut * 3
        }

        Loader {
            id: wppselectorContentLoader
            anchors {
                fill: parent
                margins: Appearance.sizes.hyprlandGapsOut
                leftMargin: Appearance.sizes.elevationMargin
            }

            focus: GlobalStates.wppselectorOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    wppselectorRoot.hide();
                }
            } 

            sourceComponent: Item {
                StyledRectangularShadow {
                    target: wppselectorBackground
                }
                
                Rectangle {
                    id: wppselectorBackground
                    anchors.fill: parent
                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

                    Item {
                        id: topBar
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 60

                        RippleButtonWithIcon {
                            id: sourceSelector
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 20
                            height: 40
                            materialIcon: isUnsplash ? "cloud" : "folder"
                            mainText: isUnsplash ? qsTr("Unsplash") : qsTr("Local")
                            colBackground: Appearance.colors.colSecondaryContainer
                            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                            onClicked: {
                                isUnsplash = !isUnsplash;
                                if (isUnsplash && Unsplash.searchResults.length === 0) {
                                    Unsplash.search(searchQuery, 1);
                                }
                            }
                        }
                        
                        RowLayout {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 20
                            spacing: 8
                            
                            MaterialSymbol {
                                text: "image"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer0
                            }
                            
                            StyledText {
                                text: qsTr("Wallpaper Selector")
                                font.pixelSize: Appearance.font.pixelSize.large
                                color: Appearance.colors.colOnLayer0
                            }
                        }
                    }

                    Rectangle {
                        id: flickableBg
                        anchors.top: topBar.bottom
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 20
                        anchors.bottomMargin: isUnsplash ? 80 : 20
                        color: Appearance.colors.colLayer1
                        radius: Appearance.rounding.small
                        
                        GridView {
                            id: wallpaperFlickable
                            visible: !missingUnsplashKey
                            anchors.fill: parent
                            anchors.margins: wppselectorPadding
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: true
                            clip: true
                            
                            cellWidth: Math.floor(width / 4)
                            cellHeight: Math.floor(cellWidth * 9 / 16) + 15
                            
                            model: isUnsplash ? Unsplash.searchResults : Wallpapers.wallpaperList
                            
                            delegate: Item {
                                id: delegateItem
                                width: GridView.view.cellWidth
                                height: GridView.view.cellHeight

                                ClippingRectangle {
                                    anchors.fill: parent
                                    anchors.margins: wppselectorPadding / 2
                                    radius: Appearance.rounding.small
                                    color: Appearance.colors.colLayer2
                                    clip: true

                                    StyledBusyIndicator {
                                        anchors.centerIn: parent
                                        visible: wallpaperImage.status === Image.Loading || (isUnsplash && Unsplash.currentlyDownloadingId === (modelData.id ? modelData.id : ""))
                                        running: true
                                        width: 45
                                        height: 45
                                        z: 10
                                    }                   
                                         
                                    Image {
                                        id: wallpaperImage
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: isUnsplash ? (modelData.urls && modelData.urls.small ? modelData.urls.small : "") : (Config.options.background.wallpaperSelectorPath + "/" + modelData)
                                        asynchronous: true
                                        cache: true
                                        sourceSize: Qt.size(480, 270)
                                        visible: !(isUnsplash && Unsplash.currentlyDownloadingId === (modelData.id ? modelData.id : ""))
                                    }
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Appearance.rounding.small
                                        color: delegateMouseArea.containsMouse ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.15) : "transparent"
                                        border.width: delegateMouseArea.containsMouse ? 2 : 0
                                        border.color: Appearance.colors.colPrimary
                                    }

                                    MouseArea {
                                        id: delegateMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (isUnsplash) {
                                                var imgId = modelData.id;
                                                var imgUrl = modelData.urls.full;
                                                Unsplash.applyWallpaper(imgId, imgUrl);
                                            } else {
                                                GlobalStates.wppselectorOpen = false
                                                Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/colors/switchwall.sh"), Config.options.background.wallpaperSelectorPath + "/" + modelData, "&"])
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            id: missingKeyLayout
                            visible: missingUnsplashKey
                            anchors.centerIn: parent
                            spacing: 16

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "key_off"
                                iconSize: 48
                                color: Appearance.colors.colSubtext
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: qsTr("Unsplash API key not set")
                                font.pixelSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: qsTr("Get your free key at unsplash.com/developers")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 10
                                spacing: 10

                                MaterialTextField {
                                    id: apiKeyInput
                                    placeholderText: qsTr("Enter API Key")
                                    Layout.preferredWidth: 300
                                    onAccepted: submitKeyBtn.clicked()
                                }

                                RippleButtonWithIcon {
                                    id: submitKeyBtn
                                    materialIcon: "check"
                                    Layout.preferredHeight: 40
                                    colBackground: Appearance.colors.colPrimaryContainer
                                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                                    mainText: qsTr("Submit")
                                    onClicked: {
                                        if (apiKeyInput.text.trim().length > 0) {
                                            Unsplash.saveApiKey(apiKeyInput.text.trim());r
                                            apiKeyInput.text = "";
                                            if (Unsplash.searchResults.length === 0) {
                                                Unsplash.search(searchQuery, 1);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        id: extraOptions
                        visible: isUnsplash && !missingUnsplashKey
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 20
                        spacing: 8
                        z: 2

                        Rectangle {
                            implicitHeight: 52
                            implicitWidth: searchRow.implicitWidth + 16
                            radius: height / 2
                            color: Appearance.colors.colLayer0 // Matches dark pill

                            RowLayout {
                                id: searchRow
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 4

                                Rectangle {
                                    Layout.preferredHeight: 40
                                    Layout.preferredWidth: 200
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: height / 2
                                    color: Appearance.colors.colLayer1
                                    
                                    TextInput {
                                        id: searchInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Appearance.colors.colOnLayer0
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        text: searchQuery
                                        onAccepted: {
                                            searchQuery = text;
                                            Unsplash.search(searchQuery, 1);
                                        }
                                    }
                                }

                                RippleButton {
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    buttonRadius: 20
                                    colBackground: "transparent"
                                    enabled: Unsplash.currentPage > 1
                                    onClicked: Unsplash.search(searchQuery, Unsplash.currentPage - 1)
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "chevron_left"
                                        color: parent.enabled ? Appearance.colors.colOnLayer0 : Appearance.colors.colOutline
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    radius: 20
                                    color: Appearance.colors.colLayer1
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Unsplash.currentPage
                                        color: Appearance.colors.colOnLayer0
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                    }
                                }

                                RippleButton {
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    buttonRadius: 20
                                    colBackground: "transparent"
                                    enabled: Unsplash.currentPage < Unsplash.totalPages
                                    onClicked: Unsplash.search(searchQuery, Unsplash.currentPage + 1)
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "chevron_right"
                                        color: parent.enabled ? Appearance.colors.colOnLayer0 : Appearance.colors.colOutline
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "wppselector"

        function toggle(): void {
            GlobalStates.wppselectorOpen = !GlobalStates.wppselectorOpen;
        }

        function close(): void {
            GlobalStates.wppselectorOpen = false;
            GlobalStates.tutorialMode = false;
        }

        function open(): void {
            GlobalStates.tutorialMode = false;
            GlobalStates.wppselectorOpen = true;
        }

        function openTutorial(): void {
            GlobalStates.tutorialMode = true;
            GlobalStates.wppselectorOpen = true;
        }
    }

    GlobalShortcut {
        name: "wppselectorToggle"
        description: qsTr("Toggles wallpaper selector on press")

        onPressed: {
            GlobalStates.wppselectorOpen = !GlobalStates.wppselectorOpen;
        }
    }
    GlobalShortcut {
        name: "wppselectorOpen"
        description: qsTr("Opens wallpaper selector on press")

        onPressed: {
            GlobalStates.wppselectorOpen = true;
        }
    }
    GlobalShortcut {
        name: "wppselectorClose"
        description: qsTr("Closes wallpaper selector on press")

        onPressed: {
            GlobalStates.wppselectorOpen = false;
        }
    }

}
