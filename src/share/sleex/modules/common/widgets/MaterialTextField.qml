import qs.modules.common
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls

/**
 * Material 3 styled TextField (filled style)
 * https://m3.material.io/components/text-fields/overview
 * Note: We don't use NativeRendering because it makes the small placeholder text look weird
 */
TextField {
    id: root
    Material.theme: Material.System
    Material.accent: Appearance.colors.colPrimary
    Material.primary: Appearance.colors.colPrimary
    Material.background: Appearance.colors.colOnSurface
    Material.foreground: Appearance.colors.colOnSurface
    Material.containerStyle: Material.Outlined
    renderType: Text.QtRendering

    selectedTextColor: Appearance.colors.colOnSecondaryContainer
    selectionColor: Appearance.colors.colSecondaryContainer
    placeholderTextColor: Appearance.colors.colOutline
    clip: true

    font {
        family: Appearance?.font.family.main ?? "sans-serif"
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
    }
    wrapMode: TextEdit.Wrap

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
    }
}