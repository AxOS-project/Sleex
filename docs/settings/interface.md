# Interface Settings User Experience

The Interface Settings page provides toggles for all visible UI components across the shell.

---

## 1. Shell Style Section

- **Transparency Toggle**:
  - Enables or disables the backdrop blur effect on shell cards and panels.
- **Opacity SpinBox**:
  - Adjusts surface background opacity from `0%` (fully transparent) to `100%` (opaque solid color).

---

## 2. Top Status Bar Section

A grid of switches configuring element visibility on the status bar:

### Workspaces Subsection
- **Show App Icons**: Replaces simple dots with icons of running applications.
- **Use Material Icons**: Uses geometric Material glyphs.
- **Always Show Numbers**: Always displays numbers (1..10) without needing to hold `SUPER`.
- **Workspaces Shown SpinBox**: Total workspaces shown (1 to 30).
- **Number Show Delay**: Delay in milliseconds (0 to 1000 ms) before `SUPER` key reveals numbers.

---

## 3. Dashboard Section

- **Dashboard Scale**: SpinBox scaling the entire dashboard from `0%` to `200%` (step: 5%).
- **GitHub Username**: Text field specifying the user queried for the contribution heatmap.
- **User Description**: Text field for personal status bio text.
- **Avatar Image Path**: Text field with an adjacent "Browse" button launching a native image picker dialog.
- **Optional Features Subsection**:
  - **Todo List Toggle**: Enables/disables the Todo task manager tab.
  - **Calendar Tab Toggle**: Enables/disables the Calendar agenda tab.
- **Animation Direction**: Dropdown selecting slide-in axis: `Right`, `Left`, `Down`, `Up`.
- **Animation Intensity**: Slider adjusting animation duration from `0` to `1500 ms`.

---

## 4. Application Dock Section

- **Enabled Toggle**: Master switch to show or hide the dock.
- **Dock Height**: SpinBox adjusting dock height.
- **Hover to Reveal**: Hides dock until cursor reaches the bottom screen margin.
- **Pinned on Startup**: Keeps dock persistently visible and reserves desktop space.
- **Hover Region Height**: Height in pixels of the sensitive bottom trigger zone.

---

## 5. Desktop Background Section

- **Show Clock**: Toggles the large desktop typography clock.
- **Show Weather**: Toggles the desktop weather forecast widget.
- **Show Watermark**: Toggles the AxOS brand watermark.
- **Show Quotes**: Toggles daily quotes.
- **Show Desktop Icons**: Displays desktop files and launchers.
- **Clock Mode Selector**: Pill buttons to choose between `Dark` and `Light` clock styling.
- **Clock Font ComboBox**: Full system font picker to select custom typography.
- **Quote Source Selector**: Switch between `Online` (API) and `Local` (community JSON file).

---

## 6. Notifications & Alerts Section

- **Position Selector**: Segmented pill picker:
  - `Top Left`
  - `Top Center`
  - `Top Right` (Default)
- **Battery Overlay Warnings**:
  - Toggles the persistent red warning banner along the top of the screen when battery drops below critical levels.

---

## 7. Lockscreen Section

- **Scrim Background**: Enables dark dimming over the wallpaper on the lock screen.
- **Player Integration**: Displays the MPRIS media player card on the lockscreen.
- **Resizable Widget**: Allows dragging and resizing the lockscreen media player card.

---

## 8. Login Screen (SDDM) Section

Integrates with the system display manager to customize the greeter face icon:
- **Current Status**: Displays whether a custom picture is set.
- **Browse Button**: Launches file picker to select a profile photo.
- **Root Elevation**: Uses `pkexec` to securely copy the image to `/usr/share/sddm/faces/$(id -un).face.icon`.
- **Remove Button**: Deletes custom SDDM face icon with root authorization.

---

## 9. Calendar Section

- **Use vdirsyncer**: Enables background CalDAV synchronization.
- **Sync Interval SpinBox**: Interval between calendar syncs (1 to 1440 minutes).
