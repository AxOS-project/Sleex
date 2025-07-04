const { GLib } = imports.gi;
import Widget from "resource:///com/github/Aylur/ags/widget.js";
import * as Utils from "resource:///com/github/Aylur/ags/utils.js";
const { execAsync, exec } = Utils;
const { Box, EventBox, Label, Revealer, Overlay } = Widget;
import { AnimatedCircProg } from "../.commonwidgets/cairo_circularprogress.js";
import { MaterialIcon } from "../.commonwidgets/materialicon.js";

const createResourceValue = (
     name,
     icon,
     interval,
     valueUpdateCmd,
     displayFunc,
     props = {}
) =>
     Box({
          ...props,
          className: "bg-system-bg txt",
          children: [
               Revealer({
                    transition: "slide_left",
                    transitionDuration: userOptions.animations.durationLarge,
                    child: Box({
                         vpack: "center",
                         vertical: true,
                         className: "margin-right-15",
                         children: [
                              Label({
                                   xalign: 1,
                                   className: "txt-small txt",
                                   label: `${name}`,
                              }),
                              Label({
                                   xalign: 1,
                                   className:
                                        "titlefont txt-norm txt-onSecondaryContainer",
                                   setup: (self) =>
                                        self.poll(interval, (label) =>
                                             displayFunc(label)
                                        ),
                              }),
                         ],
                    }),
               }),
               Overlay({
                    child: AnimatedCircProg({
                         className: "bg-system-circprog",
                         extraSetup: (self) =>
                              self.poll(interval, (self) => {
                                   execAsync([
                                        "bash",
                                        "-c",
                                        `${valueUpdateCmd}`,
                                   ])
                                        .then((newValue) => {
                                             self.css = `font-size: ${Math.round(
                                                  newValue
                                             )}px;`;
                                        })
                                        .catch(print);
                              }),
                    }),
                    overlays: [MaterialIcon(`${icon}`, "hugeass")],
                    setup: (self) =>
                         self.set_overlay_pass_through(
                              self.get_children()[1],
                              true
                         ),
               }),
          ],
     });

const createResources = () =>
     Box({
          vpack: "fill",
          vertical: true,
          className: "spacing-v-15",
          children: [
               createResourceValue(
                    "Memory",
                    "memory",
                    10000,
                    `free | awk '/^Mem/ {printf("%.2f\\n", ($3/$2) * 100)}'`,
                    (label) => {
                         execAsync([
                              "bash",
                              "-c",
                              `free -h | awk '/^Mem/ {print $3 " / " $2}' | sed 's/Gi/Gib/g'`,
                         ])
                              .then((output) => {
                                   label.label = `${output}`;
                              })
                              .catch(print);
                    },
                    { hpack: "end" }
               ),
               createResourceValue(
                    "Disk space",
                    "hard_drive_2",
                    3600000,
                    `echo $(df --output=pcent / | tr -dc '0-9')`,
                    (label) => {
                         execAsync([
                              "bash",
                              "-c",
                              `df -h --output=avail / | awk 'NR==2{print $1}'`,
                         ])
                              .then((output) => {
                                   label.label = `${output} available`;
                              })
                              .catch(print);
                    },
                    { hpack: "end" }
               ),
          ],
     });

const createDistroAndVersion = () =>
     Box({
          vertical: true,
          children: [
               Box({
                    hpack: "end",
                    children: [
                         Label({
                              className: "bg-distro-txt",
                              xalign: 0,
                              label: "Currently on ",
                         }),
                         Label({
                              className: "bg-distro-name",
                              xalign: 0,
                              label: "<distro>",
                              setup: (label) => {
                                   execAsync([
                                        `grep`,
                                        `-oP`,
                                        `PRETTY_NAME="\\K[^"]+`,
                                        `/etc/os-release`,
                                   ])
                                        .then((distro) => {
                                             label.label = distro;
                                        })
                                        .catch(print);
                              },
                         }),
                         Label({
                              className: "bg-distro-txt",
                              xalign: 0,
                              label: " ",
                         }),
                         Label({
                              className: "bg-distro-txt",
                              xalign: 0,
                              label: "UNKNOWN",
                              setup: (label) => {
                                   execAsync([
                                        `cat`,
                                        `/etc/axos-version`
                                   ])
                                        .then((distro) => {
                                             label.label = distro;
                                        })
                                        .catch(print);
                              },
                         }),
                    ],
               }),
          ],
     });

export default () => {
     // Create instances of the components when the main component is created
     const resources = createResources();
     const distroAndVersion = createDistroAndVersion();

     return Box({
          hpack: "end",
          vpack: "end",
          children: [
               EventBox({
                    child: Box({
                         hpack: "end",
                         vpack: "end",
                         className: "bg-distro-box spacing-v-20",
                         vertical: true,
                         children: [resources, distroAndVersion],
                    }),
                    onPrimaryClickRelease: () => {
                         const kids = resources.get_children();
                         for (let i = 0; i < kids.length; i++) {
                              const child = kids[i];
                              const firstChild = child.get_children()[0];
                              firstChild.revealChild = !firstChild.revealChild;
                         }
                    },
               }),
          ],
     });
};
