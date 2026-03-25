import QtQuick
import QtQuick.Controls
import Sleex.Widgets
import qs.modules.common
import qs.services

Item {
    id: root
    width: calendar.implicitWidth
    height: calendar.implicitHeight

    property var contribs: Github.contributions !== undefined ? Github.contributions : []

    ContributionCalendar {
        id: calendar
        anchors.centerIn: parent

        contributions: root.contribs

        cellSize: 7
        gap: 2
        radius: 2

        level0Color: Appearance.colors.colLayer2
        level1Color: Appearance.colors.colSecondaryContainer
        level2Color: Appearance.colors.colSecondary
        level3Color: Appearance.colors.colPrimary
        level4Color: Appearance.colors.colPrimary
    }

    ToolTip {
        visible: calendar.containsMouse
        text: calendar.hoveredTooltip
        delay: 150
    }
}
