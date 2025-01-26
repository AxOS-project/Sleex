// This is for the right pills of the bar.
import Widget from "resource:///com/github/Aylur/ags/widget.js";
import * as Utils from "resource:///com/github/Aylur/ags/utils.js";
const { Box, Label, Button, Stack } = Widget;
const { execAsync } = Utils;
const { GLib } = imports.gi;
import Battery from "resource:///com/github/Aylur/ags/service/battery.js";
import { MaterialIcon } from "../../.commonwidgets/materialicon.js";
import { WWO_CODE, WEATHER_SYMBOL } from "../../.commondata/weather.js";

const WEATHER_CACHE_FOLDER = `${GLib.get_user_cache_dir()}/ags/weather`;
Utils.exec(`mkdir -p ${WEATHER_CACHE_FOLDER}`);

const time = Variable("", {
  poll: [
    userOptions.time.interval,
    () => GLib.DateTime.new_now_local().format(userOptions.time.format),
  ],
});

const date = Variable("", {
  poll: [
    userOptions.time.dateInterval,
    () => GLib.DateTime.new_now_local().format(userOptions.time.dateFormatLong),
  ],
});

const showTimeDate = () => {
    const TIMEDATE_FILE_LOCATION = `${GLib.get_user_state_dir()}/ags/user/show_timedate.txt`;
    const actual_show_timedate = Utils.exec(`bash -c "cat ${TIMEDATE_FILE_LOCATION}"`);
    actual_show_timedate == null ? actual_show_timedate = userOptions.appearance.showTimeDate : actual_show_timedate;
    return actual_show_timedate == 'true' ? true : false;
}
const BarClock = () => {
  if (!showTimeDate()) return null;
  else return Widget.Box({
    vpack: "center",
    className: "spacing-h-4 bar-clock-box",
    children: [
      Widget.Label({
        className: "bar-time",
        label: time.bind(),
      }),
      Widget.Label({
        className: "txt-norm txt-onLayer1",
        label: "•",
      }),
      Widget.Label({
        className: "txt-smallie bar-date",
        label: date.bind(),
      }),
    ],
  });
};

const UtilButton = ({ name, icon, onClicked }) =>
  Button({
    vpack: "center",
    tooltipText: name,
    onClicked: onClicked,
    className: "bar-util-btn icon-material txt-norm",
    label: `${icon}`,
  });

const Utilities = () =>
  Box({
    hpack: "center",
    className: "spacing-h-4",
    children: [
      UtilButton({
        name: "Screen snip",
        icon: "screenshot_region",
        onClicked: () => {
          Utils.execAsync(
            `${App.configDir}/scripts/grimblast.sh copy area`
          ).catch(print);
        },
      }),
      UtilButton({
        name: "Color picker",
        icon: "colorize",
        onClicked: () => {
          Utils.execAsync(["hyprpicker", "-a"]).catch(print);
        },
      }),
    ],
  });

const BarGroup = ({ child }) =>
  Widget.Box({
    className: "bar-group-margin bar-sides",
    children: [
      Widget.Box({
        className: "bar-group bar-group-standalone bar-group-pad-system",
        children: [child],
      }),
    ],
  });

