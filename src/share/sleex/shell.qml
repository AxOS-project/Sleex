//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// Adjust this to make the shell smaller or larger
//@ pragma Env QT_SCALE_FACTOR=Config.options.appearance.shellScale

import qs.modules.common
import qs.modules.bar
import qs.modules.cheatsheet
import qs.modules.dock
import qs.modules.mediaControls
import qs.modules.notificationPopup
import qs.modules.onScreenDisplay
import qs.modules.overview
import qs.modules.polkit
import qs.modules.screenCorners
import qs.modules.session
import qs.modules.dashboard
import qs.modules.sidebarLeft
import qs.modules.wallpaperSelector
import qs.modules.background
import qs.modules.lockscreen

import Quickshell
import QtQuick
import QtQuick.Controls
import qs.services

ShellRoot {
    // Enable/disable modules here. False = not loaded at all, so rest assured
    // no unnecessary stuff will take up memory if you decide to only use, say, the overview.
    property bool enableBar: true
    property bool enableCheatsheet: true
    property bool enableDock: true
    property bool enableMediaControls: true
    property bool enableNotificationPopup: true
    property bool enableOnScreenDisplayBrightness: false
    property bool enableOnScreenDisplayVolume: false
    property bool enableOverview: true
    property bool enablePolkit: true
    property bool enableReloadPopup: true
    property bool enableScreenCorners: false
    property bool enableSession: true
    property bool enableSidebarLeft: false
    property bool enableDashboard: true
    property bool enableWallSelector: true
    property bool enableBackground: true

    // Force initialization of some singletons
    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        PersistentStateManager.loadStates()
        Cliphist.refresh()
        FirstRunExperience.load()
    }

    LazyLoader { active: enableBar; component: Bar {} }
    LazyLoader { active: enableCheatsheet; component: Cheatsheet {} }
    LazyLoader { active: enableDock && Config.options.dock.enabled; component: Dock {} }
    LazyLoader { active: enableMediaControls; component: MediaControls {} }
    LazyLoader { active: enableNotificationPopup; component: NotificationPopup {} }
    LazyLoader { active: enableOnScreenDisplayBrightness; component: OnScreenDisplayBrightness {} }
    LazyLoader { active: enableOnScreenDisplayVolume; component: OnScreenDisplayVolume {} }
    LazyLoader { active: enableOverview; component: Overview {} }
    LazyLoader { active: enablePolkit; component: Polkit {} }
    LazyLoader { active: enableReloadPopup; component: ReloadPopup {} }
    LazyLoader { active: enableScreenCorners; component: ScreenCorners {} }
    LazyLoader { active: enableSession; component: Session {} }
    LazyLoader { active: enableSidebarLeft; component: SidebarLeft {} }
    LazyLoader { active: enableDashboard; component: Dashboard {} }
    LazyLoader { active: enableWallSelector; component: WallpaperSelector {} }
    LazyLoader { active: enableBackground; component: Background {} }
    LazyLoader { active: GlobalStates.screenLocked; component: Lock {}}
}
