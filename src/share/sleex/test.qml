import Sleex.Fhtc
import QtQuick

Item {
    Connections {
        target: FhtcMonitors 
        
        function onMonitorsChanged() {
            // console.log("UPDATE REÇU :", JSON.stringify(FhtcMonitors.activeMonitor));
            console.log(FhtcMonitors.activeMonitorName);
            console.log(JSON.stringify(FhtcMonitors.activeMonitor));
            console.log(JSON.stringify(FhtcMonitors.monitors));
        }
    }
}