import QtQuick
import QtQuick.Layouts
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import Sleex.Utils

Revealer {
    id: root
    reveal: BentoModel.customizeOpen
    vertical: true

    Rectangle {
        width: root.parent ? root.parent.width : implicitWidth
        implicitHeight: barRow.implicitHeight + 16
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        RowLayout {
            id: barRow
            anchors.fill: parent
            anchors.margins: 8
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            MaterialSymbol {
                text: "dashboard_customize"
                iconSize: 20
                color: Appearance.colors.colPrimary
            }

            StyledText {
                text: qsTr("Layout Presets:")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
            }

            ButtonGroup {
                spacing: 4
                padding: 2
                color: Appearance.colors.colLayer2

                Repeater {
                    model: BentoModel.layoutPresets
                    delegate: SelectionGroupButton {
                        leftmost: index === 0
                        rightmost: index === BentoModel.layoutPresets.length - 1
                        buttonText: modelData.name
                        toggled: BentoModel.currentPreset === modelData.id
                        onClicked: BentoModel.applyPreset(modelData.id)
                    }
                }
            }

            Rectangle {
                visible: BentoModel.hiddenWidgets.length > 0
                Layout.preferredWidth: 1
                Layout.preferredHeight: 22
                color: Appearance.colors.colOutlineVariant
            }

            StyledText {
                visible: BentoModel.hiddenWidgets.length > 0
                text: qsTr("Hidden:")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }

            RowLayout {
                visible: BentoModel.hiddenWidgets.length > 0
                spacing: 6

                Repeater {
                    model: BentoModel.hiddenWidgets
                    delegate: RippleButtonWithIcon {
                        materialIcon: modelData.icon
                        materialIconFill: false
                        mainText: `+ ${modelData.title}`
                        implicitHeight: 30
                        horizontalPadding: 10
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colSecondaryContainer
                        colText: Appearance.colors.colOnSecondaryContainer
                        onClicked: BentoModel.setWidgetEnabled(modelData.id, true)
                    }
                }
            }

            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                materialIcon: "restart_alt"
                materialIconFill: false
                mainText: qsTr("Reset")
                implicitHeight: 32
                horizontalPadding: 12
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                colText: Appearance.colors.colOnLayer2
                onClicked: BentoModel.resetToDefault()
                StyledToolTip { text: qsTr("Reset home layout to default") }
            }

            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer2
                onClicked: BentoModel.customizeOpen = false

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer2
                }
                StyledToolTip { text: qsTr("Done customizing") }
            }
        }
    }
}
