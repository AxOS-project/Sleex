import Widget from "resource:///com/github/Aylur/ags/widget.js";
const { Box, Button, Label } = Widget;
import { MaterialIcon } from "../../.commonwidgets/materialicon.js";
import { setupCursorHover } from "../../.widgetutils/cursorhover.js";

import { getCalendarLayout } from "./calendar_layout.js";

let calendarJson = getCalendarLayout(undefined, true);
let monthshift = 0;

function getDateInXMonthsTime(x) {
     var currentDate = new Date(); // Get the current date
     var targetMonth = currentDate.getMonth() + x; // Calculate the target month
     var targetYear = currentDate.getFullYear(); // Get the current year

     // Adjust the year and month if necessary
     targetYear += Math.floor(targetMonth / 12);
     targetMonth = ((targetMonth % 12) + 12) % 12;

     // Create a new date object with the target year and month
     var targetDate = new Date(targetYear, targetMonth, 1);

     // Set the day to the last day of the month to get the desired date
     // targetDate.setDate(0);

     return targetDate;
}

const weekDays = [
     // MONDAY IS THE FIRST DAY OF THE WEEK :HESRIGHTYOUKNOW:
     { day: "Mo", today: 0 },
     { day: "Tu", today: 0 },
     { day: "We", today: 0 },
     { day: "Th", today: 0 },
     { day: "Fr", today: 0 },
     { day: "Sa", today: 0 },
     { day: "Su", today: 0 },
];

const CalendarDay = (day, today) =>
     Widget.Button({
          className: `sidebar-calendar-btn ${
               today == 1
                    ? "sidebar-calendar-btn-today"
                    : today == -1
                    ? "sidebar-calendar-btn-othermonth"
                    : ""
          }`,
          child: Widget.Overlay({
               child: Box({}),
               overlays: [
                    Label({
                         hpack: "center",
                         className:
                              "txt-smallie txt-semibold sidebar-calendar-btn-txt",
                         label: String(day),
                    }),
               ],
          }),
     });

const CalendarWidget = () => {
     const calendarMonthYear = Widget.Button({
          className: "txt txt-large sidebar-calendar-monthyear-btn",
          onClicked: () => shiftCalendarXMonths(0),
          setup: (button) => {
               button.label = `${new Date().toLocaleString("default", {
                    month: "long",
               })} ${new Date().getFullYear()}`;
               setupCursorHover(button);
          },
     });
     const addCalendarChildren = (box, calendarJson) => {
          const children = box.get_children();
          for (let i = 0; i < children.length; i++) {
               const child = children[i];
               child.destroy();
          }
          box.children = calendarJson.map((row, i) =>
               Widget.Box({
                    className: "spacing-h-5",
                    children: row.map((day, i) =>
                         CalendarDay(day.day, day.today)
                    ),
               })
          );
     };
     function shiftCalendarXMonths(x) {
          if (x == 0) monthshift = 0;
          else monthshift += x;
          var newDate;
          if (monthshift == 0) newDate = new Date();
          else newDate = getDateInXMonthsTime(monthshift);

          calendarJson = getCalendarLayout(newDate, monthshift == 0);
          calendarMonthYear.label = `${
               monthshift == 0 ? "" : "• "
          }${newDate.toLocaleString("default", {
               month: "long",
          })} ${newDate.getFullYear()}`;
          addCalendarChildren(calendarDays, calendarJson);
     }
     const calendarHeader = Widget.Box({
          className: "spacing-h-5 sidebar-calendar-header",
          setup: (box) => {
               box.pack_start(calendarMonthYear, false, false, 0);
               box.pack_end(
                    Widget.Box({
                         className: "spacing-h-5",
                         children: [
                              Button({
                                   className: "sidebar-calendar-monthshift-btn",
                                   onClicked: () => shiftCalendarXMonths(-1),
                                   child: MaterialIcon("chevron_left", "norm"),
                                   setup: setupCursorHover,
                              }),
                              Button({
                                   className: "sidebar-calendar-monthshift-btn",
                                   onClicked: () => shiftCalendarXMonths(1),
                                   child: MaterialIcon("chevron_right", "norm"),
                                   setup: setupCursorHover,
                              }),
                         ],
                    }),
                    false,
                    false,
                    0
               );
          },
     });
     const calendarDays = Widget.Box({
          hexpand: true,
          vertical: true,
          className: "spacing-v-5",
          setup: (box) => {
               addCalendarChildren(box, calendarJson);
          },
     });
     return Widget.EventBox({
          onScrollUp: () => shiftCalendarXMonths(-1),
          onScrollDown: () => shiftCalendarXMonths(1),
          child: Widget.Box({
               hpack: "center",
               children: [
                    Widget.Box({
                         hexpand: true,
                         vertical: true,
                         className: "spacing-v-5",
                         children: [
                              calendarHeader,
                              Widget.Box({
                                   homogeneous: true,
                                   className: "spacing-h-5",
                                   children: weekDays.map((day, i) =>
                                        CalendarDay(day.day, day.today)
                                   ),
                              }),
                              calendarDays,
                         ],
                    }),
               ],
          }),
     });
};

export const ModuleCalendar = () =>
     Box({
          className: "calendar spacing-h-5 dash-widget",
          child: CalendarWidget(),
     });
