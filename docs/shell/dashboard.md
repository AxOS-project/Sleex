# Fullscreen Dashboard & Bento Grid User Experience

The Sleex Dashboard (`src/share/sleex/modules/dashboard/Dashboard.qml`) is a full-featured, modular overlay providing instant access to personal widgets, system quick toggles, task lists, calendar agendas, and hardware controls.

---

## Invoking & Dismissing the Dashboard

- **Keyboard Shortcut**: `SUPER + D` (toggles open/close).
- **Mouse Action**: Clicking the clock island or status bar trigger.
- **Dismissal**:
  - Pressing `Escape`.
  - Clicking anywhere on the transparent backdrop outside the dashboard card.
- **Entrance & Exit Animations**:
  - The dashboard card smoothly animates in from a user-configured direction (`up`, `down`, `left`, `right`) with adjustable speed (`animationDuration`).

---

## Dashboard Header & Quick Controls

The top header of the dashboard features a system status bar and essential quick controls:

```
+---------------------------------------------------------------------------------------------------+
| [Distro Logo] Uptime: 2d 4h 12m | (Customize) (Reload) (Settings) (Session) | [Wi-Fi] [BT] [Night] [Idle] |
+---------------------------------------------------------------------------------------------------+
```

### 1. System Information
- **Distribution Badge**: Displays the active OS emblem (AxOS, Arch, Fedora, NixOS, Debian, etc.).
- **Uptime Counter**: Live counter formatted cleanly via `DateTime.uptime`.

### 2. Header Utility Buttons
- **Bento Layout Customizer** (`dashboard_customize`): Enters interactive drag-and-drop edit mode for the Bento widget grid.
- **Reload Desktop** (`restart_alt`): Reloads Hyprland and Quickshell configs without closing open windows.
- **Open Settings** (`settings`): Launches the Sleex Settings application.
- **Session Actions** (`power_settings_new`): Triggers the power/shutdown confirmation overlay.

### 3. Quick Toggles Group (`quickToggles/`)
Compact pill buttons with real-time state feedback and tooltips:
- **Network Toggle (`NetworkToggle.qml`)**: Toggles Wi-Fi or displays active SSID and connection state.
- **Bluetooth Toggle (`BluetoothToggle.qml`)**: Master toggle for Bluetooth adapter power.
- **Night Light (`NightLight.qml`)**: Toggles the blue light temperature filter.
- **Idle Inhibitor (`IdleInhibitor.qml`)**: Prevents the screen from dimming or sleeping during presentations or downloads.
- **Game Mode (`GameMode.qml`)**: Suppresses background notifications and locks idle timers for gaming sessions.

---

## Modular Bento Grid System (`bento/`)

The **Home** view of the dashboard is built on a responsive 10-row grid layout powered by `BentoModel` and `BentoWidgetRegistry.qml`.

### Interactive Customization Mode
Clicking the `dashboard_customize` button in the header enters edit mode:
- **Drag-and-Drop Repositioning**: Click and hold the drag handle on any widget to move it into another slot.
- **Drop Placeholders**: Clear visual drop targets show valid snap positions.
- **Widget Sizing Presets**: Use predefined grid spans (e.g., `1x2`, `1x3`, `2x2`, `2x4`, `1x10`) to customize layout proportions.
- **Add / Remove Widgets**: Toggle widgets on and off using the customization drawer (`BentoCustomizeBar.qml`).

### Bento Widgets Breakdown

```
+-----------------------+--------------------------+-----------------------+
|  User Profile (1x4)   |                          |   Media Player (1x2)  |
|                       |                          +-----------------------+
+-----------------------+   Notification Center    |   Weather (1x3)       |
|  Digital Clock (1x2)  |         (1x10)           |                       |
+-----------------------+                          +-----------------------+
|  GitHub Graph (1x4)   |                          |   Calendar Agenda     |
|                       |                          |         (1x5)         |
+-----------------------+--------------------------+-----------------------+
```

1. **User Profile Widget (`HomeUserInfoWidget.qml`)**:
   - Displays user profile avatar, system username, and a personalized description / quote.
   - Configurable in Settings (`Config.options.dashboard.avatarPath`, `userDesc`).
2. **Digital Clock Widget (`HomeClockWidget.qml`)**:
   - Modern large typography digital clock, current seconds ticker, and complete date.
3. **GitHub Heatmap Widget (`HomeGithubWidget.qml`)**:
   - Fetches and displays public GitHub contribution history graph via `ContributionCalendar`.
   - Reacts to username set in `Config.options.dashboard.ghUsername`.
4. **Notification Center (`NotificationList.qml`)**:
   - Chronological list of historical and unread desktop notifications.
   - Grouping by application with expandable threads (`NotificationGroupExpandButton.qml`).
   - "Clear All" button and inline notification action buttons.
5. **Media Player Widget (`MediaControls.qml`)**:
   - Displays current media playing across any MPRIS-compliant player (Spotify, Firefox, mpv, etc.).
   - Album artwork, track name, artist, previous/play/pause/next buttons, and interactive progress scrub bar.
6. **Weather Widget (`HomeWeatherWidget.qml`)**:
   - Real-time weather condition icons, temperature (°C/°F), and forecast powered by Open-Meteo.
7. **Calendar Agenda Widget (`CalendarWidget.qml`)**:
   - Highlights today's date and upcoming scheduled events.

---

## Secondary Dashboard Tabs (`DashboardTabs.qml`)

In addition to the Bento Home tab, users can switch tabs via the top tab bar:

### 1. Todo List Tab (`TodoWidgetGroup.qml`, `TodoWidget.qml`)
- **Add Tasks**: Clean text field to enter new to-do items.
- **Task Management**: Check off completed items, reorder tasks, and remove items with a single click.
- **Persistent Storage**: Tasks persist across reboots via the Sleex database service (`Todo.qml`).

### 2. Calendar & Agenda Tab (`CalendarWidgetGroup.qml`, `CalendarWidget.qml`)
- **Full Monthly Grid**: Interactive month navigation with today highlight.
- **Event Management**: Create, edit, and categorize calendar events with start/end times (`CalendarAdd.qml`, `CalendarEdit.qml`).
- **CalDAV Synchronization**: Integrates with `vdirsyncer` for background two-way syncing with Nextcloud, Google Calendar, or Radicale (`syncInterval` configurable from 1 to 1440 minutes).

---

## Dashboard Configuration Properties

| Option | Key | Default | Description |
| :--- | :--- | :--- | :--- |
| **Dashboard Scale** | `Config.options.dashboard.dashboardScale` | `1.0` | Overall UI scale factor (0.5 to 2.0). |
| **Animation Direction**| `Config.options.dashboard.animationDirection`| `"down"` | Slide-in direction (`up`, `down`, `left`, `right`). |
| **Animation Duration** | `Config.options.dashboard.animationDuration` | `374` | Duration of entrance/exit transitions in ms. |
| **GitHub User** | `Config.options.dashboard.ghUsername` | `"levraiardox"` | Username queried for the contribution heatmap. |
| **Avatar Path** | `Config.options.dashboard.avatarPath` | Pixmap path | Absolute file path or URI to the user avatar image. |
| **User Description** | `Config.options.dashboard.userDesc` | Quote text | Bio / status text displayed on profile card. |
| **Todo List Tab** | `Config.options.dashboard.opt.enableTodo` | `true` | Enable or disable the Todo tab. |
| **Calendar Tab** | `Config.options.dashboard.opt.enableCalendar`| `true` | Enable or disable the Calendar tab. |