const WeatherWidget = () =>
  Box({
    hexpand: true,
    hpack: "center",
    className: "spacing-h-4 txt-onSurfaceVariant",
    children: [
      MaterialIcon("device_thermostat", "small"),
      Label({
        label: "Weather",
      }),
    ],
    setup: (self) =>
      self.poll(900000, async (self) => {
        const WEATHER_CACHE_PATH = WEATHER_CACHE_FOLDER + "/wttr.in.txt";
        const updateWeatherForCity = (city) =>
          execAsync(
            `curl https://wttr.in/${city.replace(/ /g, "%20")}?format=j1`
          )
            .then((output) => {
              const weather = JSON.parse(output);
              Utils.writeFile(
                JSON.stringify(weather),
                WEATHER_CACHE_PATH
              ).catch(print);
              const weatherCode = weather.current_condition[0].weatherCode;
              const weatherDesc =
                weather.current_condition[0].weatherDesc[0].value;
              const temperature =
                weather.current_condition[0][
                  `temp_${userOptions.weather.preferredUnit}`
                ];
              const feelsLike =
                weather.current_condition[0][
                  `FeelsLike${userOptions.weather.preferredUnit}`
                ];
              const weatherSymbol = WEATHER_SYMBOL[WWO_CODE[weatherCode]];
              self.children[0].label = weatherSymbol;
              self.children[1].label = `${temperature}°${userOptions.weather.preferredUnit} • Feels like ${feelsLike}°${userOptions.weather.preferredUnit}`;
              self.tooltipText = weatherDesc;
            })
            .catch((err) => {
              try {
                // Read from cache
                const weather = JSON.parse(Utils.readFile(WEATHER_CACHE_PATH));
                const weatherCode = weather.current_condition[0].weatherCode;
                const weatherDesc =
                  weather.current_condition[0].weatherDesc[0].value;
                const temperature =
                  weather.current_condition[0][
                    `temp_${userOptions.weather.preferredUnit}`
                  ];
                const feelsLike =
                  weather.current_condition[0][
                    `FeelsLike${userOptions.weather.preferredUnit}`
                  ];
                const weatherSymbol = WEATHER_SYMBOL[WWO_CODE[weatherCode]];
                self.children[0].label = weatherSymbol;
                self.children[1].label = `${temperature}°${userOptions.weather.preferredUnit} • Feels like ${feelsLike}°${userOptions.weather.preferredUnit}`;
                self.tooltipText = weatherDesc;
              } catch (err) {
                print(err);
              }
            });
        if (
          userOptions.weather.city != "" &&
          userOptions.weather.city != null
        ) {
          updateWeatherForCity(userOptions.weather.city.replace(/ /g, "%20"));
        } else {
          Utils.execAsync("curl ipinfo.io")
            .then((output) => {
              return JSON.parse(output)["city"].toLowerCase();
            })
            .then(updateWeatherForCity)
            .catch(print);
        }
      }),
  });

// Bat or weather
const WeatherModule = () =>
  Stack({
    transition: "slide_up_down",
    transitionDuration: userOptions.animations.durationLarge,
    children: {
      laptop: Box({
        className: "spacing-h-4",
        children: [
          // BarGroup({ child: Utilities() }),
          BarGroup({ child: WeatherWidget() }),
        ],
      }),
    },
    setup: (stack) =>
      Utils.timeout(10, () => {
        if (!Battery.available) stack.shown = "desktop";
        else stack.shown = "laptop";
      }),
  });

const switchToRelativeWorkspace = async (self, num) => {
  try {
    const Hyprland = (
      await import("resource:///com/github/Aylur/ags/service/hyprland.js")
    ).default;
    Hyprland.messageAsync(
      `dispatch workspace ${num > 0 ? "+" : ""}${num}`
    ).catch(print);
  } catch {
    execAsync([
      `${App.configDir}/scripts/sway/swayToRelativeWs.sh`,
      `${num}`,
    ]).catch(print);
  }
};

const ShowWeather = () => {
  const WEATHER_FILE_LOCATION = `${GLib.get_user_state_dir()}/ags/user/show_weather.txt`;
  const actual_show_weather = Utils.exec(`bash -c "cat ${WEATHER_FILE_LOCATION}"`);
  return actual_show_weather == 'true' ? true : false;
}

export default () =>
  Widget.EventBox({
    onScrollUp: (self) => switchToRelativeWorkspace(self, -1),
    onScrollDown: (self) => switchToRelativeWorkspace(self, +1),
    onPrimaryClick: () => App.toggleWindow("sideright"),
    child: Widget.Box({
      children: [
        BarGroup({ child: BarClock() }),
        ShowWeather() ? WeatherModule() : null,
      ],
    }),
  });