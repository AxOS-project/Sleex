# Top Status Bar User Experience

The Sleex Status Bar (`src/share/sleex/modules/bar/Bar.qml`) serves as the primary desktop control center and visual information hub. Positioned at either the top (default) or bottom of the display, it blends workspace switching, active window tracking, global menus, system tray items, and hardware monitors into a clean, unified surface.

---

## Layout & Section Breakdown

The bar is divided into three distinct visual regions:

```
+----------------------------------------------------------------------------------------------------+
| [Workspaces] [App Title / AppMenuBar]  |  [Date & Time Island]  |  [Resources] [Tray] [Status Icons] |
+----------------------------------------------------------------------------------------------------+
       Left Region (Navigation)             Center Region (Clock)          Right Region (System Info)
```

---

## 1. Left Region: Navigation & Applications

### Workspaces Switcher (`Workspaces.qml`)
- **Workspace Dots & Numbers**: Displays available Hyprland workspaces (configurable from 1 to 30 via `Config.options.bar.workspaces.shown`).
- **Dynamic Icon Modes**:
  - **Material Icons Mode**: Displays minimalistic geometric dots and Material symbols for active workspaces.
  - **App Icons Mode**: Pulls the running application's desktop icon into the workspace badge so users immediately know which apps live where.
- **Hold-to-Reveal Numbers**:
  - Holding down the `SUPER` key reveals workspace numbers (1, 2, 3...) in place of icons.
  - The reveal delay is configurable via `Config.options.bar.workspaces.showNumberDelay` (default: 300 ms) to avoid visual flicker during quick shortcut execution.
- **Scroll Switching**: Scrolling the mouse wheel or touchpad over the workspaces area shifts active workspace left or right.

### Active Window Title (`ActiveWindow.qml`)
- Displays the human-readable title or application name of the currently focused window (`ToplevelManager.activeToplevel`).
- Automatically elides and shortens text on narrower screen resolutions (`barShortenScreenWidthThreshold`).
- Can be toggled on or off via Settings (`Config.options.bar.showTitle`).

### Global Application Menu Bar (`AppMenuBar.qml`)
- Integrates a desktop menu bar (File, Edit, View, Help) directly into the status bar:
  - Communicates with running applications using the **DBusMenu** protocol.
  - Falls back to application desktop entry quick actions (e.g., "New Tab", "New Window", "Incognito") if the client application does not export a native DBusMenu.
  - Clicking any menu item opens an animated Material dropdown menu with submenus, keyboard shortcut hints, and separators.

---

## 2. Center Region: The Dynamic Island (`ClockWidget.qml`)

- **Floating Island Styling**: Positioned dead-center of the bar, presenting the current time (`hh:mm` or `12h AM/PM`) and formatted date (`dddd, dd/MM`).
- **Interactive Triggers**:
  - **Left Click**: Opens the **Bar Center Drawer** (`BarCenterPopup.qml`).
  - **Right Click / Middle Click**: Can be configured to toggle the Fullscreen Dashboard.
- **Bar Center Drawer (`BarCenterPopup.qml`)**:
  - An elegant popup that drops down from the center island with rounded inverted corner cutouts.
  - Contains a fast **application search field** with instant keyboard focus. Typing immediately filters installed applications without opening full-screen overlays.

---

## 3. Right Region: Hardware & Status Indicators

### System Resource Monitor (`Resources.qml`, `Resource.qml`)
- Real-time hardware utilization widgets with configurable update interval (default: 3000 ms):
  - **CPU Utilization**: Live percentage load with color thresholds.
  - **Memory (RAM)**: Percentage of active physical RAM used.
  - **Swap Usage**: Monitored when swap space is utilized.
  - **Disk Capacity**: Root filesystem storage gauge.
- Can be toggled via `Config.options.bar.showRessources`.

### System Tray (`SysTray.qml`, `SysTrayItem.qml`)
- Implements the **StatusNotifierItem (SNI)** Wayland tray specification.
- **Monochrome Icon Filtering**: Optional filter converts third-party tray icons into clean monochrome symbols matching the theme palette (`Config.options.bar.tray.monochromeIcons`).
- **Pinned vs Overflow Area**:
  - Frequently accessed tray icons stay visible directly on the bar.
  - Secondary or background tray items collapse into an expandable tray menu.
  - Supports whitelist/blacklist inversion via `Config.options.bar.tray.invertPinnedItems`.
- **Right-Click Menus**: Native Wayland context menus rendered using Material styling (`SysTrayMenu.qml`).

### Hardware Status Popups & Toggles
- **Battery Indicator & Popup (`BatteryIndicator.qml`, `BatteryPopup.qml`)**:
  - Live battery charge percentage, charging lightning glyph, and time-to-full/time-to-empty calculations.
  - Clicking opens `BatteryPopup`: displays battery health, energy rate in Watts, power draw, and power profile shortcuts.
- **Bluetooth Indicator & Popup (`BluetoothIndicator.qml`, `BtPopup.qml`)**:
  - Displays connected device icons (headphones, mice, keyboards) and battery levels.
  - Clicking opens a quick connection drawer to connect or disconnect paired devices.
- **Keyboard Layout Indicator (`HyprlandXkbIndicator.qml`)**:
  - Displays current active XKB keyboard layout (e.g. `US`, `FR`, `DE`).
  - Clicking cycles through configured input languages.
- **Notification Indicator (`NotifIndicator.qml`)**:
  - Bell icon with unread badge counter.
  - Clicking opens the notification drawer or dismisses pending toasts.

---

## Bar Presentation Options

Users can customize how the bar integrates with their monitor geometry:

| Option | Configuration Key | UX Effect |
| :--- | :--- | :--- |
| **Bar Position** | `Config.options.bar.bottom` | Moves the entire bar to the bottom edge of the display instead of the top. |
| **Bar Background** | `Config.options.bar.background` | Draws a solid background across the entire screen width instead of floating segmented pills. |
| **Borderless Grouping** | `Config.options.bar.borderless` | Removes individual module card borders for a continuous flat aesthetic. |
| **Auto-Hide** | `Config.options.bar.autoHide` | Automatically slides the bar out of view when not in use. Hovering the screen edge instantly reveals it. |
| **Reserve Space** | `Config.options.bar.reserveSpace` | When auto-hide is enabled, keeps the desktop workspace margin reserved so open windows do not jump or resize when the bar appears. |
