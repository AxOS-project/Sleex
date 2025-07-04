import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';
const { execAsync, exec } = Utils;
const { Box, EventBox } = Widget;
import {
    ToggleIconBluetooth,
    ToggleIconWifi,
    ModuleNightLight,
    ModuleIdleInhibitor,
    ModuleReloadIcon,
    ModulePowerIcon,
    ModuleSettingsIcon,
} from "./widgets/quicktoggles.js";
import ModuleNotificationList from "./centermodules/notificationlist.js";
import { ModuleCalendar } from "./widgets/calendar.js";
import { getDistroIcon } from '../.miscutils/system.js';
import { ExpandingIconTabContainer } from '../.commonwidgets/tabcontainer.js';
import { checkKeybind } from '../.widgetutils/keybind.js';
import { TodoWidget } from "./widgets/todolist.js";
import { QuoteWidget } from "./widgets/quote.js";
import { MusicWidget } from './widgets/music.js';
import { WeatherWidget } from './widgets/weather.js';
import Name from "./widgets/name.js";

const centerWidgets = [
    // {
    //     name: 'Notifications',
    //     materialIcon: 'notifications',
    //     contentWidget: ModuleNotificationList,
    // },
    {
        name: 'Audio controls',
        materialIcon: 'volume_up',
        contentWidget: ModuleAudioControls,
    },
    {
        name: 'Bluetooth',
        materialIcon: 'bluetooth',
        contentWidget: ModuleBluetooth,
    },
    {
        name: 'Wifi networks',
        materialIcon: 'wifi',
        contentWidget: ModuleWifiNetworks,
        onFocus: () => execAsync('nmcli dev wifi list').catch(print),
    },
    {
        name: 'Live config',
        materialIcon: 'tune',
        contentWidget: ModuleConfigure,
    },
];

const timeRow = Box({
    className: 'spacing-h-10 sidebar-group-invisible-morehorizpad',
    children: [
        Widget.Icon({
            icon: getDistroIcon(),
            className: 'txt txt-larger',
        }),
        Widget.Label({
            hpack: 'center',
            className: 'txt-small txt',
            setup: (self) => {
            	const getUptime = async () => {
                	try {
                    	await execAsync(['bash', '-c', 'uptime -p']);
                        return execAsync(['bash', '-c', `uptime -p | sed -e 's/...//;s/ day\\| days/d/;s/ hour\\| hours/h/;s/ minute\\| minutes/m/;s/,[^,]*//2'`]);
                    } catch {
                        return execAsync(['bash', '-c', 'uptime']).then(output => {
                        	const uptimeRegex = /up\s+((\d+)\s+days?,\s+)?((\d+):(\d+)),/;
                        	const matches = uptimeRegex.exec(output);

                            if (matches) {
                            	const days = matches[2] ? parseInt(matches[2]) : 0;
                                const hours = matches[4] ? parseInt(matches[4]) : 0;
                                const minutes = matches[5] ? parseInt(matches[5]) : 0;

                                let formattedUptime = '';

                                if (days > 0) {
                                	formattedUptime += `${days} d `;
                                }
                                if (hours > 0) {
                                	formattedUptime += `${hours} h `;
                                }
                                formattedUptime += `${minutes} m`;

                                return formattedUptime;
                            } else {
                            	throw new Error('Failed to parse uptime output');
                            }
                        });
                    }
                };

                self.poll(5000, label => {
                	getUptime().then(upTimeString => {
                    	label.label = `Uptime: ${upTimeString}`;
                    }).catch(err => {
                    	console.error(`Failed to fetch uptime: ${err}`);
                    });
                });
            },
        }),
        Widget.Box({ hexpand: true }), 
        ModuleReloadIcon({ hpack: 'end' }),
        ModuleSettingsIcon({ hpack: 'end' }),
        ModulePowerIcon({ hpack: 'end' }),
    ]
});

const togglesBox = Widget.Box({
    hpack: 'center',
    className: 'sidebar-togglesbox spacing-h-5',
    children: [
        ToggleIconWifi(),
        ToggleIconBluetooth(),
        await ModuleNightLight(),
        ModuleIdleInhibitor(),
        // await ModuleCloudflareWarp(),
    ]
})

export const sidebarOptionsStack = ExpandingIconTabContainer({
    tabsHpack: 'center',
    className: 'sidebar-opt-stack',
    tabSwitcherClassName: 'sidebar-icontabswitcher',
    icons: centerWidgets.map((api) => api.materialIcon),
    names: centerWidgets.map((api) => api.name),
    children: centerWidgets.map((api) => api.contentWidget()),
    onChange: (self, id) => {
        self.shown = centerWidgets[id].name;
        if (centerWidgets[id].onFocus) centerWidgets[id].onFocus();
    }
});

const userName = exec('whoami').charAt(0).toUpperCase() + exec('whoami').slice(1);9

export default () => Box({
    vexpand: true,
    hexpand: true,
    children: [
        EventBox({
            onPrimaryClick: () => App.closeWindow('dashboard'),
            onSecondaryClick: () => App.closeWindow('dashboard'),
            onMiddleClick: () => App.closeWindow('dashboard'),
        }),
        Box({
            vertical: true,
            vexpand: true,
            className: 'dashboard spacing-v-15',
            children: [
                // Top row
                Box({
                    vertical: true,
                    className: 'spacing-v-5',
                    children: [
                        timeRow,
                        // togglesBox,
                    ]
                }),
                Widget.Box({
                    vexpand: true,
                    className: 'dashboard-tabs',
                }),

                Box({
                    className: 'spacing-v-5 spacing-h-10',
                    children: [
                        // Column 1
                        Box({
                            className: 'spacing-h-5',
                            child: ModuleNotificationList(),
                        }),
                        // Column 2
                        Box({
                            className: 'spacing-v-10',
                            hexpand: true,
                            vertical: true,
                            children: [
                                Box({
                                    className: 'greetings spacing-h-10',
                                    children: [
                                        Box({
                                            vertical: true,
                                            children: [
                                                Widget.Label({
                                                    xalign: 0,
                                                    label: `Hello, ${userName}`,
                                                    className: 'txt txt-title',
                                                }),
                                                Widget.Label({
                                                    xalign: 0,
                                                    label: 'Today is a good day to have a good day',
                                                    className: 'txt txt-medium',
                                                }),
                                            ],
                                        }),
                                        Box({
                                            className: 'greetings-img',
                                        }),
                                    ],
                                }),
                                sidebarOptionsStack,
                            ]
                        }),
                        // Column 3
                        Box({
                            vertical: true,
                            className: 'spacing-v-10',
                            children: [
                                togglesBox,
                                Box({
                                    className: 'spacing-v-5 todo-list',
                                    children: [
                                        TodoWidget(),
                                    ]
                                }),
                                ModuleCalendar(),
                            ]
                        }), 
                        // Column 4
                        Box({
                            vertical: true,
                            className: 'spacing-h-5 spacing-v-10',
                            children: [
                                QuoteWidget(),
                                MusicWidget(),
                                WeatherWidget(),
                                Name(),
                            ]
                        }),
                    ],
                }),
            ]
        }),
    ],
    setup: (self) => self
        .on('key-press-event', (widget, event) => { // Handle keybinds
            if (checkKeybind(event, userOptions.keybinds.sidebar.options.nextTab)) {
                sidebarOptionsStack.nextTab();
            }
            else if (checkKeybind(event, userOptions.keybinds.sidebar.options.prevTab)) {
                sidebarOptionsStack.prevTab();
            }
        })
    ,
});
