import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import Sleex.Services

ContentSection {
    id: root

    property string selectedMonitorName: ""
    property var    pendingChanges: null
    property bool   isSyncing: false

    readonly property var currentMon: {
        if (!Monitors.monitors || root.selectedMonitorName === "") return null
        return Monitors.monitors.find(m => m.name === root.selectedMonitorName) || null
    }

    readonly property double currentScale: {
        if (pendingChanges && pendingChanges.map[root.selectedMonitorName] && pendingChanges.map[root.selectedMonitorName].scale !== undefined)
            return pendingChanges.map[root.selectedMonitorName].scale
        return currentMon ? currentMon.scale : 1.0
    }

    readonly property string currentMode: {
        if (pendingChanges && pendingChanges.map[root.selectedMonitorName] && pendingChanges.map[root.selectedMonitorName].mode !== undefined)
            return pendingChanges.map[root.selectedMonitorName].mode
        return currentMon ? (currentMon.width + "x" + currentMon.height) : ""
    }

    readonly property string currentMirror: {
        if (pendingChanges && pendingChanges.map[root.selectedMonitorName] && pendingChanges.map[root.selectedMonitorName].mirror !== undefined)
            return pendingChanges.map[root.selectedMonitorName].mirror
        return currentMon ? currentMon.mirrorOf : ""
    }

    readonly property var availableModesList: {
        if (!currentMon) return []
        let modes = currentMon.availableModes ? [...currentMon.availableModes] : []
        const cur = currentMon.width + "x" + currentMon.height
        if (cur !== "0x0" && cur !== "" && modes.indexOf(cur) === -1) {
            modes.unshift(cur)
        }
        return modes
    }

    readonly property var availableMirrorList: {
        const others = (Monitors.monitors || [])
            .filter(m => m.name !== root.selectedMonitorName)
            .map(m => m.name)
        return [qsTr("Extend (None)"), ...others]
    }

    function syncControls() {
        if (!currentMon) return
        isSyncing = true

        const targetScale = Math.round(currentScale * 100)
        if (scaleSpinBox.value !== targetScale) {
            scaleSpinBox.value = targetScale
        }

        const modes = availableModesList
        if (modes.length > 0) {
            const modeIdx = modes.indexOf(currentMode)
            resCombo.currentIndex = (modeIdx >= 0) ? modeIdx : 0
        }

        const mirrors = availableMirrorList
        if (mirrors.length > 0) {
            const mirrorIdx = currentMirror ? mirrors.indexOf(currentMirror) : 0
            mirrorCombo.currentIndex = (mirrorIdx >= 0) ? mirrorIdx : 0
        }

        isSyncing = false
    }

    Component.onCompleted: syncControls()
    onSelectedMonitorNameChanged: syncControls()
    onCurrentMonChanged: syncControls()
    onCurrentScaleChanged: syncControls()
    onCurrentModeChanged: syncControls()
    onCurrentMirrorChanged: syncControls()

    Connections {
        target: root.currentMon
        function onChanged() {
            root.syncControls()
        }
    }

    Connections {
        target: root.pendingChanges
        function onMapChanged() {
            root.syncControls()
        }
    }

    Connections {
        target: Monitors
        function onMonitorsChanged() {
            root.syncControls()
        }
    }

    visible: currentMon !== null
    title: currentMon
           ? ((currentMon.model && currentMon.model.length > 0 ? currentMon.model : currentMon.name) + " (" + currentMon.name + ")")
           : qsTr("Display Configuration")
    icon: "tune"

    // 1. Scale
    ConfigSpinBox {
        id: scaleSpinBox
        text: qsTr("Scale (%)")
        from: 25
        to: 300
        stepSize: 25
        value: Math.round(root.currentScale * 100)
        onValueChanged: {
            if (root.isSyncing || !root.currentMon) return
            const newScale = value / 100.0
            if (Math.abs(root.currentScale - newScale) > 0.001) {
                if (root.pendingChanges) root.pendingChanges.setScale(root.selectedMonitorName, newScale)
            }
        }
    }

    // 2. Resolution
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        StyledText {
            text: qsTr("Resolution")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSecondaryContainer
            Layout.fillWidth: true
        }

        IconComboBox {
            id: resCombo
            icon: "tv"
            model: root.availableModesList
            onModelChanged: root.syncControls()
            onActivated: (index) => {
                if (root.isSyncing || !root.currentMon || !model || index < 0 || index >= model.length) return
                const selectedMode = model[index]
                if (selectedMode !== root.currentMode) {
                    if (root.pendingChanges) root.pendingChanges.setMode(root.selectedMonitorName, selectedMode)
                }
            }
        }
    }

    // 3. Mirroring
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        StyledText {
            text: qsTr("Mirror Display")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSecondaryContainer
            Layout.fillWidth: true
        }

        IconComboBox {
            id: mirrorCombo
            icon: "tv_displays"
            model: root.availableMirrorList
            onModelChanged: root.syncControls()
            onActivated: (index) => {
                if (root.isSyncing || !root.currentMon || !model || index < 0 || index >= model.length) return
                const target = (index === 0) ? "" : model[index]
                if (root.currentMirror !== target) {
                    if (root.pendingChanges) root.pendingChanges.setMirror(root.selectedMonitorName, target)
                }
            }
        }
    }
}
