# Lockscreen & Session Controls User Experience

Sleex delivers a secure Wayland screen locker and an integrated session power management system (`src/share/sleex/modules/lockscreen/` and `src/share/sleex/modules/session/`).

---

## 1. The Screen Locker (`modules/lockscreen/`)

The Sleex lockscreen uses the official Wayland `ext-session-lock-v1` protocol via Quickshell's `WlSessionLock`. When locked, unauthorized windows and input are prevented from reaching the compositor.

### Triggering the Lockscreen
- **Shortcut**: `SUPER + L` (calls `quickshell:lockScreen`).
- **Idle Daemon**: Automatically locks upon reaching user-defined idle timeouts (configured in Behavior settings).
- **Session Menu**: Selecting the "Lock" action from the power menu.

```
+-----------------------------------------------------------------------------------------------+
|  10:45 AM                                                                          [Battery]  |
|  Tuesday, October 22                                                                          |
|                                                                                               |
|                                         (User Avatar)                                         |
|                                            ardox                                              |
|                                     [ Enter Password... ]                                     |
|                                    (• Face Auth Active •)                                     |
|                                                                                               |
|                     +---------------------------------------------------+                     |
|                     |  [Album Art]  Song Title - Artist Name            |                     |
|                     |               [Prev] [Pause] [Next]               |                     |
|                     |               "Synced lyric line..."              |                     |
|                     +---------------------------------------------------+                     |
+-----------------------------------------------------------------------------------------------+
```

### Visual & Interactive Elements
1. **Background Scrim & Blur (`LockSurface.qml`)**:
   - The desktop background is displayed with configurable scrim darkening and blur (`Config.options.lockscreen.enableScrim`).
2. **Clock & Date Header**:
   - Large digital clock and current date positioned at the top-left of the display.
3. **Authentication Card**:
   - **User Information**: Displays user avatar and username.
   - **Password Field**: Clean password input field with immediate focus.
   - **Failure Animation**: Incorrect password entry triggers a horizontal shake animation and highlights the input border in error red (`Appearance.colors.colError`).
   - **Escape Action**: Pressing `Escape` clears the entered characters.
4. **Howdy Facial Recognition Integration**:
   - When enabled (`Config.options.lockscreen.enableFaceAuth`), the lockscreen interfaces with the camera via Howdy.
   - A pulsing camera icon indicates active facial scanning. Upon successful face match, the screen unlocks instantly without requiring password entry.
5. **Lockscreen Media Controls**:
   - Active music playback can be controlled directly on the lockscreen (`MprisController`).
   - Shows album art, track title, artist name, and playback buttons.
   - **Synced Lyrics Option**: Can display live scrolling lyrics on the lockscreen (`Config.options.lockscreen.showLyricsOnLockScreen`).
   - **Resizable Widget Option**: Allows resizing and dragging the media player widget to any corner of the lockscreen (`resizableLockScreenWidget`).

---

## 2. Session & Power Actions Menu (`modules/session/Session.qml`)

The Session Menu provides a full-screen, high-contrast overlay for system power states and session termination.

### Triggering the Session Menu
- **Keyboard Shortcut**: `CTRL + ALT + Delete` (`quickshell:sessionToggle`).
- **Hardware Button**: Physical power button press (`quickshell:powerButtonPressed`).
- **Dashboard Button**: Clicking the power button icon in the dashboard header.

```
+-----------------------------------------------------------------------------------------------+
|                                                                                               |
|                                     System Power Options                                      |
|                             Select an action to proceed or Escape                             |
|                                                                                               |
|     [ 🔒 Lock ]   [ 💤 Suspend ]   [ ❄️ Hibernate ]   [ 🔄 Restart ]   [ ⚡ Power Off ]   [ 🚪 Log Out ]     |
|                                                                                               |
+-----------------------------------------------------------------------------------------------+
```

### Available Actions

| Action | Icon | Behavior | Confirmation Required? |
| :--- | :--- | :--- | :--- |
| **Lock** | `lock` | Activates the Wayland session lockscreen. | No (immediate) |
| **Suspend** | `bedtime` | Puts the computer into low-power sleep mode via `systemctl suspend`. | No (immediate) |
| **Hibernate** | `mode_heat` | Saves RAM state to disk and powers down via `systemctl hibernate`. | No (immediate) |
| **Restart** | `restart_alt` | Reboots the system via `systemctl reboot`. | **Yes** (Safety modal) |
| **Power Off** | `power_settings_new`| Shuts down the machine cleanly via `systemctl poweroff`. | **Yes** (Safety modal) |
| **Log Out** | `logout` | Terminates the active Hyprland session and returns to the display manager. | **Yes** (Safety modal) |

### Confirmation Guards (`PowerConfirmContent.qml`)
To prevent accidental reboots or data loss during active work:
- Selecting **Restart**, **Power Off**, or **Log Out** switches the session menu into a secondary confirmation card.
- The confirmation dialog clearly displays the target action with "Confirm" (accent color) and "Cancel" buttons.
- Pressing `Escape` or clicking outside the card cancels the pending action and dismisses the menu.
