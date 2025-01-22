const { GLib } = imports.gi;
import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';

const { exec, execAsync } = Utils;
const { Box, Label, Button } = Widget;
import { setupCursorHover } from '../.widgetutils/cursorhover.js';
import { quickLaunchItems } from './data_quicklaunches.js'

const TimeAndDate = () => Box({
    vertical: true,
    className: 'spacing-v--5',
    children: [
        Label({
            className: 'bg-time-clock',
            xalign: 0,
            label: GLib.DateTime.new_now_local().format(userOptions.time.format),
            setup: (self) => self.poll(userOptions.time.interval, label => {
                label.label = GLib.DateTime.new_now_local().format(userOptions.time.format);
            }),
        }),
        Label({
            className: 'bg-time-date',
            xalign: 0,
            label: GLib.DateTime.new_now_local().format(userOptions.time.dateFormatLong),
            setup: (self) => self.poll(userOptions.time.dateInterval, (label) => {
                label.label = GLib.DateTime.new_now_local().format(userOptions.time.dateFormatLong);
            }),
        }),
    ]
})

const QuickLaunches = () => Box({
    vertical: true,
    className: 'spacing-v-10',
    children: [
        Label({
            xalign: 0,
            className: 'bg-quicklaunch-title',
            label: 'Quick Launches',
        }),
        Box({
            hpack: 'start',
            className: 'spacing-h-5',
            children: quickLaunchItems.map((item, i) => Button({
                onClicked: () => {
                    execAsync(['bash', '-c', `${item["command"]}`]).catch(print);
                },
                className: 'bg-quicklaunch-btn',
                child: Label({
                    label: `${item["name"]}`,
                }),
                setup: (self) => {
                    setupCursorHover(self);
                }
            })),
        })
    ]
})

const getBarPosition = () => {
    const BARPOS_FILE_LOCATION = `${GLib.get_user_state_dir()}/ags/user/bar_position.txt`;
    const actualPos = exec(`bash -c "cat ${BARPOS_FILE_LOCATION}"`);
    const currentVpack = actualPos == 'top' ? 'end' : 'start';
    return currentVpack;
}

export default () => Box({
    hpack: 'start',
    vpack: getBarPosition(),
    vertical: true,
    className: 'bg-time-box spacing-h--10',
    children: [
        TimeAndDate(),
        // QuickLaunches(),
    ],
})

