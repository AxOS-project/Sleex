pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.mediaControls
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import "../common/widgets/widgetCanvas"

AbstractWidget {
    id: root

    required property real screenWidth
    required property real screenHeight

    visible: Config.options.background.enableMediaWidget ?? true
    draggable: true

    implicitWidth: Appearance.sizes.mediaControlsWidth
    implicitHeight: Appearance.sizes.mediaControlsHeight

    x: (Config.options.background.mediaX || (screenWidth / 2)) - implicitWidth / 2
    y: (Config.options.background.mediaY || (screenHeight / 2 + 160)) - implicitHeight / 2

    function commitPosition() {
        Config.options.background.mediaX = root.x + root.implicitWidth / 2
        Config.options.background.mediaY = root.y + root.implicitHeight / 2
    }

    StyledRectangularShadow {
        target: mediaControls
        z: -1
    }

    MediaControls {
        id: mediaControls
        anchors.fill: parent
    }
}
