import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledFlickable {
    id: root
    property real breakpoint: 900
    property real columnSpacing: 20
    property real itemSpacing: 20
    readonly property bool wideMode: root.width >= root.breakpoint
    property bool forceSingleColumn: false

    default property alias data: container.data

    clip: true
    contentHeight: container.height

    Item {
        id: container
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            margins: 10
        }
        width: root.width - 20

        onChildrenChanged: Qt.callLater(positionItems)
        onWidthChanged: Qt.callLater(positionItems)
    }

    onWideModeChanged: positionItems()

    function positionItems() {
        const items = []
        for (let i = 0; i < container.children.length; i++)
            items.push(container.children[i])

        const singleColumn = !wideMode || forceSingleColumn || items.length === 1
        const colW = singleColumn
            ? container.width
            : (container.width - columnSpacing) / 2

        if (singleColumn) {
            let y = 0
            items.forEach(item => {
                item.width = colW
                item.x = (container.width - colW) / 2
                item.y = y
                y += item.implicitHeight + itemSpacing
                item.implicitHeightChanged.connect(() => Qt.callLater(positionItems))
            })
            container.height = y - itemSpacing
            return
        }

        let leftY = 0, rightY = 0
        items.forEach(item => {
            item.width = colW
            const goLeft = leftY <= rightY
            item.x = goLeft ? 0 : colW + columnSpacing
            item.y = goLeft ? leftY : rightY
            const advance = item.implicitHeight + itemSpacing
            if (goLeft) leftY += advance
            else        rightY += advance
            item.implicitHeightChanged.connect(() => Qt.callLater(positionItems))
        })
        container.height = Math.max(leftY, rightY) - itemSpacing
    }
}