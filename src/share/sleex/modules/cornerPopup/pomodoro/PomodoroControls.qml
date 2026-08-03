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
        materialIcon: Pomodoro.running ? "pause" : "play_arrow"
        mainText: Pomodoro.running ? "Pause" : "Start"
        onClicked: Pomodoro.toggle()
        colBackground: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.2)
        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.3)
    }

    RippleButtonWithIcon {
        materialIcon: "refresh"
        mainText: "Reset"
        onClicked: Pomodoro.reset()
    }
}
