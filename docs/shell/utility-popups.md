# Utility Popups, Cheatsheet & Tools User Experience

Sleex includes a suite of built-in productivity tools and graphical system prompts designed to eliminate third-party popups (`src/share/sleex/modules/cornerPopup/`, `modules/cheatsheet/`, `modules/wallpaperSelector/`, `modules/polkit/`).

---

## 1. Corner Utility Drawer (`modules/cornerPopup/CornerPopup.qml`)

Anchored discreetly to the bottom-left corner of the display, the Corner Popup is a slide-out productivity tool that remains completely out of the way until needed.

```
+-------------------------------------------------------------+
|  [Pomodoro Focus Timer]  |  [Stopwatch with Laps]           |
|                                                             |
|                          25 : 00                            |
|                       Focus Session                         |
|                                                             |
|           [ ▶ Start ]     [ ⏸ Pause ]     [ 🔄 Reset ]      |
+-------------------------------------------------------------+
(Bottom-Left Screen Edge Hotspot)
```

### Reveal Interaction
- **Mouse Hotspot**: Hovering over the small 20x20 pixel area in the bottom-left corner smoothly slides out a 500x350 pixel card with rounded corners.
- Moving the mouse away immediately collapses the drawer back into the screen edge.

### Tab 1: Pomodoro Timer (`PomodoroTab.qml`, `PomodoroWidget.qml`)
- **Focus Sessions & Breaks**: Tracks standard 25-minute focus intervals and 5-minute break cycles.
- **Controls**:
  - Start, Pause, and Reset buttons.
  - Cycle counter tracking completed sessions.
  - Desktop notification alerts when a work interval or break finishes.

### Tab 2: Precision Stopwatch (`StopwatchTab.qml`, `StopwatchWidget.qml`)
- **Millisecond Timer**: Start, pause, and zero out a precise elapsed-time counter.
- **Lap Tracking**: Clicking "Lap" records split times into a scrollable list, highlighting fastest and slowest laps.

---

## 2. Keyboard Shortcuts Cheatsheet (`modules/cheatsheet/Cheatsheet.qml`)

Sleex provides an interactive graphical keybind helper to make Hyprland tiling and shortcuts easy to discover.

### Invocation & Navigation
- **Shortcut**: `SUPER + F1` (`quickshell:cheatsheetToggle`).
- **Dismissal**: Press `Escape` or click anywhere on the background.

```
+---------------------------------------------------------------------------------------------------+
|                                 Sleex Keyboard Shortcuts Cheatsheet                               |
|                                                                                                   |
|  [Shell Dispatcher]              [Window Management]               [Workspaces & Nav]            |
|  SUPER ......... App Launcher    SUPER + Q ....... Close Window    SUPER + 1..10 ... Switch Work |
|  SUPER + D ..... Dashboard       SUPER + F ....... Fullscreen      SUPER + Arrow ... Move Window |
|  SUPER + V ..... Clipboard       SUPER + Space ... Toggle Float    CTRL+SUPER+Arrow  Focus Dir   |
|  SUPER + ; ..... Emoji Picker    SUPER + Left .... Move Window     SUPER + Scroll .. Cycle Work  |
|  SUPER + T ..... Wallpapers      SUPER + Drag .... Drag Window                                   |
+---------------------------------------------------------------------------------------------------+
```

- **Dynamic Categorization**: Keybinds are parsed from `/etc/sleex/hyprland/keybinds.lua` into clean categories:
  - **Shell Dispatcher**: Desktop overlays, menus, and launchers.
  - **Window Management**: Closing, floating, tiling, and resizing windows.
  - **Workspace Navigation**: Direct jumps, window movement, and monitor shifts.
  - **Multimedia & Tools**: Screenshots, screen recording, color pickers, and audio controls.

---

## 3. Visual Wallpaper Selector (`modules/wallpaperSelector/WallpaperSelector.qml`)

The Wallpaper Selector is a visual browser for local wallpapers and online photo collections.

### Invocation
- **Shortcut**: `SUPER + T` (`quickshell:wppselectorToggle`).
- **Overview Action**: `/wallpaper`.
- **Desktop Context Menu**: Right-click desktop -> "Change Wallpaper".

```
+---------------------------------------------------------------------------------------------------+
|  [📁 Local Wallpapers]  |  [🌐 Unsplash Online Search]             [ Search wallpapers...       ] |
|                                                                                                   |
|  +--------------------+  +--------------------+  +--------------------+  +--------------------+   |
|  | [Thumbnail 1]      |  | [Thumbnail 2]      |  | [Thumbnail 3]      |  | [Thumbnail 4]      |   |
|  | Mountain Lake      |  | Cyberpunk Neon     |  | Abstract Waves     |  | Minimalist Dark    |   |
|  +--------------------+  +--------------------+  +--------------------+  +--------------------+   |
+---------------------------------------------------------------------------------------------------+
```

### Local Wallpapers Tab
- Displays a grid of thumbnail previews for all images and videos found in the wallpapers directory (`/usr/share/backgrounds/sleex/` or custom user folder).
- Clicking any thumbnail applies the wallpaper immediately with the active transition animation and triggers color palette extraction.

### Unsplash Online Tab
- Search millions of high-resolution wallpapers directly using the Unsplash API.
- Filter by keywords (nature, architecture, abstract, minimalism).
- Clicking an Unsplash thumbnail automatically downloads the full-resolution image to `~/Pictures/Sleex Wallpapers/Unsplash/`, applies it to the desktop, and recalculates system colors.

---

## 4. Polkit Authentication Dialog (`modules/polkit/Polkit.qml`)

When an administrative task requires elevated root privileges (such as managing disk partitions, installing system packages, or updating SDDM avatars), Sleex displays a native Polkit dialog:

```
+--------------------------------------------------------------------------+
|  🛡️ <b>Authentication Required</b>                                       |
|  System policy requires authentication to execute:                       |
|  <i>/usr/bin/package-manager</i>                                         |
|                                                                          |
|  User: ardox                                                             |
|  Password: [ •••••••••••••••••••••• ]                                    |
|                                                                          |
|                     [ Cancel ]    [ Authenticate ]                       |
+--------------------------------------------------------------------------+
```

- **Seamless Theming**: Adheres to the Material 3 surface elevation, color palette, and font styling rather than falling back to standard GNOME or KDE Polkit agents.
- **Interactive Validation**: Shows real-time spinner feedback while verifying credentials; incorrect password entry shakes the dialog and displays clear error feedback.
