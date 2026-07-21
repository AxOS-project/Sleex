import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.dashboard.notifications
import qs.modules.dashboard.calendar
import qs.modules.dashboard.home
import qs.modules.mediaControls
import QtQuick
import QtQuick.Layouts
import Quickshell
import Sleex.Services

Rectangle {
    id: root
    color: "transparent"

    property bool connected: Network.networks.filter(n => n.active).length > 0

    Component { id: compUserInfo; HomeUserInfoWidget {} }
    Component { id: compClock; HomeClockWidget {} }
    Component { id: compGithub; HomeGithubWidget { connected: root.connected } }
    Component { id: compNotifications; NotificationList { anchors.margins: 15 } }
    Component { id: compMedia; MediaControls {} }
    Component { id: compWeather; HomeWeatherWidget { connected: root.connected } }
    Component { id: compCalendar; CalendarWidget {} }

    readonly property var widgetRegistry: [
        { id: "userInfo", column: 1, fillHeight: false, preferredHeight: 300, component: compUserInfo },
        { id: "clock", column: 1, fillHeight: false, preferredHeight: 150, component: compClock },
        { id: "github", column: 1, fillHeight: true, preferredHeight: -1,  component: compGithub },
        { id: "notifications", column: 2, fillHeight: true, preferredHeight: -1,  component: compNotifications },
        { id: "media", column: 3, fillHeight: false, preferredHeight: 150, component: compMedia },
        { id: "weather", column: 3, fillHeight: true, preferredHeight: -1,  component: compWeather },
        { id: "calendar", column: 3, fillHeight: false, preferredHeight: 375, component: compCalendar }
    ]

    function widgetsForColumn(col) {
        return widgetRegistry.filter(w => w.column === col)
    }

    RowLayout {
        id: mainCols
        anchors.fill: parent
        spacing: 10

        Repeater {
            model: 3
            delegate: ColumnLayout {
                id: columnDelegate
                required property int index
                readonly property int columnNumber: index + 1
                spacing: 10

                Layout.fillWidth: columnNumber === 2
                Layout.preferredWidth: columnNumber !== 2 ? 450 : -1

                Layout.fillHeight: true

                Repeater {
                    model: root.widgetsForColumn(columnDelegate.columnNumber)
                    delegate: Loader {
                        id: widgetLoader
                        required property var modelData
                        
                        Layout.fillWidth: true
                        Layout.fillHeight: modelData.fillHeight
                        
                        Layout.preferredHeight: modelData.preferredHeight > 0 ? modelData.preferredHeight : -1
                        
                        sourceComponent: modelData.component
                    }
                }
            }
        }
    }
}
