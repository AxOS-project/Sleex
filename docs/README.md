# Sleex Desktop Environment: Shell & Settings UX Documentation

Welcome to the comprehensive user experience (UX) documentation for **Sleex**, the flagship desktop environment of AxOS built on **Hyprland** (Wayland compositor) and **Quickshell** (Qt 6 / QML layer shell).

This documentation focuses exclusively on the **user-facing shell and settings experience** implemented in `src/share/sleex`.

---

## Design Language & UX Philosophy

Sleex is built around the modern **Material Design 3 (Material You)** design philosophy, customized for an efficient, keyboard-driven Wayland desktop workflow:

- **Dynamic Material You Theming**: The desktop palette is dynamically generated from the current wallpaper using color extraction algorithms (`scheme-tonal-spot`, `scheme-expressive`, `scheme-fruit-salad`, etc.), or locked to a static accent color preference.
- **Surface Elevation & Contrast**: Interfaces utilize hierarchical elevation layers (`colLayer0` through `colLayer2`, `colSurfaceContainerHigh`) with subtle borders, elevation shadows, and optional background blur (`transparency`).
- **Fluid Spring Animations**: All transitions, popups, and state changes respect physics-inspired easing curves (`emphasizedLastHalf`, `elementMoveEnter`, `elementMoveExit`).
- **Dual-Mode Interaction**: Seamlessly switch between zero-latency keyboard shortcuts and intuitive pointing device gestures (hover triggers, context menus, drag-and-drop).

---

## Architecture Overview

The Sleex user interface is divided into two primary entry points:

1. **The Desktop Shell (`shell.qml`)**:
   Runs continuously as a Wayland layer-shell daemon (`qs -p /usr/share/sleex`). It hosts the top/bottom status bar, the application dock, the modular bento dashboard, the window & workspace overview launcher, desktop background widgets, system notifications, OSDs, utility drawers, and the session lockscreen.
2. **The Settings Center (`settings.qml`)**:
   An application window (`qs -p /usr/share/sleex/settings.qml`) providing categorized configuration across 11 dedicated pages. Settings are synchronized in real time with the desktop shell via a persistent JSON database and reactive file triggers (`.db_trigger`).

```mermaid
graph TD
    User([User]) -->|Hotkeys / Gestures| Shell[Sleex Shell: shell.qml]
    User -->|Configure / Personalize| Settings[Sleex Settings: settings.qml]

    subgraph Desktop Shell Experience
        Shell --> Bar[Top / Bottom Status Bar]
        Shell --> Dock[Application Dock]
        Shell --> Dashboard[Fullscreen Dashboard & Bento Grid]
        Shell --> Overview[Overview & Universal Launcher]
        Shell --> Desktop[Desktop Canvas & Widgets]
        Shell --> Popups[Utility Popups: Pomodoro, Stopwatch, Cheatsheet]
        Shell --> Lock[Lockscreen & Session Controls]
        Shell --> Alerts[Notifications & Volume/Brightness OSD]
    end

    subgraph Settings Experience
        Settings --> StylePage[Style & Material 3 Colors]
        Settings --> InterfacePage[Interface & Layout Toggles]
        Settings --> BehaviorPage[Behavior, Power & Hypnos Idle]
        Settings --> SoundPage[Sound, Earbang & Volume Mixer]
        Settings --> ConnectPage[Connectivity: Bluetooth & Wi-Fi]
        Settings --> DisplayPage[Display & Monitor Arrangement]
        Settings --> AppsPage[Default Applications]
        Settings --> SecurityPage[Security: Howdy & Privacy]
        Settings --> AboutPage[About Sleex & Hardware Info]
    end

    Settings -.->|Live Database Sync| Shell
```

---

## Documentation Table of Contents

### Part 1: The Shell User Experience (`docs/shell/`)

