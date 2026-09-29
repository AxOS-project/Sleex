import qs.modules.common
import qs.modules.cornerPopup.stopwatch
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: Appearance.rounding.normal
    color: ColorUtils.applyAlpha(Appearance.colors.colLayer2, 0.6)
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant

    Item {
        anchors.fill: parent
        anchors.margins: 14

        StopwatchWidget {}
    }
}
