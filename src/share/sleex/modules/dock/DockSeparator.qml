import qs
import qs.modules.common
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SleexUiKit.Appearance

Rectangle {
    Layout.topMargin: Appearance.sizes.elevationMargin + dockRow.padding + Appearance.rounding.normal
    Layout.bottomMargin: Appearance.sizes.hyprlandGapsOut + dockRow.padding + Appearance.rounding.normal
    Layout.fillHeight: true
    implicitWidth: 1
    color: Appearance.colors.colOutlineVariant
}
