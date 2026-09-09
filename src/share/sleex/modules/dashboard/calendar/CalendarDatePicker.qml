import qs
import qs.modules.common
import SleexUiKit.Widgets
import SleexUiKit.Appearance
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool multiSelect: true
    property var selectedDates: [] // list of Date (normalized to midnight)
    readonly property int selectedCount: root.selectedDates ? root.selectedDates.length : 0

    signal selectionChanged()

    property int displayYear: new Date().getFullYear()
    property int displayMonth: new Date().getMonth()
    property string monthLabel: {
        const d = new Date(displayYear, displayMonth, 1);
        return Qt.formatDate(d, "MMMM yyyy");
    }
    readonly property int daysInMonth: new Date(displayYear, displayMonth + 1, 0).getDate()
    readonly property int firstDayOffset: (new Date(displayYear, displayMonth, 1).getDay() - (Config.options?.time?.firstDayOfWeek ?? 0) + 7) % 7
    readonly property var weekdayLabels: root.buildWeekdayLabels()
    readonly property real cellSize: root.width / 7

    function buildWeekdayLabels() {
        const base = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
        const start = Config.options?.time?.firstDayOfWeek ?? 0;
        const labels = [];
        for (let i = 0; i < 7; i++) labels.push(base[(start + i) % 7]);
        return labels;
    }

    function dateKey(d) {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function makeDate(year, month, day) {
        return new Date(year, month, day, 0, 0, 0, 0);
    }

    function dateForCell(index) {
        const day = index - root.firstDayOffset + 1;
        if (day < 1 || day > root.daysInMonth) return null;
        return root.makeDate(root.displayYear, root.displayMonth, day);
    }

    function cellForDate(d) {
        if (!d) return -1;
        const sameMonth = d.getFullYear() === root.displayYear && d.getMonth() === root.displayMonth;
        return sameMonth ? (d.getDate() - 1 + root.firstDayOffset) : -1;
    }

    function isSelected(d) {
        if (!d || !root.selectedDates) return false;
        const key = root.dateKey(d);
        return root.selectedDates.some((s) => root.dateKey(s) === key);
    }

    function isSameDay(a, b) {
        return a && b && a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function sortDates(list) {
        const copy = list.map((d) => new Date(d.getTime()));
        copy.sort((a, b) => a.getTime() - b.getTime());
        return copy;
    }

    function toggleDate(d) {
        if (!d) return;
        if (root.isSelected(d)) {
            root.selectedDates = root.selectedDates.filter((s) => root.dateKey(s) !== root.dateKey(d));
        } else {
            root.selectedDates = root.selectedDates.concat([new Date(d.getTime())]);
        }
        root.selectedDates = root.sortDates(root.selectedDates);
        root.selectionChanged();
    }

    function setSelection(list) {
        const normalized = (list || []).map((d) => root.makeDate(d.getFullYear(), d.getMonth(), d.getDate()));
        root.selectedDates = root.multiSelect ? root.sortDates(normalized) : root.sortDates(normalized).slice(0, 1);
        root.selectionChanged();
    }

    function clearSelection() {
        root.selectedDates = [];
        root.selectionChanged();
    }

    function addDays(d, days) {
        const r = new Date(d.getTime());
        r.setDate(r.getDate() + days);
        return root.makeDate(r.getFullYear(), r.getMonth(), r.getDate());
    }

    // range by absolute day count (works across month boundaries)
    function rangeBetween(a, b) {
        if (!a || !b) return [];
        const out = [];
        const start = a.getTime() < b.getTime() ? a : b;
        const end = a.getTime() < b.getTime() ? b : a;
        let cur = start;
        while (cur.getTime() <= end.getTime()) {
            out.push(root.makeDate(cur.getFullYear(), cur.getMonth(), cur.getDate()));
            cur = root.addDays(cur, 1);
        }
        return out;
    }

    // drag-range selection state
    property int anchorCell: -1
    property int currentCell: -1
    property bool dragging: false
    readonly property var dragRange: root.dragging
        ? root.rangeBetween(root.dateForCell(root.anchorCell), root.dateForCell(root.currentCell))
        : []

    function inDragRange(d) {
        if (!d || !root.dragging) return false;
        return root.dragRange.some((s) => root.isSameDay(s, d));
    }

    Column {
        anchors.fill: parent
        spacing: 10

        // Month navigation header
        Row {
            width: parent.width
            height: 40
            spacing: 6

            RippleButton {
                width: 40; height: 40
                buttonRadius: 20
                colBackground: "transparent"
                colBackgroundHover: Appearance.m3colors.m3surfaceVariant
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "chevron_left"
                    iconSize: Appearance.font.pixelSize.title
                    color: Appearance.m3colors.m3onBackground
                }
                onClicked: root.shiftMonth(-1)
            }

            StyledText {
                text: root.monthLabel
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: Appearance.m3colors.m3onBackground
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                width: parent.width - 152
                height: 40
            }

            RippleButton {
                width: 40; height: 40
                buttonRadius: 20
                colBackground: "transparent"
                colBackgroundHover: Appearance.m3colors.m3surfaceVariant
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "chevron_right"
                    iconSize: Appearance.font.pixelSize.title
                    color: Appearance.m3colors.m3onBackground
                }
                onClicked: root.shiftMonth(1)
            }

            RippleButton {
                width: 56; height: 40
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.m3colors.m3surfaceVariant
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Today")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.m3colors.m3primary
                    horizontalAlignment: Text.AlignHCenter
                }
                onClicked: {
                    const t = new Date();
                    root.displayYear = t.getFullYear();
                    root.displayMonth = t.getMonth();
                }
            }
        }

        // Weekday labels row
        Row {
            width: parent.width
            height: 26
            Repeater {
                model: root.weekdayLabels
                StyledText {
                    width: root.cellSize
                    text: modelData
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.m3colors.m3outline
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Day grid + interaction layer
        Item {
            width: parent.width
            height: root.cellSize * 6

            Repeater {
                model: 42
                delegate: Item {
                    x: (index % 7) * root.cellSize
                    y: Math.floor(index / 7) * root.cellSize
                    width: root.cellSize
                    height: root.cellSize

                    property var date: root.dateForCell(index)
                    readonly property bool valid: date !== null
                    readonly property bool isToday: valid && root.isSameDay(date, new Date())
                    readonly property bool isSelected: valid && root.isSelected(date)
                    readonly property bool inRange: valid && root.inDragRange(date)

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.cellSize - 6
                        height: root.cellSize - 6
                        radius: (root.cellSize - 6) / 2
                        color: isSelected ? Appearance.colors.colPrimary
                             : inRange    ? Appearance.colors.colPrimaryContainer
                             : isToday    ? Appearance.m3colors.m3secondaryContainer
                             : "transparent"
                        visible: valid
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: valid ? date.getDate() : ""
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: isSelected ? Font.DemiBold : Font.Normal
                        color: isSelected ? Appearance.colors.colOnPrimary
                             : inRange    ? Appearance.colors.colOnPrimaryContainer
                             : isToday    ? Appearance.m3colors.m3onSecondaryContainer
                             :              Appearance.m3colors.m3onBackground
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            MouseArea {
                id: gridMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: {
                    const d = root.dateForCell(root.cellAt(mouseX, mouseY));
                    return d ? Qt.PointingHandCursor : Qt.ArrowCursor;
                }

                function cellAt(mx, my) {
                    const col = Math.floor(mx / root.cellSize);
                    const row = Math.floor(my / root.cellSize);
                    return row * 7 + col;
                }

                onPositionChanged: (mouse) => {
                    const cell = gridMouse.cellAt(mouse.x, mouse.y);
                    if (gridMouse.pressed) {
                        root.currentCell = cell;
                        if (cell !== root.anchorCell) {
                            root.dragging = true;
                        }
                    }
                }
                onPressed: (mouse) => {
                    root.anchorCell = gridMouse.cellAt(mouse.x, mouse.y);
                    root.currentCell = root.anchorCell;
                    root.dragging = false;
                }
                onReleased: (mouse) => {
                    const cell = gridMouse.cellAt(mouse.x, mouse.y);
                    root.currentCell = cell;
                    const anchorDate = root.dateForCell(root.anchorCell);
                    const releaseDate = root.dateForCell(cell);

                    if (root.dragging) {
                        if (root.multiSelect) {
                            if (anchorDate && releaseDate) {
                                root.setSelection(root.rangeBetween(anchorDate, releaseDate));
                            }
                        } else if (releaseDate) {
                            root.setSelection([releaseDate]);
                        }
                    } else if (anchorDate) {
                        if (root.multiSelect) {
                            root.toggleDate(anchorDate);
                        } else {
                            root.setSelection([anchorDate]);
                        }
                    }
                    root.dragging = false;
                    root.anchorCell = -1;
                    root.currentCell = -1;
                }
            }
        }

        // Selection summary + chips (multiSelect only)
        Column {
            width: parent.width
            spacing: 6
            visible: root.multiSelect

            Item {
                width: parent.width
                height: 26

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedCount === 0
                        ? qsTr("No dates selected")
                        : root.selectedCount === 1
                            ? qsTr("1 date selected")
                            : root.selectedCount + qsTr(" dates selected")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.m3colors.m3onSurfaceVariant
                }

                RippleButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    buttonRadius: Appearance.rounding.full
                    visible: root.selectedCount > 0
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.m3colors.m3surfaceVariant
                    contentItem: StyledText {
                        anchors.centerIn: parent
                        text: qsTr("Clear all")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.m3colors.m3error
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: root.clearSelection()
                }
            }

            Flow {
                width: parent.width
                spacing: 6
                visible: root.selectedCount > 0
                Repeater {
                    model: root.selectedDates
                    delegate: Rectangle {
                        property var date: modelData
                        height: 30
                        width: chipRow.implicitWidth + 14
                        radius: 15
                        color: Appearance.m3colors.m3secondaryContainer

                        Row {
                            id: chipRow
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDate(modelData, "d MMM")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.m3colors.m3onSecondaryContainer
                            }

                            RippleButton {
                                width: 18; height: 18
                                buttonRadius: 9
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.m3colors.m3onSecondaryContainer
                                anchors.verticalCenter: parent.verticalCenter
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "close"
                                    iconSize: 12
                                    color: Appearance.m3colors.m3onSecondaryContainer
                                }
                                onClicked: root.toggleDate(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    function shiftMonth(delta) {
        let m = root.displayMonth + delta;
        let y = root.displayYear;
        if (m < 0) { m = 11; y -= 1; }
        if (m > 11) { m = 0; y += 1; }
        root.displayYear = y;
        root.displayMonth = m;
    }
}
