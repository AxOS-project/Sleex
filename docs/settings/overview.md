# Settings Center Architecture & Navigation Overview

The Sleex Settings Center is a standalone desktop application providing centralized control over various system and desktop configurations. 

---

## Launching Settings

- **Shortcut Key**: Press `Super + I` to open the settings window.
- **Terminal / Script**: Execute `qs -p /usr/share/sleex/settings.qml`.
- **Dashboard Button**: Click the settings gear icon in the Fullscreen Dashboard header.
- **Desktop Context Menu**: Right-click the desktop wallpaper and select "Settings".

---

## Window Structure & Navigation

The settings interface follows a modern two-pane master-detail layout:

![settings](../assets/settings.png)

### 1. User Header
- Located at the top of the sidebar.
- Displays the user's profile avatar, system username, and uptime.

### 2. Sidebar Navigation
The sidebar organizes configuration into 11 distinct sections separated by subtle category dividers:

| Page Name | Icon | Category | QML Component |
| :--- | :--- | :--- | :--- |
| **Style** | `palette` | Visuals | `modules/settings/Style.qml` |
| **Interface** | `space_dashboard`| Layout | `modules/settings/Interface.qml` |
| *Divider* | — | — | — |
| **Behavior** | `settings` | System | `modules/settings/BehaviorConfig.qml` |
| **Sound** | `brand_awareness`| Audio | `modules/settings/Sound.qml` |
| **Bluetooth** | `bluetooth` | Connectivity | `modules/settings/Bluetooth.qml` |
| **Wifi** | `wifi` | Connectivity | `modules/settings/Wifi.qml` |
| **Applications**| `apps` | Software | `modules/settings/Applications.qml` |
| **Display** | `display_settings`| Hardware | `modules/settings/Display.qml` |
| **Security** | `lock` | Authentication| `modules/settings/Security.qml` |
| *Divider* | — | — | — |
| **Privacy** | `lock` | Privacy | `modules/settings/Privacy.qml` |
| **About** | `info` | System Info | `modules/settings/About.qml` |

### 3. Animated Content Loader
When clicking a navigation item, the main view executes a crossfade transition (`switchAnim`):
- Previous page fades out with `elementMoveExit` easing (150 ms).
- Selected page loads asynchronously (`asynchronous: true`) to maintain 60 FPS responsiveness.
- Incoming page fades in with `elementMoveEnter` easing (250 ms).

---

## Reactive Configuration Engine

Sleex utilizes a reactive JSON database architecture rather than static text files:

```mermaid
sequenceDiagram
    participant UI as Settings UI Widget
    participant Adapter as JsonAdapter (Config.options)
    participant DB as DatabaseManager (C++)
    participant File as .db_trigger File
    participant Shell as Desktop Shell (shell.qml)

    UI->>Adapter: User toggles switch / changes value
    Adapter->>DB: DatabaseManager.updateSettingField(...)
    DB->>File: Touches .db_trigger timestamp
    File-->>Shell: FileView.onFileChanged detected
    Shell->>Shell: ObjectUtils.applyToQtObject(...)
    Note over Shell: Shell UI updates instantly without restart!
```

- **Instant Visual Feedback**: Modifying any toggle, slider, or combobox in Settings immediately broadcasts the change to the active desktop shell.
- **Persistent Storage**: All settings are automatically serialized to JSON and persisted to `~/.config/sleex/`.
