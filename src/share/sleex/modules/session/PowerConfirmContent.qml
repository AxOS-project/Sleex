import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance

Item {
    id: root
    required property string pendingAction
    required property int secondsLeft

    signal cancelRequested()
    signal confirmRequested()

    Keys.onPressed: event => { // Esc to cancel, matches PolkitContent
        if (event.key === Qt.Key_Escape) {
            root.cancelRequested();
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Appearance.colors.colScrim
        opacity: 0
        Component.onCompleted: {
            opacity = 1
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    WindowDialog {
        anchors.centerIn: parent
        backgroundWidth: 420
        show: false
        Component.onCompleted: {
            show = true
        }
        onDismiss: root.cancelRequested()

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            iconSize: 32
            text: "power_settings_new"
            color: Appearance.colors.colSecondary
        }

        WindowDialogTitle {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.pendingAction === "reboot" ? qsTr("Restart") : qsTr("Power Off")
        }

        WindowDialogParagraph {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.pendingAction === "reboot"
                ? qsTr("The system will restart automatically in %1 seconds.").arg(root.secondsLeft)
                : qsTr("The system will power off automatically in %1 seconds.").arg(root.secondsLeft)
        }

        WindowDialogButtonRow {
            Item { Layout.fillWidth: true }
            DialogButton {
                id: cancelButton
                buttonText: qsTr("Cancel")
                onClicked: root.cancelRequested()
                colBackground: cancelButton.focus ? Appearance.colors.colPrimaryContainer : "transparent"
                KeyNavigation.right: confirmButton
                // RippleButton (what DialogButton is built on) doesn't
                // activate on Enter/Return by default.
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.cancelRequested()
                        event.accepted = true
                    }
                }
            }
            DialogButton {
                id: confirmButton
                focus: true // matches Debian/GNOME: Enter confirms, since the power button press was already the deliberate step
                buttonText: root.pendingAction === "reboot" ? qsTr("Restart") : qsTr("Power Off")
                onClicked: root.confirmRequested()
                colBackground: confirmButton.focus ? Appearance.colors.colPrimaryContainer : "transparent"
                KeyNavigation.left: cancelButton
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.confirmRequested()
                        event.accepted = true
                    }
                }
            }
        }
    }
}
