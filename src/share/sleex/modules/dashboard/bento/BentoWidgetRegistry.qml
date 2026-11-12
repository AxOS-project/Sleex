import QtQuick
import qs.modules.dashboard.notifications
import qs.modules.dashboard.calendar
import qs.modules.dashboard.home
import qs.modules.mediaControls

Item {
    id: root
    visible: false

    property bool connected: false

    Component { id: compUserInfo; HomeUserInfoWidget {} }
    Component { id: compClock; HomeClockWidget {} }
    Component { id: compGithub; HomeGithubWidget { connected: root.connected } }
    Component { id: compNotifications; NotificationList {} }
    Component { id: compMedia; MediaControls {} }
    Component { id: compWeather; HomeWeatherWidget { connected: root.connected } }
    Component { id: compCalendar; CalendarWidget {} }

    readonly property var componentMap: ({
        "userInfo": compUserInfo,
        "clock": compClock,
        "github": compGithub,
        "notifications": compNotifications,
        "media": compMedia,
        "weather": compWeather,
        "calendar": compCalendar
    })

    readonly property var definitions: [
        {
            id: "userInfo",
            title: qsTr("User Profile"),
            icon: "person",
            col: 0, row: 0, colSpan: 1, rowSpan: 4, enabled: true,
            presets: [
                { colSpan: 1, rowSpan: 3, label: "1×3" },
                { colSpan: 1, rowSpan: 4, label: "1×4" },
                { colSpan: 1, rowSpan: 5, label: "1×5" }
            ]
        },
        {
            id: "clock",
            title: qsTr("Clock"),
            icon: "schedule",
            col: 0, row: 4, colSpan: 1, rowSpan: 2, enabled: true,
            presets: [
                { colSpan: 1, rowSpan: 2, label: "1×2" },
                { colSpan: 1, rowSpan: 3, label: "1×3" },
                { colSpan: 2, rowSpan: 2, label: "2×2" }
            ]
        },
        {
            id: "github",
            title: qsTr("GitHub"),
            icon: "code",
            col: 0, row: 6, colSpan: 1, rowSpan: 4, enabled: true,
            presets: [
                { colSpan: 1, rowSpan: 3, label: "1×3" },
                { colSpan: 1, rowSpan: 4, label: "1×4" },
                { colSpan: 1, rowSpan: 5, label: "1×5" },
                { colSpan: 2, rowSpan: 4, label: "2×4" }
            ]
        },
        {
            id: "notifications",
            title: qsTr("Notifications"),
            icon: "notifications",
            col: 1, row: 0, colSpan: 1, rowSpan: 10, enabled: true,
            presets: [
                { colSpan: 1, rowSpan: 5, label: "1×5" },
                { colSpan: 1, rowSpan: 6, label: "1×6" },
                { colSpan: 1, rowSpan: 8, label: "1×8" },
                { colSpan: 1, rowSpan: 10, label: "1×10" },
                { colSpan: 2, rowSpan: 10, label: "2×10" }
            ]
        },
        {
            id: "media",
            title: qsTr("Media Player"),
            icon: "music_note",
            col: 2, row: 0, colSpan: 1, rowSpan: 2, enabled: true,
            presets: [
                { colSpan: 1, rowSpan: 2, label: "1×2" },
                { colSpan: 1, rowSpan: 3, label: "1×3" },
                { colSpan: 2, rowSpan: 2, label: "2×2" }
            ]
        },
        {
            id: "weather",
            title: qsTr("Weather"),
            icon: "cloud",
            col: 2, row: 2, colSpan: 1, rowSpan: 3, enabled: true,
            presets: [
                { colSpan: 1, rowSpan: 2, label: "1×2" },
                { colSpan: 1, rowSpan: 3, label: "1×3" },
                { colSpan: 1, rowSpan: 4, label: "1×4" },
                { colSpan: 2, rowSpan: 3, label: "2×3" }
            ]
        },
        {
            id: "calendar",
            title: qsTr("Calendar"),
            icon: "calendar_month",
            col: 2, row: 5, colSpan: 1, rowSpan: 5, enabled: true,
            presets: [
                { colSpan: 1, rowSpan: 4, label: "1×4" },
                { colSpan: 1, rowSpan: 5, label: "1×5" },
                { colSpan: 1, rowSpan: 6, label: "1×6" },
                { colSpan: 2, rowSpan: 5, label: "2×5" }
            ]
        }
    ]

    function componentForId(widgetId) {
        return componentMap[widgetId] ?? null
    }
}
