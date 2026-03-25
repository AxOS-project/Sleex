import QtQuick
import QtQuick.Controls
import Sleex.Widgets
import qs.modules.common
import qs.services


Item {
    id: contributionCalendar
    width: 300
    height: 60

    ContributionCalendar {
        id: calendar
        anchors.centerIn: parent

        contributions: []

        cellSize: 7
        gap: 2
        radius: 2

        level0Color: Appearance.colors.colLayer2
        level1Color: Appearance.colors.colSecondaryContainer
        level2Color: Appearance.colors.colSecondary
        level3Color: Appearance.colors.colPrimary
        level4Color: Appearance.colors.colPrimary
    }
}
