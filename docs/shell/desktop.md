# Desktop Canvas, Background & Widgets User Experience

The Sleex Desktop Canvas (`src/share/sleex/modules/background/Background.qml`) transforms the desktop into an interactive surface featuring dynamic wallpaper transitions, draggable widgets, desktop icons, and customizable typography.

---

## Dynamic Wallpaper Engine

The background subsystem seamlessly renders both high-resolution static images and animated video wallpapers with cinematic transitions:

### Transition Effects (`Config.options.background.wallpaperTransition`)
When changing wallpapers via the shell, settings, or CLI scripts, Sleex executes smooth animations between the old and new wallpapers:

- **Fade**: Crossfades opacity smoothly between the old and incoming wallpaper.
- **Scale**: Smoothly zooms in the incoming wallpaper from `1.15x` scale down to native `1.0x` while crossfading.
- **Wipe (Left, Right, Up, Down)**: Performs a directional wiping reveal across the display using hardware-accelerated clipping rects.

### Transition Duration
The duration of wallpaper transitions is controlled via `Config.options.background.transitionDuration` (default: 0.5 seconds), adjustable via the animation slider in Settings.

---

## Interactive Desktop Widgets (`WidgetCanvas`)

Positioned directly on the desktop canvas are modular widgets that can be enabled, disabled, and positioned:

```
+-----------------------------------------------------------------------------------------------+
|  [Desktop Icons]                                                                             |
|  📁 Documents                                                        [Desktop Clock]          |
|  📁 Downloads                                                         10:45 AM                |
|  ⚙️ Settings.desktop                                                  Tuesday, October 22      |
|                                                                                               |
|                                                                      [Weather Widget]         |
|  [Sticky Note]                                                        Partly Cloudy • 19°C    |
|  "Deploy Sleex release v2.0"                                                                  |
|                                                                                               |
|                                     [Daily Tech Quote]                                        |
|                     "Talk is cheap. Show me the code. — Linus Torvalds"                       |
|                                                                              [AxOS Watermark] |
+-----------------------------------------------------------------------------------------------+
```

### 1. Desktop Clock Widget (`Clock.qml`)
- **Large Typographic Presentation**: Displays current time and date in bold, elegant typography.
- **Clock Mode**: Choose between `light` (primary accent color) and `dark` (deep tone) via `Config.options.background.clockMode`.
- **Custom Font Selection**: Users can select any font family installed on the system (e.g., *Rubik*, *Inter*, *JetBrains Mono*, *Fira Code*) via `Config.options.background.clockFontFamily`.
- **Smart Alignment**: Automatically aligns text left, center, or right depending on whether it is positioned on the left, center, or right third of the display.

### 2. Live Weather Widget (`WeatherWidget.qml`)
- Positioned on the desktop canvas showing current local temperature and weather condition icons.
- Coordinates saved via `Config.options.background.weatherX` and `weatherY`.

### 3. Sticky Notes (Post-It Widget, `PostIt.qml`)
- On-desktop notepad allowing users to write quick reminders, notes, and scratchpad tasks.
- Can be dragged anywhere across the desktop grid. Contents persist across reboots.

### 4. Community Daily Quote Widget (`Quote.qml`)
- Renders inspiring technology, programming, and open-source quotes on the desktop.
- **Dual Sources** (`Config.options.background.quoteSource`):
  - **Local (0)**: Curated tech quotes written by the AxOS community, stored in `/usr/share/sleex/assets/quotes.json`.
  - **Online (1)**: Dynamically fetched quotes from online API providers.

### 5. AxOS Desktop Watermark (`Watermark.qml`)
- Subtle branded watermark anchored to the bottom-right corner of the canvas.
- Can be toggled on or off via `Config.options.background.showWatermark`.

---

## Desktop Icons & Context Menus (`DesktopIcons.qml`)

Sleex features a desktop file and launcher grid with full mouse interaction:

### Desktop Files & Launchers
- Reads files and folders placed in the user's `~/Desktop` directory.
- Double-clicking an icon opens the file in its default application or launches the program.
- Drag-and-drop icon arrangement with grid snapping.

### Right-Click Context Menus
- **Item Context Menu (`DesktopIconContextMenu.qml`)**:
  - Open / Launch.
  - Open with... (application chooser).
  - Rename file.
  - Move to Trash / Delete.
  - Properties.
- **Desktop Background Context Menu (`BackgroundContextMenu.qml`)**:
  - Right-clicking empty space on the wallpaper brings up quick actions:
    - Change Wallpaper (opens Wallpaper Selector).
    - Open Terminal (`foot`).
    - Open File Manager (`pcmanfm-qt`).
    - Desktop Settings (launches Sleex Settings).
    - Add New Note (spawns a Post-it sticky note).

---

## Desktop Configuration Reference

| Option | Key | Default | Description |
| :--- | :--- | :--- | :--- |
| **Wallpaper Path** | `Config.options.background.wallpaperPath` | Path to image | Current active wallpaper file. |
| **Transition Style** | `Config.options.background.wallpaperTransition` | `"fade"` | Transition type: `fade`, `scale`, `wipe`, `wipe_left`, `wipe_up`, `wipe_down`. |
| **Transition Duration**| `Config.options.background.transitionDuration` | `0.5` | Transition speed in seconds. |
| **Show Clock** | `Config.options.background.enableClock` | `true` | Toggle the desktop clock widget. |
| **Clock Font** | `Config.options.background.clockFontFamily` | `"Rubik"` | Font family applied to clock numerals. |
| **Clock Mode** | `Config.options.background.clockMode` | `"light"` | Palette tone: `"light"` or `"dark"`. |
| **Show Weather** | `Config.options.background.enableWeatherWidget`| `true` | Toggle desktop weather widget. |
| **Show Watermark** | `Config.options.background.showWatermark` | `true` | Toggle AxOS desktop watermark. |
| **Show Quotes** | `Config.options.background.enableQuote` | `true` | Toggle daily quote widget. |
| **Quote Source** | `Config.options.background.quoteSource` | `0` | `0` for local JSON, `1` for online API. |
| **Show Desktop Icons**| `Config.options.background.showDesktopIcons` | `false` | Enable or disable files on the desktop. |
