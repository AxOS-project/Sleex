# Notifications, Alerts & On-Screen Displays User Experience

Sleex manages desktop alerts, multimedia adjustments, and hardware warnings through animated transient overlays (`src/share/sleex/modules/notificationPopup/` and `src/share/sleex/modules/onScreenDisplay/`).

---

## 1. Notification Popups (`NotificationPopup.qml`)

Sleex implements a desktop notification daemon conforming to the Desktop Notifications Specification.

### Visual Anatomy
Each incoming toast notification appears as an elevated Material card:

```
+--------------------------------------------------------------------------+
|  [App Icon]  Application Name                                   [Dismiss]|
|  <b>Notification Title</b>                                               |
|  Descriptive message body with full text wrapping and formatting...      |
|  +---------------------------+  +-------------------------------------+  |
|  |  [Action 1: Reply / Open] |  |  [Action 2: Secondary Option]       |  |
|  +---------------------------+  +-------------------------------------+  |
+--------------------------------------------------------------------------+
```

- **App Icon & Source Label**: Displays the sender application's icon and human-readable name.
- **Title & Body**: Bold heading and formatted body text supporting rich text formatting.
- **Action Buttons (`NotificationActionButton.qml`)**: Inline interactive buttons allowing users to respond directly (e.g. "Reply", "Mark as Read", "Accept").
- **Dismiss Interactions**:
  - Clicking the close button.
  - Middle-clicking or flicking/swiping the card away.
  - Automatic timeout based on notification urgency.

### Positioning Options (`Config.options.notifications.position`)
Users can configure which screen corner notifications pop up in:
- `top-right` (Default)
- `top-center`
- `top-left`

---

## 2. On-Screen Displays (OSD)

When hardware volume or monitor brightness is adjusted via keyboard hotkeys or hardware buttons, Sleex displays centered floating OSD pills:

### Volume OSD (`OnScreenDisplayVolume.qml`)
- **Trigger**: `XF86AudioRaiseVolume`, `XF86AudioLowerVolume`, `XF86AudioMute`.
- **Display**:
  - Speaker glyph (reflecting current level or muted state with a strike-through).
  - Smooth progress bar filling horizontally.
  - Percentage text indicator (e.g. `45%`, `MAX (Earbang 85%)`).
- **Hearing Protection Badge**: If the user reaches the configured earbang limit, the bar turns orange to indicate volume capping.

### Brightness OSD (`OnScreenDisplayBrightness.qml`)
- **Trigger**: `XF86MonBrightnessUp`, `XF86MonBrightnessDown`.
- **Display**:
  - Sun / brightness glyph with dynamic rays.
  - Smooth progress bar reflecting display backlight percentage.
- **Auto-Dismiss**: OSD pills fade out automatically after 1000 ms of inactivity (`Config.options.osd.timeout`).

---

## 3. Battery Warnings & Overlays (`BatteryWarningOverlay.qml`)

For laptop devices monitored by `UPower`, Sleex provides progressive alerts to safeguard against battery exhaustion:

```
+--------------------------------------------------------------------------+
|  🔋 Low Battery Warning: 20% remaining                                   |
|  Please plug in your charger soon to avoid interruption.                 |
+--------------------------------------------------------------------------+
```

### Warning Thresholds & Behaviors

| Battery Level | Configuration Key | Default | Shell Alert & Action |
| :--- | :--- | :--- | :--- |
| **Low Warning** | `Config.options.battery.low` | `20%` | Triggers a visual toast notification and status bar indicator color shift to warning yellow. |
| **Critical Warning**| `Config.options.battery.critical` | `5%` | Triggers an urgent notification, audible alert chime, and top-edge warning overlay bar. |
| **Auto-Suspend** | `Config.options.battery.suspend` | `2%` | Automatically suspends the system to prevent data loss or sudden power cutoff. |

### Battery Warning Overlay Bar
- When enabled via `Config.options.battery.overlayEnabled`, reaching critical battery level displays a persistent warning banner along the top of the screen until a power adapter is connected.
- Audible alert chimes can be toggled on/off in Settings via `Config.options.battery.sound`.
