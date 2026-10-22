# Interface Settings User Experience

The Interface Settings page (`src/share/sleex/modules/settings/Interface.qml`) provides comprehensive toggles for all visible UI components across the shell: top bar, dashboard, dock, desktop background, lockscreen, and login manager.

---

## 1. Shell Style Section

- **Transparency Toggle (`Config.options.appearance.transparency`)**:
  - Enables or disables the backdrop blur effect on shell cards and panels.
- **Opacity SpinBox (`Config.options.appearance.opacity`)**:
  - Adjusts surface background opacity from `0%` (fully transparent) to `100%` (opaque solid color).

---

## 2. Top Status Bar Section

A grid of switches configuring element visibility on the status bar:

```
+-----------------------------------------------------------------------------------------------+
|  Bar                                                                                          |
|                                                                                               |
|  [x] Show app name                      [ ] Show resources usage                              |
|  [x] Show Workspaces                    [ ] Show clock                                        |
|  [x] Show island                        [x] Show system icons                                 |
|  [ ] Enable bar background              [ ] Bar auto-hide                                     |
|  [ ] Reserve space (visible if auto-hide is on)                                               |
+-----------------------------------------------------------------------------------------------+
```

### Workspaces Subsection
- **Show App Icons (`workspaces.showAppIcons`)**: Replaces simple dots with icons of running applications.
- **Use Material Icons (`workspaces.useMaterialIcons`)**: Uses geometric Material glyphs.
- **Always Show Numbers (`workspaces.alwaysShowNumbers`)**: Always displays numbers (1..10) without needing to hold `SUPER`.
- **Workspaces Shown SpinBox (`workspaces.shown`)**: Total workspaces shown (1 to 30).
- **Number Show Delay (`workspaces.showNumberDelay`)**: Delay in milliseconds (0 to 1000 ms) before `SUPER` key reveals numbers.

---

## 3. Dashboard Section

- **Dashboard Scale (`dashboard.dashboardScale`)**: SpinBox scaling the entire dashboard from `0%` to `200%` (step: 5%).
- **GitHub Username (`dashboard.ghUsername`)**: Text field specifying the user queried for the contribution heatmap.
- **User Description (`dashboard.userDesc`)**: Text field for personal status bio text.
- **Avatar Image Path (`dashboard.avatarPath`)**: Text field with an adjacent "Browse" button launching a native image picker dialog (`avatarPickerDialog`).
- **Optional Features Subsection**:
  - **Todo List Toggle (`dashboard.opt.enableTodo`)**: Enables/disables the Todo task manager tab.
  - **Calendar Tab Toggle (`dashboard.opt.enableCalendar`)**: Enables/disables the Calendar agenda tab.
- **Animation Direction**: Dropdown selecting slide-in axis: `Right`, `Left`, `Down`, `Up`.
- **Animation Intensity**: Slider adjusting animation duration from `0` to `1500 ms`.

---

## 4. Application Dock Section

- **Enabled Toggle (`dock.enabled`)**: Master switch to show or hide the dock.
- **Dock Height (`dock.height`)**: SpinBox adjusting dock thickness (pixels).
- **Hover to Reveal (`dock.hoverToReveal`)**: Hides dock until cursor reaches the bottom screen margin.
- **Pinned on Startup (`dock.pinnedOnStartup`)**: Keeps dock persistently visible and reserves desktop space.
- **Hover Region Height (`dock.hoverRegionHeight`)**: Height in pixels of the sensitive bottom trigger zone.

---

## 5. Desktop Background Section

- **Show Clock (`background.enableClock`)**: Toggles the large desktop typography clock.
- **Show Weather (`background.enableWeatherWidget`)**: Toggles the desktop weather forecast widget.
- **Show Watermark (`background.showWatermark`)**: Toggles the AxOS brand watermark.
- **Show Quotes (`background.enableQuote`)**: Toggles daily technology quotes.
- **Show Desktop Icons (`background.showDesktopIcons`)**: Displays desktop files and launchers.
- **Clock Mode Selector**: Pill buttons to choose between `Dark` and `Light` clock styling.
- **Clock Font ComboBox**: Full system font picker (`Qt.fontFamilies()`) to select custom typography.
- **Quote Source Selector**: Switch between `Online` (API) and `Local` (community JSON file).

---

## 6. Notifications & Alerts Section

- **Position Selector (`notifications.position`)**: Segmented pill picker:
  - `Top Left`
  - `Top Center`
  - `Top Right` (Default)
- **Battery Overlay Warnings (`battery.overlayEnabled`)**:
  - Toggles the persistent red warning banner along the top of the screen when battery drops below critical levels.

---

## 7. Lockscreen Section

- **Scrim Background (`lockscreen.enableScrim`)**: Enables dark dimming over the wallpaper on the lock screen.
- **Player Integration (`lockscreen.showLyricsOnLockScreen`)**: Displays the MPRIS media player card on the lockscreen.
- **Resizable Widget**: Allows dragging and resizing the lockscreen media player card.

---

## 8. Login Screen (SDDM) Section

Integrates with the system display manager to customize the greeter face icon:
- **Current Status**: Displays whether a custom picture is set.
- **Browse Button**: Launches file picker to select a profile photo (`.png`, `.jpg`, `.webp`).
- **Root Elevation**: Uses `pkexec` to securely copy the image to `/usr/share/sddm/faces/$(id -un).face.icon`.
- **Remove Button**: Deletes custom SDDM face icon with root authorization.

---

## 9. Calendar Section

- **Use vdirsyncer (`dashboard.calendar.useVdirsyncer`)**: Enables background CalDAV synchronization.
- **Sync Interval SpinBox (`dashboard.calendar.syncInterval`)**: Interval between calendar syncs (1 to 1440 minutes).
