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
    property string temperature
    property string condition
    property string raw
    property string weatherCode
    property bool useCustomLocation: false

    Timer {
        id: weatherTimer
        interval: 3600000 // 1 hour
        running: Config.options.dashboard.enableWeather
        repeat: true
        onTriggered: updateWeather()
    }

    // Check if custom location is set in config
    function checkCustomLocation() {
        if (Config.options.dashboard.weatherLocation && Config.options.dashboard.weatherLocation.trim() !== "") {
            // Use the custom location from config
            root.loc = Config.options.dashboard.weatherLocation.trim();
            root.useCustomLocation = true;
            getWeather.running = true;
        } else {
            // No custom location set, use IP-based location
            getIp.running = true;
        }
    }

    Process {
        id: getIp
        command: ["curl", "ipinfo.io"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.loc = data.loc;
                    root.useCustomLocation = false;
                    getWeather.running = true;
                } catch (e) {
                    console.error("Error parsing IP data:", e);
                    // Fallback to a default location if IP lookup fails
                    root.loc = "London";
                    root.useCustomLocation = false;
                    getWeather.running = true;
                }
            }
        }
    }

    Process {
        id: getWeather
        command: ["curl", `https://wttr.in/${root.loc}?format=j1`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const json = JSON.parse(text).current_condition[0];
                    root.raw = text;
                    root.condition = json.weatherDesc[0].value;
                    root.temperature = json.temp_C + "°C";
                    root.weatherCode = json.weatherCode;
                } catch (e) {
                    console.error("Error parsing weather data:", e);
                    // If using custom location failed, try IP-based as fallback
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
        // Initial weather update
        updateWeather();
    }
}
