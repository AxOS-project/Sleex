# Overview & Universal Launcher User Experience

The Sleex Overview and Launcher (`src/share/sleex/modules/overview/Overview.qml`) combines a multi-workspace window switcher with an omnibar universal search system.

---

## Invoking & Dismissing

- **Keyboard Trigger**:
  - Tap and release `SUPER` (Windows key) on its own (`quickshell:overviewToggleRelease`).
  - `SUPER + V`: Opens directly into **Clipboard History** mode.
  - `SUPER + ;`: Opens directly into **Emoji Picker** mode.
- **Dismissal**:
  - Press `Escape`.
  - Click on the dark scrim backdrop.
  - Press `Enter` to launch an item or switch window.

---

## 1. Multi-Workspace Window Visualizer (`OverviewWidget.qml`)

When opened, the top half of the screen displays a scaled visual matrix of all active Hyprland workspaces:

- **Live Tiling Grid**:
  - Workspaces are rendered across rows and columns according to `Config.options.overview.numOfRows` (default: 2) and `numOfCols` (default: 5).
  - Shows thumbnail representations of open windows preserving their relative tiling positions and aspect ratios.
- **Window Interaction**:
  - **Left Click Window**: Immediately closes the overview and focuses that window.
  - **Middle Click / Close Button**: Terminates or closes the hovered window directly from the overview.
  - **XWayland Badge**: Displays a subtle indicator for windows running via XWayland translation (`showXwaylandIndicator`).

---

## 2. Universal Search Omnibar (`SearchWidget.qml`)

Positioned directly below the workspace matrix is an omnibar search field. It handles multi-modal queries in real time:

```
+-----------------------------------------------------------------------------------------------+
|  (Search Icon)  Type to search apps, math expressions, /commands, ;clipboard, or :emojis...  |
+-----------------------------------------------------------------------------------------------+
```

### Application Fuzzy Search (Default Mode)
- Typing any text without a prefix performs rapid fuzzy matching against installed desktop applications.
- Results display the official app icon, application name, and brief description.
- Pressing `Enter` launches the highlighted top result.
- Pressing `Down Arrow` or `Up Arrow` navigates through the search results list.

### Quick Actions (`/` Prefix)
Typing the forward slash `/` unlocks command actions built into Sleex:

| Action Command | Syntax | Behavior |
| :--- | :--- | :--- |
| **Set Accent Color** | `/accentcolor #HEX` | Instantly applies a new custom accent color across all shell surfaces. |
| **Dark Theme** | `/dark` | Forces dark mode color generation. |
| **Light Theme** | `/light` | Forces light mode color generation. |
| **Superpaste** | `/superpaste [count][i]` | Pastes the last `N` clipboard entries in sequence using `ydotool` (append `i` for images). |
| **Add Todo** | `/todo [task description]` | Appends a new item to the user's dashboard todo list without opening the dashboard. |
| **Wallpaper Picker** | `/wallpaper` | Opens the visual Wallpaper Selector modal. |
| **Wipe Clipboard** | `/wipeclipboard` | Purges all stored history from `cliphist`. |

### Clipboard History Browser (`;` Prefix or `SUPER + V`)
- Typing `;` or pressing `SUPER + V` switches the search widget into the **Clipboard Browser**:
  - Queries `cliphist` for recent text snippets and copied images.
  - Real-time search filters through copied text contents.
  - Image thumbnails preview copied screenshots or pictures.
  - Pressing `Enter` copies the selected item to the active clipboard buffer and closes the launcher.

### Emoji Picker (`:` Prefix or `SUPER + ;`)
- Typing `:` or pressing `SUPER + ;` activates the **Emoji Search**:
  - Search by emoji keywords (e.g. `:rocket`, `:heart`, `:fire`, `:check`).
  - Displays emoji glyph, unicode identifier, and descriptive title.
  - Selecting an emoji automatically copies it to the clipboard and pastes it into the active window.

### Real-Time Math Calculator
- Any mathematical formula typed into the search bar (e.g. `12 * 8.5`, `sqrt(144) + 2^5`, `15% of 350`) is evaluated in real time via `qalc`:
  - The calculated result appears as the top primary search result.
  - Pressing `Enter` copies the computed answer to your clipboard.

### Fallback Web Search
- If a search query does not match any local desktop application or command:
  - A search suggestion item offers: *"Search on Google: [query]"*.
  - Pressing `Enter` opens the query in the user's default web browser.

---

## Configuration Settings Reference

| Option | Key | Default | Description |
| :--- | :--- | :--- | :--- |
| **Overview Scale** | `Config.options.overview.scale` | `0.18` | Relative scale of workspace previews. |
| **Grid Rows** | `Config.options.overview.numOfRows` | `2` | Number of workspace rows. |
| **Grid Columns** | `Config.options.overview.numOfCols` | `5` | Number of workspace columns. |
| **XWayland Badge** | `Config.options.overview.showXwaylandIndicator` | `true` | Badge distinguishing XWayland clients. |
| **Action Prefix** | `Config.options.search.prefix.action` | `"/"` | Prefix character for system commands. |
| **Clipboard Prefix**| `Config.options.search.prefix.clipboard` | `";"` | Prefix character for clipboard history. |
| **Emoji Prefix** | `Config.options.search.prefix.emojis` | `":"` | Prefix character for emoji search. |
| **Search Engine URL**| `Config.options.search.engineBaseUrl` | Google URL | Web fallback search engine query string. |
