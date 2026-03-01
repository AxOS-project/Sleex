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

    property bool isLoading: false

    Connections {
        target: Weather
        function onForecastChanged() { isLoading = false }
    }

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

                RowLayout {
                    spacing: 12
                    Layout.preferredWidth: 140
                    Layout.alignment: Qt.AlignHCenter

                    MaterialSymbol {
                        id: weatherIcon
                        iconSize: 48
                        text: materialSymbolForCode(Weather.weatherCode)
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        spacing: 2
                        StyledText {
                            text: Weather.locationName || "Loading..."
                            font.pixelSize: 14
                            font.bold: true
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            text: Weather.temperature || "--"
                            font.pixelSize: 24
                            font.bold: true
                            color: Appearance.colors.colOnLayer0
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Refresh button / spinner
                Item {
                    width: 22
                    height: 22
                    Layout.alignment: Qt.AlignVCenter

                    MaterialSymbol {
                        anchors.fill: parent
                        text: "restart_alt"
                        iconSize: 22
                        color: Appearance.colors.colPrimary
                        visible: !isLoading

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                isLoading = true
                                Weather.updateWeather()
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: isLoading

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "progress_activity"
                            iconSize: 22
                            color: Appearance.colors.colPrimary

                            RotationAnimator on rotation {
                                running: isLoading
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                        }
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
                    model: Weather.forecast ? Weather.forecast.length : 0
                    delegate: ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignHCenter

                        property var dayData: Weather.forecast[index]

                        StyledText {
                            text: dayData ? dayData.day : ""
                            font.pixelSize: 15
                            color: Appearance.colors.colOnLayer0
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }
                        MaterialSymbol {
                            text: dayData ? materialSymbolForCode(dayData.weatherCode) : "cloud"
                            font.pixelSize: 22
                            color: Appearance.colors.colPrimary
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }
                        StyledText {
                            text: dayData ? `${dayData.minTemp} / ${dayData.maxTemp}` : "--"
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

    // WMO weather code to Material Symbol mapping
    function materialSymbolForCode(code) {
        const c = parseInt(code);
        if (c === 0)    return "sunny";
        if (c <= 2)     return "partly_cloudy_day";
        if (c === 3)    return "cloud";
        if (c <= 48)    return "foggy";
        if (c <= 57)    return "rainy";
        if (c <= 67)    return "rainy";
        if (c <= 77)    return "weather_snowy";
        if (c <= 82)    return "rainy";
        if (c <= 86)    return "weather_snowy";
        if (c <= 99)    return "thunderstorm";
        return "cloud";
    }
}
