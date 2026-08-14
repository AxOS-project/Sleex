import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property var dayEvents: []
    property string dayEventsSummary: (button.dayEvents?.length ?? 0) > 4
        ? button.dayEvents.slice(0, 4).map(e => e.content).join("\n") + "…"
        : (button.dayEvents?.map(e => e.content).join("\n") ?? "")

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredWidth: 38
    Layout.preferredHeight: 38
    implicitWidth: 38;
    implicitHeight: 38;

    toggled: (isToday == 1)
    buttonRadius: Appearance.rounding.small
    
    contentItem: Item {
        anchors.fill: parent
        StyledText {
            anchors.centerIn: parent
            text: day
            horizontalAlignment: Text.AlignHCenter
            font.weight: bold ? Font.DemiBold : Font.Normal
            color: (isToday == 1) ? Appearance.m3colors.m3onPrimary : 
                (isToday == 0) ? Appearance.colors.colOnLayer1 : 
                Appearance.colors.colOutlineVariant

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            width: 6
            height: 6
            radius: 3
            visible: (button.dayEvents?.length ?? 0) > 0
            color: button.dayEvents?.[0]?.color ?? Appearance.m3colors.m3primary
        }
    }

    StyledToolTip {
        text: button.dayEventsSummary
        extraVisibleCondition: (button.dayEvents?.length ?? 0) > 0
    }
}
