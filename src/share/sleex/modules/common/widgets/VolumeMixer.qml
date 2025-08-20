import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire


Item {
    id: root
    readonly property list<PwNode> appPwNodes: Pipewire.nodes.values.filter((node) => {
        // return node.type == "21" // Alternative, not as clean
        return node.isSink && node.isStream
    })

    onAppPwNodesChanged: console.log("Volume Mixer: Number of audio nodes:", root.appPwNodes.length)


    ColumnLayout {
        anchors.fill: parent
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledListView {
                id: listView
                model: root.appPwNodes
                clip: true
                anchors {
                    fill: parent
                    topMargin: 10
                    bottomMargin: 10
                }
                spacing: 6

                delegate: Item {
                    id: rootEntry

                    Component.onCompleted: console.log("VolumeMixerEntry created for node:", modelData.id, modelData.ready, modelData.name, modelData.audio.volume)

                    implicitHeight: rowLayout.implicitHeight


                    RowLayout {
                        id: rowLayout
                        anchors.fill: parent
                        spacing: 12

                        PwObjectTracker {
                            objects: [modelData]
                        }

                        Image {
                            property real size: slider.height * 0.9
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                            visible: source != ""
                            sourceSize.width: size
                            sourceSize.height: size
                            source: {
                                let icon;
                                icon = AppSearch.guessIcon(modelData.properties["application.icon-name"]);
                                if (AppSearch.iconExists(icon)) return Quickshell.iconPath(icon, "image-missing");
                                icon = AppSearch.guessIcon(modelData.properties["node.name"]);
                                return Quickshell.iconPath(icon, "image-missing");
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -4

                            StyledText {
                                Layout.fillWidth: true
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                                text: {
                                    // application.name -> description -> name

                                    const app = modelData.properties["application.name"] ?? (modelData.description != "" ? modelData.description : modelData.name);
                                    const media = modelData.properties["media.name"];
                                    return media != undefined ? `${app} • ${media}` : app;
                                }
                            }

                            StyledSlider {

                                id: slider
                                value: modelData.audio.volume
                                onValueChanged: modelData.audio.volume = value
                            }
                        }
                    }
                }
            }

            // Placeholder when list is empty
            Item {
                anchors.fill: listView

                visible: opacity > 0
                opacity: (root.appPwNodes.length === 0) ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.menuDecel.duration
                        easing.type: Appearance.animation.menuDecel.type
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        iconSize: 55
                        color: Appearance.m3colors.m3outline
                        text: "brand_awareness"
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors.m3outline
                        horizontalAlignment: Text.AlignHCenter
                        text: "No audio source"
                    }
                }
            }
        }
    }
}