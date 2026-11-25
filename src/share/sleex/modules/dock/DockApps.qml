import qs
import qs.services
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance
import Sleex.Fhtc
import Sleex.Widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

Item {
    id: root
    property real maxWindowPreviewHeight: 200
    property real maxWindowPreviewWidth: 300
    property real windowControlsHeight: 30

    property Item lastHoveredButton
    property bool buttonHovered: false
    property bool requestDockShow: previewPopup.show

    // Only refresh the dock when the pinned list's content actually changes (fix animation happening on every desktop change)
    property var pinnedAppsStable: []
    readonly property string pinnedAppsKey: JSON.stringify(Config.options?.dock.pinnedApps ?? [])
    onPinnedAppsKeyChanged: pinnedAppsStable = Config.options?.dock.pinnedApps ?? []
    Component.onCompleted: pinnedAppsStable = Config.options?.dock.pinnedApps ?? []

    Layout.fillHeight: true
    Layout.topMargin: Appearance.sizes.hyprlandGapsOut
    implicitWidth: listView.implicitWidth

    StyledListView {
        id: listView
        spacing: 2
        orientation: ListView.Horizontal
        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        implicitWidth: contentWidth

        Behavior on implicitWidth {
            animation: NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        model: ScriptModel {
            objectProp: "appId"
            values: {
                var map = new Map();

                // Pinned apps
                const pinnedApps = root.pinnedAppsStable;
                for (const appId of pinnedApps) {
                    if (!map.has(appId.toLowerCase())) map.set(appId.toLowerCase(), ({
                        pinned: true,
                        toplevels: []
                    }));
                }

                // Separator
                if (pinnedApps.length > 0) {
                    map.set("SEPARATOR", { pinned: false, toplevels: [] });
                }

                // Open windows from fht-compositor IPC
                for (const win of Object.values(FhtcWorkspaces.windows ?? {})) {
                    const rawAppId = win["app-id"] ?? "";
                    if (!rawAppId)
                        continue;
                    const key = rawAppId.toLowerCase();
                    if (!map.has(key)) map.set(key, ({
                        pinned: false,
                        toplevels: []
                    }));
                    map.get(key).toplevels.push(win);
                }

                var values = [];

                for (const [key, value] of map) {
                    values.push({ appId: key, toplevels: value.toplevels, pinned: value.pinned });
                }

                return values;
            }
        }
        delegate: DockAppButton {
            required property var modelData
            appToplevel: modelData
            appListRoot: root
        }
    }

    PopupWindow {
        id: previewPopup
        property var appTopLevel: root.lastHoveredButton?.appToplevel
        property bool allPreviewsReady: false
        readonly property bool hoverConditions: popupMouseArea.containsMouse || root.buttonHovered
        readonly property bool previewActive: visible || hoverConditions
        onPreviewActiveChanged: {
            if (!previewActive) {
                updateTimer.stop();
                show = false;
                allPreviewsReady = false;
                if (root.lastHoveredButton) {
                    root.lastHoveredButton = null;
                }
            }
        }
        Connections {
            target: root
            function onLastHoveredButtonChanged() {
                previewPopup.allPreviewsReady = false;
            }
        }
        function updatePreviewReadiness() {
            if (!previewActive || (appTopLevel?.toplevels?.length ?? 0) === 0) {
                allPreviewsReady = false;
                return;
            }
            for (var i = 0; i < previewRowLayout.children.length; i++) {
                const view = previewRowLayout.children[i];
                if (view.hasContent === false) {
                    allPreviewsReady = false;
                    return;
                }
            }
            allPreviewsReady = true;
        }
        property bool shouldShow: hoverConditions && allPreviewsReady && (appTopLevel?.toplevels?.length ?? 0) > 0
        property bool show: false

        onShouldShowChanged: {
            updateTimer.restart();
        }
        Timer {
            id: updateTimer
            interval: 100
            onTriggered: {
                previewPopup.show = previewPopup.shouldShow
            }
        }
        anchor {
            window: root.QsWindow.window
            adjustment: PopupAdjustment.None
            gravity: Edges.Top | Edges.Right
            edges: Edges.Top | Edges.Left
        }
        visible: previewPopup.show || popupBackground.opacity > 0
        color: "transparent"
        implicitWidth: root.QsWindow.window?.width ?? 1
        implicitHeight: popupMouseArea.implicitHeight + root.windowControlsHeight + Appearance.sizes.elevationMargin * 2

        MouseArea {
            id: popupMouseArea
            anchors.bottom: parent.bottom
            implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
            implicitHeight: root.maxWindowPreviewHeight + root.windowControlsHeight + Appearance.sizes.elevationMargin * 2
            hoverEnabled: true
            x: {
                if (!root.lastHoveredButton || !root.QsWindow?.window) return 0;
                const itemCenter = root.QsWindow.mapFromItem(root.lastHoveredButton, root.lastHoveredButton.width / 2, 0);
                return itemCenter ? itemCenter.x - width / 2 : 0;
            }
            StyledRectangularShadow {
                target: popupBackground
                opacity: previewPopup.show ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
            }
            Rectangle {
                id: popupBackground
                property real padding: 5
                opacity: previewPopup.show ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
                clip: true
                color: Appearance.colors.colSurfaceContainer
                radius: Appearance.rounding.normal
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.sizes.elevationMargin
                anchors.horizontalCenter: parent.horizontalCenter
                implicitHeight: previewRowLayout.implicitHeight + padding * 2
                implicitWidth: previewRowLayout.implicitWidth + padding * 2
                Behavior on implicitWidth {
                    enabled: previewPopup.visible
                    animation: NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
                Behavior on implicitHeight {
                    enabled: previewPopup.visible
                    animation: NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                RowLayout {
                    id: previewRowLayout
                    anchors.centerIn: parent
                    Repeater {
                        model: ScriptModel {
                            values: previewPopup.previewActive ? (previewPopup.appTopLevel?.toplevels ?? []) : []
                        }
                        RippleButton {
                            id: windowButton
                            required property var modelData
                            readonly property alias hasContent: screencopyView.hasContent
                            padding: 0
                            middleClickAction: () => {
                                if (windowButton.modelData?.id !== undefined) {
                                    FhtcIpc.dispatch("close-window", { "window-id": windowButton.modelData.id, "kill": false });
                                }
                            }
                            onClicked: {
                                if (windowButton.modelData?.id !== undefined) {
                                    FhtcIpc.dispatch("focus-window", { "window-id": windowButton.modelData.id });
                                }
                            }
                            contentItem: ColumnLayout {
                                implicitWidth: screencopyView.implicitWidth
                                implicitHeight: screencopyView.implicitHeight

                                ButtonGroup {
                                    contentWidth: parent.width - anchors.margins * 2
                                    WrapperRectangle {
                                        Layout.fillWidth: true
                                        color: ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                        radius: Appearance.rounding.small
                                        margin: 5
                                        StyledText {
                                            Layout.fillWidth: true
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            text: windowButton.modelData?.title ?? ""
                                            elide: Text.ElideRight
                                            color: Appearance.m3colors.m3onSurface
                                        }
                                    }
                                    GroupButton {
                                        id: closeButton
                                        colBackground: ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                        baseWidth: windowControlsHeight
                                        baseHeight: windowControlsHeight
                                        buttonRadius: Appearance.rounding.full
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "close"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: Appearance.m3colors.m3onSurface
                                        }
                                        onClicked: {
                                            if (windowButton.modelData?.id !== undefined) {
                                                FhtcIpc.dispatch("close-window", { "window-id": windowButton.modelData.id, "kill": false });
                                            }
                                        }
                                    }
                                }
                                ExtCaptureItem {
                                    id: screencopyView
                                    windowId: previewPopup.previewActive ? (windowButton.modelData?.["foreign-handle"] ?? "") : ""
                                    active: previewPopup.previewActive && windowId !== ""
                                    constraintSize: Qt.size(root.maxWindowPreviewWidth, root.maxWindowPreviewHeight)
                                    onHasContentChanged: {
                                        if (hasContent)
                                            previewPopup.updatePreviewReadiness();
                                    }
                                    layer.enabled: screencopyView.hasContent && screencopyView.width > 0 && screencopyView.height > 0
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: screencopyView.width
                                            height: screencopyView.height
                                            radius: Appearance.rounding.small
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
