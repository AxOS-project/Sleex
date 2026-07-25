import SleexUiKit.Appearance
import SleexUiKit.Functions
import QtQuick

Item {
    Binding { target: Appearance; property: "wallpaperPath"; value: Config.options.background.wallpaperPath }
    Binding { target: Appearance; property: "thumbnailPath"; value: Config.options.background.thumbnailPath }
    Binding { target: Appearance; property: "backgroundTransparency"; value: Config?.options.appearance.transparency ? Config?.options.appearance.opacity / 100 : 0 }
    Binding { target: Appearance; property: "contentTransparency"; value: Config?.options.appearance.transparency ? Config?.options.appearance.opacity / 100 : 0 }
    Binding { target: Appearance.colors; property: "colLayer0"; value: ColorUtils.mix(ColorUtils.transparentize(Appearance.m3colors.m3background, Appearance.backgroundTransparency), Appearance.m3colors.m3primary, Config.options.appearance.extraBackgroundTint ? 0.99 : 1) }
    Binding { target: Appearance.sizes; property: "barHeight"; value: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.baseBarHeight + Appearance.sizes.hyprlandGapsOut * 2) : Appearance.sizes.baseBarHeight }
    Binding { target: Appearance.sizes; property: "barCenterSideModuleWidth"; value: Config.options?.bar.verbose ? 360 : 140 }
    Binding { target: Appearance.sizes; property: "verticalBarWidth"; value: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.baseVerticalBarWidth + Appearance.sizes.hyprlandGapsOut * 2) : Appearance.sizes.baseVerticalBarWidth }
}