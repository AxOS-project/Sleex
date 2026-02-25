import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Weather service.
 */
Singleton {
    id: root
    property string loc
    property string locationName
    property string temperature
    property string condition
    property string raw
    property string weatherCode
    property bool useCustomLocation: false
    property var forecast: []

    Timer {
        id: weatherTimer
        interval: 3600000 // 1 hour
        running: Config.options.dashboard.enableWeather
        repeat: true
        onTriggered: updateWeather()
    }

    function checkCustomLocation() {
        if (!Config.options.dashboard.autoWeatherLocation && Config.options.dashboard.weatherLocation && Config.options.dashboard.weatherLocation.trim() !== "") {
            root.loc = Config.options.dashboard.weatherLocation.trim();
            root.useCustomLocation = true;
            geocodeLocation.running = true;
        } else {
            getIp.running = true;
        }
    }

    function weatherCodeToDescription(code) {
        const descriptions = {
            0: "Clear sky",
            1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
            45: "Foggy", 48: "Depositing rime fog",
            51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
            56: "Light freezing drizzle", 57: "Heavy freezing drizzle",
            61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
            66: "Light freezing rain", 67: "Heavy freezing rain",
            71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow",
            77: "Snow grains",
            80: "Slight showers", 81: "Moderate showers", 82: "Violent showers",
            85: "Slight snow showers", 86: "Heavy snow showers",
            95: "Thunderstorm", 96: "Thunderstorm with slight hail", 99: "Thunderstorm with heavy hail"
        };
        return descriptions[code] ?? "Unknown";
    }

    Process {
        id: getIp
        command: ["curl", "https://ipwho.is"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.loc = `${data.latitude},${data.longitude}`;
                    root.locationName = data.city || data.region || "Unknown";
                    root.useCustomLocation = false;
                    getWeather.lat = String(data.latitude);
                    getWeather.lon = String(data.longitude);
                    getWeather.running = true;
                } catch (e) {
                    console.error("Error parsing IP data:", e);
                    root.locationName = "London";
                    getWeather.lat = "51.5074";
                    getWeather.lon = "-0.1278";
                    getWeather.running = true;
                }
            }
        }
    }

    Process {
        id: geocodeLocation
        command: ["curl", `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(root.loc)}&count=1&format=json`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!data.results || data.results.length === 0) {
                        throw new Error("No geocoding results for: " + root.loc);
                    }
                    const result = data.results[0];
                    root.locationName = result.name || root.loc;
                    getWeather.lat = String(result.latitude);
                    getWeather.lon = String(result.longitude);
                    getWeather.running = true;
                } catch (e) {
                    console.error("Error geocoding location:", e);
                    root.useCustomLocation = false;
                    getIp.running = true;
                }
            }
        }
    }

    Process {
        id: getWeather
        property string lat: "0"
        property string lon: "0"
        command: [
            "curl",
            `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
            `&current=temperature_2m,weather_code` +
            `&daily=weather_code,temperature_2m_max,temperature_2m_min` +
            `&forecast_days=6&timezone=auto`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const current = data.current;
                    root.raw = text;
                    root.weatherCode = String(current.weather_code);
                    root.temperature = Math.round(current.temperature_2m) + "°C";
                    root.condition = root.weatherCodeToDescription(current.weather_code);

                    // Build 5-day forecast (skip index 0 = today)
                    const daily = data.daily;
                    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                    const forecastData = [];
                    for (let i = 1; i <= 5; i++) {
                        const date = new Date(daily.time[i]);
                        forecastData.push({
                            day: days[date.getDay()],
                            minTemp: Math.round(daily.temperature_2m_min[i]) + "°C",
                            maxTemp: Math.round(daily.temperature_2m_max[i]) + "°C",
                            weatherCode: daily.weather_code[i]
                        });
                    }
                    root.forecast = forecastData;
                } catch (e) {
                    console.error("Error parsing weather data:", e);
                    if (root.useCustomLocation) {
                        root.useCustomLocation = false;
                        getIp.running = true;
                    }
                }
            }
        }
    }

    function updateWeather() {
        checkCustomLocation();
    }

    Component.onCompleted: {
        updateWeather();
    }
}
