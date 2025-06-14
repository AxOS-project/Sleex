const { GLib } = imports.gi;
import App from 'resource:///com/github/Aylur/ags/app.js';
import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import Brightness from '../../../services/brightness.js';
import Indicator from '../../../services/indicator.js';
import * as Utils from "resource:///com/github/Aylur/ags/utils.js";
const { exec } = Utils;
import { RoundedCorner } from "../../.commonwidgets/cairo_roundedcorner.js";

const WindowTitle = async () => {
    try {
        const Hyprland = (await import('resource:///com/github/Aylur/ags/service/hyprland.js')).default;
        return Widget.Scrollable({
            hexpand: true, vexpand: true,
            hscroll: 'automatic', vscroll: 'never',
            child: Widget.Box({
                vertical: true,
                children: [
                    Widget.Label({
                        xalign: 0,
                        truncate: 'end',
                        maxWidthChars: 1, // Doesn't matter, just needs to be non negative
                        className: 'txt-smaller bar-wintitle-topdesc txt',
                        setup: (self) => self.hook(Hyprland.active.client, label => {
                            label.label = Hyprland.active.client.class.length === 0 ? 'Desktop' : Hyprland.active.client.class;
                        }),
                    }),
                    Widget.Label({
                        xalign: 0,
                        truncate: 'end',
                        maxWidthChars: 1, // Doesn't matter, just needs to be non negative
                        className: 'txt-smallie bar-wintitle-txt',
                        setup: (self) => {
                            self.hook(Hyprland.active.client, label => {
                                label.label = Hyprland.active.client.title.length === 0 ? `Workspace ${Hyprland.active.workspace.id}` : Hyprland.active.client.title;
                            });
                            self.hook(Hyprland.active.workspace, label => {
                                label.label = Hyprland.active.client.title.length === 0 ? `Workspace ${Hyprland.active.workspace.id}` : Hyprland.active.client.title;
                            });
                        }
                    })
                ]
            })
        });
    } catch {
        return null;
    }
}

const ShowWindowTitle = () => {
    const WINTITLE_FILE_LOCATION = `${GLib.get_user_state_dir()}/ags/user/show_wintitle.txt`;
    const actual_show_wintitle = exec(`bash -c "cat ${WINTITLE_FILE_LOCATION}"`);
    actual_show_wintitle == null ? actual_show_wintitle = userOptions.appearance.showWinTitle : actual_show_wintitle;
    return actual_show_wintitle == 'true' ? true : false;
}

export default async (monitor = 0) => {
    let optionalWindowTitleInstance = await WindowTitle();
    if (ShowWindowTitle()) return Widget.EventBox({
        onScrollUp: () => {
            Indicator.popup(1);
            Brightness[monitor].screen_value += 0.05;
        },
        onScrollDown: () => {
            Indicator.popup(1);
            Brightness[monitor].screen_value -= 0.05;
        },
        onPrimaryClick: () => {
            App.toggleWindow('applauncher');
        },
        child: Widget.Box({
            homogeneous: false,
            children: [
                Widget.Overlay({
                    overlays: [
                        Widget.Box({ hexpand: true }),
                        Widget.Box({
                            className: 'bar-sidemodule', 
                            hexpand: true,
                            children: [Widget.Box({
                                vertical: true,
                                className: 'bar-space-button bar-spaceleft',
                                children: [
                                    optionalWindowTitleInstance,
                                ]
                            })]
                        }),
                    ]
                }),
                RoundedCorner('topright', { className: 'corner', }),
                Widget.Box({ hexpand: true }),
            ]
        })
    });
    else return Widget.Box({
        children: [
            // RoundedCorner('topright', { className: 'corner', }),
            Widget.Box({ hexpand: true }),
            
        ]
    });
}
