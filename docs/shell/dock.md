# Application Dock User Experience

The Sleex Application Dock (`src/share/sleex/modules/dock/Dock.qml`) provides a sleek, floating macOS/iPadOS-inspired app launcher and task switcher resting at the bottom of the active display.

---

## Visual Design & Geometry

The dock is rendered as an elevated floating pill with rounded corners, subtle outline stroke, and surface elevation shadowing:

- **Configurable Dimensions**:
  - Dock height: `Config.options.dock.height` (default: 60 px).
  - Hover trigger threshold: `Config.options.dock.hoverRegionHeight` (default: 3 px).
- **Responsive Item Spacing**:
  - Pinned applications and active running windows are organized neatly with horizontal spacing and smooth hover scale feedback.

---

## Application Elements & Indicators

```
+-----------------------------------------------------------------------------------------+
|  [Files]  [Terminal]  [Browser]  |  (Separator)  |  [Editor *]  [Music *]  [Settings *] |
+-----------------------------------------------------------------------------------------+
        Pinned Applications                              Running App Instances
```

### Pinned Applications (`DockApps.qml`, `DockAppButton.qml`)
- Configured via `Config.options.dock.pinnedApps` (e.g. `["pcmanfm-qt", "foot", "firefox"]`).
- Clicking a pinned application launches the program if it is not running, or focuses its primary window if already open.
- Hovering an icon scales the icon slightly and displays a Material tooltip with the application name.

### Running App Indicators
- Applications currently open on any workspace appear on the right side of the dock separator (`DockSeparator.qml`).
- Visual indicator dots below the icon indicate how many windows are active for that application.
- The currently focused active application receives an accent color indicator highlight.

### Context Actions
- **Right-Click Menu**: Allows users to:
  - Open a new window / instance.
  - Pin or unpin the application from the dock.
  - Quit or force-close the running application.

---

## Visibility & Reveal Behaviors

The dock supports three distinct modes of operation:

### 1. Pinned on Startup (`Config.options.dock.pinnedOnStartup`)
- When set to `true`, the dock reserves an exclusive bottom margin (`exclusiveZone`) on the display.
- Tiled application windows in Hyprland automatically avoid overlapping the dock.

### 2. Hover-to-Reveal (`Config.options.dock.hoverToReveal`)
- The dock slides down off-screen, leaving an invisible 3 px trigger region at the bottom edge.
- Moving the cursor to the bottom edge smoothly animates the dock into view using a fast bezier spring animation (`elementMoveFast`).
- Moving the mouse away automatically retracts the dock after a brief delay.

### 3. Smart Reveal on Empty Workspace
- When `hoverToReveal` is disabled and the dock is unpinned, Sleex detects whether the current workspace contains any focused windows (`!ToplevelManager.activeToplevel?.activated`).
- If the workspace is empty (viewing only the desktop wallpaper), the dock stays visible automatically.
- When an application window takes focus, the dock gracefully hides to maximize usable screen real estate.

---

## Configuration Settings Reference

| Option | Key | Default | Description |
| :--- | :--- | :--- | :--- |
| **Enable Dock** | `Config.options.dock.enabled` | `true` | Master switch to enable or disable the dock module entirely. |
| **Dock Height** | `Config.options.dock.height` | `60` | Vertical size of the dock bar in pixels. |
| **Hover Reveal** | `Config.options.dock.hoverToReveal` | `false` | Slide out upon cursor reaching the bottom screen edge. |
| **Pinned on Startup** | `Config.options.dock.pinnedOnStartup` | `false` | Keep dock persistently visible and reserve screen margins. |
| **Hover Region** | `Config.options.dock.hoverRegionHeight` | `3` | Height of the sensitive edge zone triggering auto-reveal. |
| **Pinned Apps** | `Config.options.dock.pinnedApps` | `["pcmanfm-qt", "foot", "firefox"]` | List of desktop entry IDs pinned to the dock. |
