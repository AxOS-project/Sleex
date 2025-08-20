import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

ColumnLayout {
    id: root
    required property bool input

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: deviceSelectorLayout.implicitHeight + 10
        color: Appearance.colors.colLayer2
        radius: Appearance.rounding.verysmall

        ColumnLayout {
            id: deviceSelectorLayout
            anchors.fill: parent
            anchors.margins: 5

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 5
                Layout.rightMargin: 5
                spacing: 5
                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: false
                    Layout.leftMargin: 5
                    color: Appearance.colors.colOnLayer2
                    iconSize: Appearance.font.pixelSize.hugeass
                    text: root.input ? "mic_external_on" : "media_output"
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.rightMargin: 5
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.normal
                        text: root.input ? qsTr("Input") : qsTr("Output")
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        text: (root.input ? Pipewire.defaultAudioSource?.description : Pipewire.defaultAudioSink?.description) ?? qsTr("Unknown")
                        color: Appearance.m3colors.m3outline
                    }
                }
            }
            PwObjectTracker {
                objects: [root.input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink]
            }
            StyledSlider {
                id: slider
                value: root.input ? (Pipewire.defaultAudioSource?.audio.volume ?? 0) : (Pipewire.defaultAudioSink?.audio.volume ?? 0)
                onValueChanged: {
                    if (root.input) {
                        Pipewire.defaultAudioSource.audio.volume = value
                    } else {
                        Pipewire.defaultAudioSink.audio.volume = value
                    }
                }
            }

            Repeater {
                id: deviceList
                model: ScriptModel {
                    values: Pipewire.nodes.values.filter(node => {
                        return !node.isStream && node.isSink !== root.input && node.audio
                    })
                }
                delegate: StyledRadioButton {
                    id: radioButton
                    required property var modelData
                    Layout.fillWidth: true
                    description: modelData.description
                    checked: modelData.id === (root.input ? Pipewire.defaultAudioSource?.id : Pipewire.defaultAudioSink?.id)
                    onCheckedChanged: {
                        if (checked) {
                            // Set the selected device as default
                            if (root.input) {
                                Pipewire.preferredDefaultAudioSource = modelData
                            } else {
                                Pipewire.preferredDefaultAudioSink = modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
