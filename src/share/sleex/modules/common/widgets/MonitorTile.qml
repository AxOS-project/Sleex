import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import Sleex.Services

Item {
    id: tile

    required property var   monitorInfo
    property int            monitorIndex: 0
    property bool           isSelected: false
    property bool           isPending: false
    property bool           isMirroring: false
    property string         mirrorTarget: ""
    property bool           isFocused: false

    property real realX:      monitorInfo ? monitorInfo.x : 0
    property real realY:      monitorInfo ? monitorInfo.y : 0
    property real realWidth:  monitorInfo ? monitorInfo.width : 1920
    property real realHeight: monitorInfo ? monitorInfo.height : 1080
    property real realScale:  monitorInfo ? monitorInfo.scale : 1.0

    // Compatibility aliases
    property alias origin: tile.canvasOrigin
    required property point canvasOrigin
    required property real  canvasScaleF
    property real           canvasOffsetX: 0
    property real           canvasOffsetY: 0

    property var            allTiles: null
    property Item           tileParent: null

    signal clicked()
    signal dragCommitted(string name, real rx, real ry)
    signal snapGuideUpdate(bool visible, real cx, real cy, real cw, real ch, string guideType)
    signal snapLineUpdate(bool showH, real hy, bool showV, real vx)

    readonly property real targetX: (realX - canvasOrigin.x) * canvasScaleF + canvasOffsetX
    readonly property real targetY: (realY - canvasOrigin.y) * canvasScaleF + canvasOffsetY
    readonly property real targetWidth: Math.max(88, realWidth * canvasScaleF)
    readonly property real targetHeight: Math.max(58, realHeight * canvasScaleF)

    readonly property bool isLaptop: monitorInfo && monitorInfo.name ? monitorInfo.name.startsWith("eDP") : false

    readonly property string displayName: {
        if (!monitorInfo) return "Display"
        if (monitorInfo.model && monitorInfo.model.length > 0) return monitorInfo.model
        if (monitorInfo.make && monitorInfo.make.length > 0) return monitorInfo.make
        return monitorInfo.name
    }

    x: targetX
    y: targetY
    width: targetWidth
    height: targetHeight

    Behavior on x {
        enabled: !dragHandler.active
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: !dragHandler.active
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on width {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    z: dragHandler.active ? 50 : (isSelected ? 20 : 1)

    // Stand neck
    Rectangle {
        id: standNeck
        visible: !tile.isLaptop
        anchors.top: screenBody.bottom
        anchors.topMargin: -2
        anchors.horizontalCenter: screenBody.horizontalCenter
        width: Math.max(10, Math.min(22, screenBody.width * 0.12))
        height: 8
        color: Appearance.colors.colOutlineVariant
        radius: 2
        z: -1
    }

    // Stand base
    Rectangle {
        id: standBase
        visible: !tile.isLaptop
        anchors.top: standNeck.bottom
        anchors.topMargin: -1
        anchors.horizontalCenter: standNeck.horizontalCenter
        width: Math.max(34, Math.min(60, screenBody.width * 0.38))
        height: 4
        color: Appearance.colors.colOutline
        radius: 2
        z: -1
    }

    // Monitor Screen Casing
    Rectangle {
        id: screenBody
        anchors.fill: parent
        radius: 8

        color: dragHandler.active
               ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.28)
               : tile.isSelected
                 ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.16)
                 : tile.isMirroring
                   ? Qt.rgba(Appearance.colors.colTertiary.r, Appearance.colors.colTertiary.g, Appearance.colors.colTertiary.b, 0.18)
                   : tile.isPending
                     ? Qt.rgba(Appearance.colors.colSecondary.r, Appearance.colors.colSecondary.g, Appearance.colors.colSecondary.b, 0.18)
                     : Appearance.colors.colLayer2

        border.color: dragHandler.active || tile.isSelected
                      ? Appearance.colors.colPrimary
                      : tile.isPending
                        ? Appearance.colors.colSecondary
                        : tile.isMirroring
                          ? Appearance.colors.colTertiary
                          : Appearance.colors.colOutlineVariant
        border.width: tile.isSelected || dragHandler.active ? 2.5 : 1.5

        scale: dragHandler.active ? 1.05 : (hoverHandler.hovered ? 1.015 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        // Inner screen surface
        Rectangle {
            id: innerDisplay
            anchors.fill: parent
            anchors.margins: 4
            radius: 5
            color: Appearance.colors.colLayer0
            clip: true

            // Center content
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 12
                spacing: 1

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: tile.isLaptop ? "laptop" : "desktop_windows"
                    iconSize: Math.max(16, Math.min(26, innerDisplay.height * 0.26))
                    color: tile.isSelected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    text: tile.displayName
                    font.pixelSize: Math.max(8, Math.min(12, innerDisplay.height * 0.14))
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: tile.isSelected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: portText.implicitHeight + 2
                    implicitWidth: portText.implicitWidth + 8
                    radius: 3
                    color: Appearance.colors.colLayer1

                    StyledText {
                        id: portText
                        anchors.centerIn: parent
                        text: tile.monitorInfo ? tile.monitorInfo.name : ""
                        font.pixelSize: Math.max(7, Math.min(10, innerDisplay.height * 0.11))
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            // Mirror banner
            Rectangle {
                visible: tile.isMirroring
                anchors.centerIn: parent
                width: parent.width - 10
                height: 22
                radius: 4
                color: Qt.rgba(Appearance.colors.colTertiary.r, Appearance.colors.colTertiary.g, Appearance.colors.colTertiary.b, 0.9)
                z: 10

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        text: "screen_share"
                        iconSize: 12
                        color: Appearance.colors.colOnTertiary
                    }
                    StyledText {
                        text: "Mirror: " + tile.mirrorTarget
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnTertiary
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // Detailed ToolTip
    StyledToolTip {
        extraVisibleCondition: hoverHandler.hovered && !dragHandler.active
        text: [
            tile.displayName + " (" + (tile.monitorInfo ? tile.monitorInfo.name : "") + ")",
            "Resolution: " + Math.round(tile.realWidth) + "×" + Math.round(tile.realHeight) +
                (tile.monitorInfo && tile.monitorInfo.refreshRate > 0 ? " @" + tile.monitorInfo.refreshRate.toFixed(1) + "Hz" : ""),
            "Scale: " + Math.round(tile.realScale * 100) + "%",
            "Position: (" + Math.round(tile.realX) + ", " + Math.round(tile.realY) + ")",
            tile.isMirroring ? "Mirroring: " + tile.mirrorTarget : "",
        ].filter(Boolean).join("\n")
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    TapHandler {
        onTapped: tile.clicked()
    }

    property real dragStartX: 0
    property real dragStartY: 0
    readonly property real snapThreshold: 18

    DragHandler {
        id: dragHandler
        enabled: !tile.isMirroring
        target: null

        onActiveChanged: {
            if (active) {
                tile.dragStartX = tile.x
                tile.dragStartY = tile.y
            } else {
                tile.snapGuideUpdate(false, 0, 0, 0, 0, "")
                tile.snapLineUpdate(false, 0, false, 0)

                // Clamp inside canvas bounds
                const p = tile.tileParent
                if (p) {
                    tile.x = Math.max(0, Math.min(p.width - tile.width, tile.x))
                    tile.y = Math.max(0, Math.min(p.height - tile.height, tile.y))
                }

                // Convert canvas coords back to real pixel coords
                const newRx = Math.round((tile.x - tile.canvasOffsetX) / tile.canvasScaleF + tile.canvasOrigin.x)
                const newRy = Math.round((tile.y - tile.canvasOffsetY) / tile.canvasScaleF + tile.canvasOrigin.y)
                tile.dragCommitted(tile.monitorInfo.name, newRx, newRy)
            }
        }

        onTranslationChanged: {
            let nx = tile.dragStartX + translation.x
            let ny = tile.dragStartY + translation.y

            const p = tile.tileParent
            if (p) {
                nx = Math.max(-tile.width * 0.4, Math.min(p.width - tile.width * 0.6, nx))
                ny = Math.max(-tile.height * 0.4, Math.min(p.height - tile.height * 0.6, ny))
            }

            let snapped = tile._performMagneticSnap(nx, ny)
            tile.x = snapped.x
            tile.y = snapped.y
        }
    }

    function _performMagneticSnap(rawX, rawY) {
        const reps = tile.allTiles
        if (!reps || reps.count < 2) {
            tile.snapGuideUpdate(false, 0, 0, 0, 0, "")
            tile.snapLineUpdate(false, 0, false, 0)
            return { x: rawX, y: rawY }
        }

        let bestX = rawX, bestY = rawY
        let minXDist = tile.snapThreshold + 1
        let minYDist = tile.snapThreshold + 1
        let snappedHLine = -1, snappedVLine = -1

        for (let i = 0; i < reps.count; i++) {
            const sib = reps.itemAt(i)
            if (!sib || sib === tile) continue

            // Horizontal snap targets (touching edges and axis alignment)
            const xTargets = [
                { pos: sib.x + sib.width,              line: sib.x + sib.width },
                { pos: sib.x - tile.width,             line: sib.x },
                { pos: sib.x,                          line: sib.x },
                { pos: sib.x + sib.width - tile.width, line: sib.x + sib.width }
            ]
            for (let j = 0; j < xTargets.length; j++) {
                const c = xTargets[j]
                const d = Math.abs(rawX - c.pos)
                if (d < minXDist) { minXDist = d; bestX = c.pos; snappedVLine = c.line }
            }

            // Vertical snap targets (touching edges and axis alignment)
            const yTargets = [
                { pos: sib.y + sib.height,                         line: sib.y + sib.height },
                { pos: sib.y - tile.height,                        line: sib.y },
                { pos: sib.y,                                      line: sib.y },
                { pos: sib.y + sib.height - tile.height,           line: sib.y + sib.height },
                { pos: sib.y + (sib.height - tile.height) / 2,     line: sib.y + sib.height / 2 }
            ]
            for (let k = 0; k < yTargets.length; k++) {
                const c = yTargets[k]
                const d = Math.abs(rawY - c.pos)
                if (d < minYDist) { minYDist = d; bestY = c.pos; snappedHLine = c.line }
            }
        }

        const hasSnap = (minXDist <= tile.snapThreshold || minYDist <= tile.snapThreshold)
        tile.snapGuideUpdate(hasSnap, bestX, bestY, tile.width, tile.height, "magnetic")
        tile.snapLineUpdate(minYDist <= tile.snapThreshold, snappedHLine, minXDist <= tile.snapThreshold, snappedVLine)

        return { x: bestX, y: bestY }
    }
}
