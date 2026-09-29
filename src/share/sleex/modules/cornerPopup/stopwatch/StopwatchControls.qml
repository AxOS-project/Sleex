import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import SleexUiKit.Functions
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 12
    Layout.alignment: Qt.AlignHCenter

    RippleButtonWithIcon {
        materialIcon: Stopwatch.running ? "pause" : "play_arrow"
        mainText: Stopwatch.running ? "Pause" : "Start"
        colBackground: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.2)
        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.3)

        onClicked: Stopwatch.toggle()
    }

    RippleButtonWithIcon {
        materialIcon: "flag"
        mainText: "Lap"
        enabled: Stopwatch.elapsedTime > 0
        onClicked: Stopwatch.recordLap()
    }

    RippleButtonWithIcon {
        materialIcon: "refresh"
        mainText: "Reset"
        enabled: Stopwatch.elapsedTime > 0 || Stopwatch.running
        onClicked: Stopwatch.reset()
    }
}