- [**1. Shell Architecture & Interaction Model**](shell/overview.md) — Wayland layer surfaces, global shortcuts, multi-monitor behavior, and state management.
- [**2. Top Status Bar**](shell/bar.md) — Workspaces indicator, dynamic app titles, AppMenuBar global menu, resource monitors, center island clock, system tray, and auto-hide.
- [**3. Application Dock**](shell/dock.md) — Floating launcher dock, pinned applications, running window dots, auto-hide, hover-to-reveal, and empty workspace display.
- [**4. Fullscreen Dashboard & Bento Grid**](shell/dashboard.md) — Modular Bento grid layout, user profile card, GitHub heatmap, Weather widget, Calendar tab, Todo list, and Quick Toggles.
- [**5. Overview & Universal Launcher**](shell/overview-and-launcher.md) — Multi-workspace visualizer, fuzzy app launcher, action prefixes (`/`), clipboard history (`;`), emoji picker (`:`), and math calculator.
- [**6. Desktop Background, Canvas & Widgets**](shell/desktop.md) — Dynamic wallpaper transition engine, desktop clock, weather widget, Post-it sticky notes, daily quotes, and desktop icons context menus.
- [**7. Lockscreen & Session Controls**](shell/lockscreen-and-session.md) — PAM & Howdy facial unlock, media player with synced lyrics, and full-screen session shutdown/reboot menu with confirmation guards.
- [**8. Notifications, Alerts & On-Screen Displays**](shell/notifications-and-osd.md) — Floating notification toasts, volume & brightness OSD indicators, battery alerts, and warning overlays.
- [**9. Utility Popups, Cheatsheet & Tools**](shell/utility-popups.md) — Bottom-left corner drawer (Pomodoro & Stopwatch), Hyprland keybind cheatsheet, wallpaper visual picker with Unsplash integration, and Polkit dialog.

---

### Part 2: The Settings User Experience (`docs/settings/`)

- [**1. Settings Navigation & Overview**](settings/overview.md) — Master window layout, sidebar navigation, user card, and reactive config engine.
- [**2. Style & Colors**](settings/style.md) — Light/Dark theme switching, Material 3 dynamic color generation palettes, static color chips, wallpaper transition styles, and directory configuration.
- [**3. Interface & Layout**](settings/interface.md) — Transparency blur, opacity slider, bar elements visibility, workspace indicator styling, dashboard customization, dock behavior, desktop background toggles, notification positioning, and SDDM avatar setup.
- [**4. Behavior, Power & Idle Rules**](settings/behavior.md) — Time/date formats, battery thresholds, power profiles (Balanced, Performance, Power Saver), Hypnos idle screen dimming/lock/suspend rules, and Unsplash API credentials.
- [**5. Sound, Protection & Volume Mixer**](settings/sound.md) — Hearing protection (earbang limiter), input/output device selection, per-application stream volume mixer, and battery alert sounds.
- [**6. Connectivity: Bluetooth & Wi-Fi**](settings/connectivity.md) — Bluetooth adapter controls, discovery, device cards, Wi-Fi network scanning, connection details, built-in speed test, and custom DNS provider switching.
- [**7. Display & Multi-Monitor Arrangement**](settings/display.md) — Interactive drag-and-drop monitor canvas with magnetic snapping, resolution, refresh rate, scaling, rotation, mirroring, brightness slider, and Night Light schedule.
- [**8. Default Applications**](settings/applications.md) — Association manager for Web Browser, File Manager, Image Viewer, Video Player, Music Player, Document Viewer, Terminal, and Text Editor.
- [**9. Security & Privacy**](settings/security-and-privacy.md) — Howdy face recognition enrollment and model manager; weather location privacy and media player lyrics provider toggles.
- [**10. About Sleex & System Information**](settings/about.md) — Distribution banner, kernel version, active Material color chips, hardware specs (CPU, GPU, RAM), and project links.

---

## Quick Reference: Default Desktop Hotkeys

| Shortcut | Shell Action / UX Trigger | Documented In |
| :--- | :--- | :--- |
| `SUPER` (release) | Toggle Overview & Universal App Launcher | [Overview & Launcher](shell/overview-and-launcher.md) |
| `SUPER + V` | Open Clipboard History Browser | [Overview & Launcher](shell/overview-and-launcher.md) |
| `SUPER + ;` | Open Emoji Picker | [Overview & Launcher](shell/overview-and-launcher.md) |
| `SUPER + D` | Toggle Fullscreen Dashboard | [Dashboard](shell/dashboard.md) |
| `SUPER + T` | Toggle Wallpaper Selector & Unsplash Browser | [Utility Popups](shell/utility-popups.md) |
| `SUPER + F1` | Toggle Keyboard Shortcuts Cheatsheet | [Utility Popups](shell/utility-popups.md) |
| `SUPER + L` | Lock Session (Screen Locker) | [Lockscreen & Session](shell/lockscreen-and-session.md) |
| `CTRL + ALT + Delete` | Open Power & Session Action Menu | [Lockscreen & Session](shell/lockscreen-and-session.md) |
| `XF86PowerOff` | Confirm before powering off | [Lockscreen & Session](shell/lockscreen-and-session.md) |
| `SUPER` (hold) | Reveal workspace numbers on status bar | [Top Status Bar](shell/bar.md) |
| `SUPER + 1..10` | Switch to workspace 1 through 10 | [Top Status Bar](shell/bar.md) |
| `SUPER + End` | Restart Quickshell Desktop Shell | [Shell Architecture](shell/overview.md) |
