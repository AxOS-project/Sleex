pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.services
import SleexUiKit.Widgets
import SleexUiKit.Functions
import SleexUiKit.Appearance

Rectangle {
    id: root

    function materialSymbolForCode(code) {
        const c = parseInt(code);
        if (isNaN(c)) return "cloud";
        if (c === 0) return "sunny";
        if (c <= 2) return "partly_cloudy_day";
        if (c === 3) return "cloud";
        if (c <= 48) return "foggy";
        if (c <= 67) return "rainy";
        if (c <= 77) return "weather_snowy";
        if (c <= 82) return "rainy";
        if (c <= 86) return "weather_snowy";
        if (c <= 99) return "thunderstorm";
        return "cloud";
    }

    implicitWidth: Math.max(300, mainRow.implicitWidth + 24)
    implicitHeight: mainRow.implicitHeight + 20
    radius: Appearance.rounding.verylarge
    color: ColorUtils.mix("#000000", Appearance.m3colors.m3surfaceContainerHigh, 0.45)
    border.width: 1
    border.color: ColorUtils.transparentize(Appearance.m3colors.m3outlineVariant, 0.65)

    RowLayout {
        id: mainRow
        anchors.centerIn: parent
        spacing: 16

        Rectangle {
            Layout.preferredWidth: Math.max(108, tempColumn.implicitWidth + 28)
            Layout.preferredHeight: Math.max(76, tempColumn.implicitHeight + 16)
            radius: Appearance.rounding.large
            color: Appearance.m3colors.m3primaryContainer

            RowLayout {
                id: tempColumn
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    text: root.materialSymbolForCode(Weather.weatherCode)
                    iconSize: 32
                    fill: 1
                    color: Appearance.m3colors.m3onPrimaryContainer
                }

                StyledText {
                    text: Weather.temperature || qsTr("--°C")
                    font.family: Appearance.font.family.expressive
                    font.pixelSize: 24
                    font.weight: Font.Bold
                    color: Appearance.m3colors.m3onPrimaryContainer
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.rightMargin: 8
            spacing: 4

            StyledText {
                text: Weather.condition || qsTr("Weather unavailable")
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                color: Appearance.m3colors.m3onSurface
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 12

                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "location_on"
                        iconSize: 14
                        fill: 1
                        color: Appearance.m3colors.m3primary
                    }
                    StyledText {
                        text: Weather.locationName || qsTr("--")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "water_drop"
                        iconSize: 14
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }
                    StyledText {
                        text: Weather.humidity ? `${Weather.humidity}%` : qsTr("--%")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }
                }

                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "air"
                        iconSize: 14
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }
                    StyledText {
                        text: Weather.windSpeed ? qsTr("%1 km/h").arg(Weather.windSpeed) : qsTr("-- km/h")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
