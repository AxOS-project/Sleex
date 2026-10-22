# Security & Privacy Settings User Experience

The Security and Privacy Settings pages (`src/share/sleex/modules/settings/Security.qml` and `modules/settings/Privacy.qml`) manage biometric facial authentication and data privacy controls.

---

## 1. Security: Howdy Facial Authentication (`Security.qml`)

Sleex integrates with **Howdy** to provide Windows Hello-style facial authentication on Wayland using IR or standard webcams.

```
+-----------------------------------------------------------------------------------------------+
|  Howdy Facial Authentication                                                                  |
|                                                                                               |
|  Status: Found 2 face model(s). Camera device: /dev/video0                                    |
|                                                                                               |
|  Enrolled Face Models:                                                                        |
|  +-----------------------------------------------------------------------------------------+  |
|  |  ID: 0  •  Created: 2026-09-15 11:20  •  Label: Laptop Webcam Normal       [ Delete ]   |  |
|  +-----------------------------------------------------------------------------------------+  |
|  |  ID: 1  •  Created: 2026-10-02 18:45  •  Label: Low Light Bedroom          [ Delete ]   |  |
|  +-----------------------------------------------------------------------------------------+  |
|                                                                                               |
|  Add New Face Model                                                                           |
|  Model Label: [ Glasses / Morning                               ]   [ ➕ Add Model ]          |
+-----------------------------------------------------------------------------------------------+
```

### Model Management UX
- **Live Status Feed**: Shows model load state, camera discovery status, and active capture progress.
- **Enrolled Models List**:
  - Displays ID, creation timestamp, and user label for each enrolled face scan.
  - **Delete Button**: Prompts with confirmation and invokes `pkexec /usr/bin/howdy remove` to delete obsolete models.
- **Adding a New Face Model**:
  - Enter a descriptive label (e.g. "Work Desk", "Dim Lighting", "With Glasses").
  - Clicking "Add Model" prompts for root authentication and activates the camera enrollment wizard.
  - Visual status updates guide the user to look directly into the camera lens during scanning.

---

## 2. Privacy Settings (`Privacy.qml`)

Allows users to control what personal or environmental data is shared with online API providers:

```
+-----------------------------------------------------------------------------------------------+
|  Weather Privacy                                                                              |
|                                                                                               |
|  [x] Enabled                                                                                  |
|      View weather forecasts directly in your dashboard (Open-Meteo provider)                  |
|                                                                                               |
|  [x] Automatic Location                                                                       |
|      IP-based approximate location                                                            |
|                                                                                               |
|  Weather Location (visible if Automatic Location is off):                                     |
|  [ Paris, France                                                                            ] |
+-----------------------------------------------------------------------------------------------+
|  Media Player Privacy                                                                         |
|                                                                                               |
|  [x] Lyrics                                                                                   |
|      Fetch and display synced lyrics (LRCLIB provider)                                        |
+-----------------------------------------------------------------------------------------------+
```

### Weather Privacy Controls
- **Weather Forecast Toggle (`dashboard.enableWeather`)**: Master toggle for weather widgets across the dashboard and desktop background.
- **Automatic Location Toggle (`dashboard.autoWeatherLocation`)**:
  - When enabled, uses IP-based geolocation to query local weather forecasts without storing GPS coordinates.
- **Manual City / Coordinate Override (`dashboard.weatherLocation`)**:
  - When automatic location is turned off, a text input appears allowing users to manually enter a city or region name, preventing transmission of their IP location.

### Media Player Lyrics Privacy
- **Synced Lyrics Toggle (`dashboard.enableLyrics`)**:
  - Controls whether the media player queries online providers (LRCLIB) for live synchronized lyrics during music playback.
  - Disabling this prevents outgoing queries with artist and song metadata.
