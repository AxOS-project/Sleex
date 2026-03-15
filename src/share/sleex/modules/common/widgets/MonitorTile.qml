import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: tile

    required property var   monitorInfo
    required property real  canvasScaleF
    required property point origin
    required property bool  isPending
    required property Item  tileParent
    required property var   allTiles

    property bool isSelected: false

    readonly property bool isMirroring: monitorInfo.mirrorOf !== ""

    signal clicked()

    signal dragCommitted(string name, real cx, real cy)
    // Tell parent to show / hide / move the snap guide
    signal snapGuideUpdate(bool visible, real cx, real cy, real cw, real ch)

    x:      (monitorInfo.x - origin.x) * canvasScaleF
    y:      (monitorInfo.y - origin.y) * canvasScaleF
    width:  monitorInfo.width  * canvasScaleF
    height: monitorInfo.height * canvasScaleF

    property real dragStartX: 0
    property real dragStartY: 0

    Rectangle {
        id: body
        anchors.fill: parent
        radius: 6
        color: dragHandler.active
                ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.22) : tile.isMirroring
                ? Qt.rgba(Appearance.colors.colTertiary.r, Appearance.colors.colTertiary.g, Appearance.colors.colTertiary.b, 0.15) : tile.isPending
                ? Qt.rgba(Appearance.colors.colSecondary.r, Appearance.colors.colSecondary.g, Appearance.colors.colSecondary.b, 0.18) : Appearance.colors.colLayer2

        border.color: dragHandler.active
              ? Appearance.colors.colPrimary
              : tile.isSelected
                ? Appearance.colors.colTertiary
                : tile.isPending
                  ? Appearance.colors.colSecondary
                  : Appearance.colors.colOutlineVariant
        border.width: tile.isSelected ? 3 : 2

        scale: dragHandler.active ? 1.08 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "monitor"
                font.pixelSize: Math.min(tile.width, tile.height) * 0.28
                color: Appearance.colors.colOnLayer2
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: tile.monitorInfo.name + (tile.isPending ? " *" : "")
                font.pixelSize: Math.max(8, Math.min(tile.width, tile.height) * 0.13)
                color: tile.isPending
                       ? Appearance.colors.colSecondary
                       : Appearance.colors.colOnLayer2
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: tile.monitorInfo.width + "×" + tile.monitorInfo.height
                font.pixelSize: Math.max(7, Math.min(tile.width, tile.height) * 0.10)
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: tile.isMirroring
                text: "↔ " + monitorInfo.mirrorOf
                font.pixelSize: Math.max(7, Math.min(tile.width, tile.height) * 0.10)
                color: Appearance.m3colors.m3tertiary
            }
        }
    }

    StyledToolTip {
        extraVisibleCondition: hoverHandler.hovered && !dragHandler.active
        text: [
            tile.monitorInfo.description,
            tile.monitorInfo.width + "×" + tile.monitorInfo.height +
                " @ " + tile.monitorInfo.refreshRate.toFixed(2) + " Hz",
            "Scale: " + tile.monitorInfo.scale.toFixed(2) + "×",
            "Position: " + tile.monitorInfo.x + ", " + tile.monitorInfo.y,
            tile.monitorInfo.primary ? "Primary" : ""
        ].filter(Boolean).join("\n")
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    TapHandler {
        onTapped: tile.clicked()
    }

    DragHandler {
        id: dragHandler
        enabled: !tile.isMirroring
        target: null

        onActiveChanged: {
            if (active) {
                tile.dragStartX = tile.x
                tile.dragStartY = tile.y
                tile.z = 10
            } else {
                tile.z = 0
                tile.snapGuideUpdate(false, 0, 0, 0, 0)

                // Snap to closest snap position if within threshold
                const snap = tile._findBestSnap()
                let finalX = tile.x
                let finalY = tile.y
                if (snap !== null) {
                    finalX = snap.x
                    finalY = snap.y
                    tile.x = finalX
                    tile.y = finalY
                }

                // Clamp inside canvas
                const parent = tile.tileParent
                tile.x = Math.max(0, Math.min(parent.width  - tile.width,  tile.x))
                tile.y = Math.max(0, Math.min(parent.height - tile.height, tile.y))

                tile.dragCommitted(tile.monitorInfo.name, tile.x, tile.y)
            }
        }

        onTranslationChanged: {
            let nx = tile.dragStartX + translation.x
            let ny = tile.dragStartY + translation.y

            // Clamp inside canvas
            const parent = tile.tileParent
            nx = Math.max(0, Math.min(parent.width  - tile.width,  nx))
            ny = Math.max(0, Math.min(parent.height - tile.height, ny))

            tile.x = nx
            tile.y = ny

            const snap = tile._findBestSnap()
            if (snap !== null) {
                tile.snapGuideUpdate(true, snap.x, snap.y, tile.width, tile.height)
            } else {
                tile.snapGuideUpdate(false, 0, 0, 0, 0)
            }
        }
    }

    readonly property int snapPx: 50

    function _findBestSnap() {
        const reps = tile.allTiles
        if (!reps || reps.count < 2) return null

        let best     = null
        let bestDist = tile.snapPx + 1

        for (let i = 0; i < reps.count; i++) {
            const sibling = reps.itemAt(i)
            // itemAt may return the delegate wrapper; look for the tile inside
            if (!sibling || sibling === tile) continue

            const candidates = _snapCandidates(sibling)
            for (let c of candidates) {
                const dist = Math.sqrt((tile.x - c.x) ** 2 + (tile.y - c.y) ** 2)
                if (dist < bestDist) {
                    bestDist = dist
                    best = c
                }
            }
        }
        return best
    }

    function _snapCandidates(sib) {
        return [
            { x: sib.x + sib.width,   y: sib.y                        },
            { x: sib.x - tile.width,  y: sib.y                        },
            { x: sib.x,               y: sib.y - tile.height           },
            { x: sib.x,               y: sib.y + sib.height            },
            { x: sib.x + sib.width,   y: sib.y - tile.height           },
            { x: sib.x + sib.width,   y: sib.y + sib.height            },
            { x: sib.x - tile.width,  y: sib.y - tile.height           },
            { x: sib.x - tile.width,  y: sib.y + sib.height            }, 
        ]
    }
}
