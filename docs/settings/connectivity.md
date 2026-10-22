# Connectivity Settings: Bluetooth & Wi-Fi User Experience

Sleex provides dedicated, responsive configuration pages for wireless adapters (`src/share/sleex/modules/settings/Bluetooth.qml` and `modules/settings/Wifi.qml`).

---

## 1. Bluetooth Management (`Bluetooth.qml`)

```
+-----------------------------------------------------------------------------------------------+
|  Bluetooth settings                                                                           |
|                                                                                               |
|  [x] Enabled                                [ ] Discoverable                                  |
|                                                                                               |
|  3 devices available (1 connected)                                     [ (Scan Icon) Discover ]|
|                                                                                               |
|  +-----------------------------------------------------------------------------------------+  |
|  |  🎧 Sony WH-1000XM4                                                      ( 🔋 80% )     |  |
|  |     Connected • Paired                                    [ Disconnect ]   [ Forget ]   |  |
|  +-----------------------------------------------------------------------------------------+  |
|  |  ⌨️ Keychron K2                                                                          |  |
|  |     Paired                                                [ Connect ]      [ Forget ]   |  |
|  +-----------------------------------------------------------------------------------------+  |
|  |  🖱️ MX Master 3S                                                                        |  |
|  |     Discovered                                            [ Pair ]                      |  |
|  +-----------------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------------+
```

### Controls & Indicators
- **Adapter Switches**:
  - **Enabled**: Powers on/off the primary Bluetooth controller.
  - **Discoverable**: Makes the desktop visible to nearby phones and accessories.
- **Device Counter**: Real-time counter showing total discovered devices and connected accessories.
- **Discover / Scan Button**: Initiates an active device discovery scan with a spinning animation.
- **Device Type Categorization**:
  Icons adapt to device profiles automatically:
  - Headphones (`headphones`)
  - Earbuds (`earbuds_2`)
  - Speakers (`speaker`)
  - Keyboards (`keyboard_alt`)
  - Mice (`mouse`)
- **Device Actions**:
  - `Connect` / `Disconnect`
  - `Pair` / `Unpair`
  - Battery percentage indicator for supported Bluetooth devices.

---

## 2. Wi-Fi & Network Management (`Wifi.qml`)

A comprehensive networking center managing wireless interfaces, diagnostics, DNS security, and connection privacy.

```
+-----------------------------------------------------------------------------------------------+
|  Wi-Fi Network                                                                                |
|                                                                                               |
|  Active Connection: Fiber-Home-5G                                                             |
|  Signal: Excellent (98%)  •  Security: WPA2-PSK  •  Frequency: 5GHz, Channel 36              |
|                                                                                               |
|  Connection Details:                                                                          |
|  • Local IP:    192.168.1.145                                                                 |
|  • Gateway:     192.168.1.1                                                                   |
|  • DNS:         1.1.1.1, 1.0.0.1                                                              |
|  • Public IP:   203.0.113.42                                                                  |
|                                                                                               |
|  [x] Show connection details            [ ] Show sensitive IP info                            |
|                                                                                               |
|  Speed Test Diagnostics                                                 [ ▶ Run Speed Test ]  |
|  Ping: 12 ms                            Download: 425 Mbps             Upload: 88 Mbps        |
|                                                                                               |
|  DNS Provider:                                                                                |
|  (●) Cloudflare (1.1.1.1)    ( ) Google (8.8.8.8)    ( ) Quad9    ( ) AdGuard    ( ) Custom   |
|                                                                                               |
|  Available Wi-Fi Networks                                                                     |
|  +-----------------------------------------------------------------------------------------+  |
|  |  📶 Fiber-Home-5G                    Connected                                          |  |
|  |  📶 Office_Guest_Network             WPA2-PSK                     [ Connect ]           |  |
|  |  📶 Cafe_Free_WiFi                   Open                         [ Connect ]           |  |
|  +-----------------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------------+
```

### Active Connection Card
- Displays active SSID, signal strength icon, security encryption protocol, and precise frequency band:
  - `2.4 GHz, Channel X`
  - `5 GHz, Channel X`
  - `6 GHz, Channel X` (Wi-Fi 6E / Wi-Fi 7)

### Privacy Toggles
- **Show Connection Details (`Config.options.networking.connectionDetails`)**: Toggles visibility of IP, gateway, and frequency cards.
- **Show Sensitive Info (`Config.options.networking.sensitiveNetworkInfo`)**: Masks private and public IP addresses with bullets (`••••••••`) to protect privacy while screen sharing or streaming.

### Built-in Network Speed Test Tool
- Interactive benchmark tool integrated directly into Settings via `Network` service:
  - **Ping Benchmark**: Measures real-time round-trip latency in milliseconds (ms).
  - **Download Speed**: Multi-stream throughput test in Megabits per second (Mbps).
  - **Upload Speed**: Upstream bandwidth benchmark in Mbps.

### DNS Provider Switching
One-click switching between encrypted and privacy-respecting DNS resolvers:
- **Cloudflare** (`1.1.1.1`, `1.0.0.1`)
- **Google** (`8.8.8.8`, `8.8.4.4`)
- **Quad9** (`9.9.9.9`, `149.112.112.112`)
- **AdGuard DNS** (Ad & tracker blocking)
- **Custom DNS**: User-defined primary and secondary IP inputs.

### Available Wi-Fi Networks List
- Scans and sorts nearby access points by signal quality.
- Clicking a secured network opens a modal password prompt.
- Includes a "Forget Network" button to remove stored credentials.
