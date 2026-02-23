import QtQuick 
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: weatherRoot
    anchors.horizontalCenterOffset: -2
    color: "transparent"

    property var weatherData: Weather.raw ? JSON.parse(Weather.raw) : null
    property string city: Weather.raw ? weatherData.nearest_area[0].areaName[0].value : "Loading..."

    Rectangle {
        id: card
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Current weather row
            RowLayout {
                spacing: 12
                Layout.fillWidth: true

                // Weather icon and basic info section
                RowLayout {
                    spacing: 12
                    Layout.preferredWidth: 140
                    Layout.alignment: Qt.AlignHCenter

                    // Weather icon
                    MaterialSymbol {
                        id: weatherIcon
                        iconSize: 48
                        text: Weather.raw ? materialSymbolForCode(Weather.weatherCode) : "cloud"
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        spacing: 2
                        RowLayout {
                            spacing: 4
                            StyledText {
                                text: city
                                font.pixelSize: 14
                                font.bold: true
                                color: Appearance.colors.colOnLayer0
                            }
                        }
                        StyledText {
                            text: Weather.temperature ? Weather.temperature : "--"
                            font.pixelSize: 24
                            font.bold: true
                            color: Appearance.colors.colOnLayer0
                        }
                    }
                }
                // Spacer to push content to the right
                Item {
                    Layout.fillWidth: true
                }
                
                // Refresh button
                MaterialSymbol {
                    text: "restart_alt"
                    iconSize: 22
                    color: Appearance.colors.colPrimary
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Weather.updateWeather()
                    }
                }
            }

            // Separator line
            Rectangle {
                width: parent.width
                height: 1
                color: Appearance.colors.colLayer2
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
            }

            // 5-day forecast row
            RowLayout {
                spacing: 12
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: weatherData && weatherData.weather ? Math.min(5, weatherData.weather.length) : 0
                    delegate: ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignHCenter
                        
                        property var dayData: weatherData && weatherData.weather && weatherData.weather[index] ? weatherData.weather[index] : null
                        
                        StyledText {
                            // Day of the week (e.g., Mon)
                            text: dayData ? Qt.formatDateTime(new Date(dayData.date), "ddd") : Qt.formatDateTime(new Date(Date.now() + index * 24 * 60 * 60 * 1000), "ddd")
                            font.pixelSize: 15
                            color: Appearance.colors.colOnLayer0
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }
                        MaterialSymbol {
                            // Material Symbol icon - use the day's weather code
                            text: dayData && dayData.hourly && dayData.hourly.length > 0 ? 
                                  materialSymbolForCode(dayData.hourly[Math.floor(dayData.hourly.length/2)].weatherCode) : 
                                  "cloud"
                            font.pixelSize: 22
                            color: Appearance.colors.colPrimary
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }
                        StyledText {
                            // High/low temp
                            text: dayData ? `${dayData.mintempC}°C / ${dayData.maxtempC}°C` : "--"
                            font.pixelSize: 12
                            color: Appearance.colors.colOnLayer0
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // Weather code to Material Symbol ligature mapping (wttr.in uses WorldWeatherOnline codes)
    function materialSymbolForCode(code) {
        const weatherCode = parseInt(code);
        
        switch (weatherCode) {
            case 113: return "sunny";
            case 116: return "partly_cloudy_day";
            
            case 119: // Cloudy
            case 122: // Overcast
                return "cloud";
            
            case 143: // Mist
            case 248: // Fog
            case 260: // Freezing fog
                return "foggy";
            
            case 176: // Patchy rain nearby
            case 263: // Patchy light drizzle
            case 266: // Light drizzle
            case 293: // Patchy light rain
            case 296: // Light rain
            case 299: // Moderate rain at times
            case 302: // Moderate rain
            case 305: // Heavy rain at times
            case 308: // Heavy rain
            case 353: // Light rain shower
            case 356: // Moderate or heavy rain shower
            case 359: // Torrential rain shower
                return "rainy";
            
            case 179: // Patchy snow nearby
            case 182: // Patchy sleet nearby
            case 185: // Patchy freezing drizzle nearby
            case 227: // Blowing snow
            case 230: // Blizzard
            case 281: // Freezing drizzle
            case 284: // Heavy freezing drizzle
            case 311: // Light freezing rain
            case 314: // Moderate or Heavy freezing rain
            case 317: // Light sleet
            case 320: // Moderate or heavy sleet
            case 323: // Patchy light snow
            case 326: // Light snow
            case 329: // Patchy moderate snow
            case 332: // Moderate snow
            case 335: // Patchy heavy snow
            case 338: // Heavy snow
            case 350: // Ice pellets
            case 362: // Light sleet showers
            case 365: // Moderate or heavy sleet showers
            case 368: // Light snow showers
            case 371: // Moderate or heavy snow showers
            case 374: // Light showers of ice pellets
            case 377: // Moderate or heavy showers of ice pellets
                return "weather_snowy";
            
            case 200: // Thundery outbreaks nearby
            case 386: // Patchy light rain with thunder
            case 389: // Moderate or heavy rain with thunder
            case 392: // Patchy light snow with thunder
            case 395: // Moderate or heavy snow with thunder
                return "thunderstorm";
            
            default:
                return "cloud";
        }
    }
    
    function weatherDescriptionForCode(code) {
        const weatherCode = parseInt(code);
        
        switch (weatherCode) {
            case 113: return "Clear/Sunny";
            case 116: return "Partly Cloudy";
            case 119: return "Cloudy";
            case 122: return "Overcast";
            case 143: return "Mist";
            case 176: return "Patchy rain nearby";
            case 179: return "Patchy snow nearby";
            case 182: return "Patchy sleet nearby";
            case 185: return "Patchy freezing drizzle nearby";
            case 200: return "Thundery outbreaks in nearby";
            case 227: return "Blowing snow";
            case 230: return "Blizzard";
            case 248: return "Fog";
            case 260: return "Freezing fog";
            case 263: return "Patchy light drizzle";
            case 266: return "Light drizzle";
            case 281: return "Freezing drizzle";
            case 284: return "Heavy freezing drizzle";
            case 293: return "Patchy light rain";
            case 296: return "Light rain";
            case 299: return "Moderate rain at times";
            case 302: return "Moderate rain";
            case 305: return "Heavy rain at times";
            case 308: return "Heavy rain";
            case 311: return "Light freezing rain";
            case 314: return "Moderate or Heavy freezing rain";
            case 317: return "Light sleet";
            case 320: return "Moderate or heavy sleet";
            case 323: return "Patchy light snow";
            case 326: return "Light snow";
            case 329: return "Patchy moderate snow";
            case 332: return "Moderate snow";
            case 335: return "Patchy heavy snow";
            case 338: return "Heavy snow";
            case 350: return "Ice pellets";
            case 353: return "Light rain shower";
            case 356: return "Moderate or heavy rain shower";
            case 359: return "Torrential rain shower";
            case 362: return "Light sleet showers";
            case 365: return "Moderate or heavy sleet showers";
            case 368: return "Light snow showers";
            case 371: return "Moderate or heavy snow showers";
            case 374: return "Light showers of ice pellets";
            case 377: return "Moderate or heavy showers of ice pellets";
            case 386: return "Patchy light rain in area with thunder";
            case 389: return "Moderate or heavy rain in area with thunder";
            case 392: return "Patchy light snow in area with thunder";
            case 395: return "Moderate or heavy snow in area with thunder";
            default: return "Unknown";
        }
    }
}
