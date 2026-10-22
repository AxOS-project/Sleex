# Behavior, Power & Idle Rules User Experience

The Behavior Settings page (`src/share/sleex/modules/settings/BehaviorConfig.qml`) configures time formatting, power thresholds, sleep profiles, idle daemon rules, and external API keys.

---

## 1. Time and Date Section

```
+-----------------------------------------------------------------------------------------------+
|  Time and date                                                                                |
|                                                                                               |
|  Time format:                                                                                 |
|  [ 24h (hh:mm)                                                                            ▼ ] |
|                                                                                               |
|  Date format:                                                                                 |
|  [ DDDD, DD/MM (Tuesday, 22/10)                                                           ▼ ] |
+-----------------------------------------------------------------------------------------------+
```

### Time Format Options
- **24h (`hh:mm`)**: 24-hour military/European format (e.g. `14:30`).
- **12h AM/PM (`h:mm AP`)**: Standard 12-hour format with meridian indicator (e.g. `2:30 PM`).

### Date Format Options
Configurable through a combobox mapped to Qt date formatting strings:
- `ddd, MMM dd` (e.g. `Tue, Oct 22`)
- `DD/MM/YYYY` (e.g. `22/10/2026`)
- `MM/DD/YYYY` (e.g. `10/22/2026`)
- `YYYY-MM-DD` (ISO format: `2026-10-22`)
- `DDDD, DD/MM/YYYY` (e.g. `Tuesday, 22/10/2026`)
- `DDDD, DD/MM` (e.g. `Tuesday, 22/10`)

---

## 2. Power & Battery Section

```
+-----------------------------------------------------------------------------------------------+
|  Power                                                                                        |
|                                                                                               |
|  Low warning: [ 20 % ]                  Critical warning: [ 5 % ]                             |
|                                                                                               |
|  Power profile:                                                                               |
|  ( Balanced )            [ Performance ]            ( Power Saver )                           |
+-----------------------------------------------------------------------------------------------+
```

- **Low Warning SpinBox (`battery.low`)**: Battery percentage triggering the first notification and yellow status bar indicator (0 to 100%).
- **Critical Warning SpinBox (`battery.critical`)**: Battery percentage triggering sound alerts and red overlay banner (0 to 100%).
- **Power Profile Selector (`PowerProfiles.profile`)**:
  - **Balanced**: Standard everyday efficiency and performance.
  - **Performance**: Maximum clock speeds and display refresh.
  - **Power Saver**: Throttles background tasks and dims displays to extend battery life.

---

## 3. Idle Daemon (Hypnos) Section

Sleex includes an idle management daemon with progressive timeouts for battery preservation:

```
+-----------------------------------------------------------------------------------------------+
|  Idle daemon                                                                                  |
|                                                                                               |
|  [x] Enable idle actions                                                                      |
|                                                                                               |
|  Dim screen                                                                                   |
|  [x] Enable dimming                      [ ] Only on battery power                            |
|  Timeout: [ 300 seconds ]                                                                     |
|                                                                                               |
|  Lock screen                                                                                  |
|  [x] Enable locking                      [ ] Only on battery power                            |
|  Timeout: [ 600 seconds ]                                                                     |
|                                                                                               |
|  Suspend system                                                                               |
|  [x] Enable suspend                      [x] Only on battery power                            |
|  Timeout: [ 1800 seconds ]                                                                    |
+-----------------------------------------------------------------------------------------------+
```

### 1. Screen Dimming
- Gradually decreases backlight brightness after inactivity.
- **Timeout**: 10 to 3600 seconds.
- **Only on battery power**: When enabled, the screen will never dim while plugged into AC power.

### 2. Lock Screen
- Engages the Wayland session lockscreen automatically.
- **Timeout**: 10 to 3600 seconds.
- **Only on battery power**: Prevents locking on AC power if desired.

### 3. System Suspend
- Puts the computer into low-power sleep mode (`systemctl suspend`).
- **Timeout**: 10 to 3600 seconds.
- **Only on battery power**: Safe option to keep desktop running on AC while sleeping on battery.

---

## 4. API Keys & Online Services Section

### Unsplash Wallpapers API
- **API Key Text Field (`Unsplash.apiKey`)**: Enter an official Unsplash developer key to search and download online wallpapers.
- **Save Button**: Saves the API key securely.
- **Delete Button**: Clears the saved key.
- **Wallpaper Download Directory Path (`background.wallpaperDownloadPath`)**: Path where downloaded Unsplash photos are saved (default: `~/Pictures/Sleex Wallpapers/Unsplash/`).
