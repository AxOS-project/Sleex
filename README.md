<p align="center">
  <a href="https://axos-project.github.io"><img src="https://github.com/user-attachments/assets/a64a60d1-c4ec-4fdf-a1df-ce4bde3890ce" width="512" alt="AxOS"></a>
</p>

Sleex is the third desktop environement of AxOS. It is based on Hyprland with Quickshell.

## Features
- AI chat integration with external providers (Gemini, OpenAI...)
- Smooth animations
- Tiling window management for seamless multitasking
- Adaptative color scheme based on the wallpaper
- Ready to use
- Multiple available built in tools
- Looks good

|      |
|------|
| ![preview](preview.mp4) |

## Installation

> [!IMPORTANT]
> If you already have an hyprland config, this will erase it.

If you are using AxOS, you can simply use epsilon:
```
epsi i sleex
```

# Cross distro

- Clone this repo
- Build every sleex meta-packages in `sleex-packages` then install them
- Build the user configuration in the `sleex-user-config` and copy the user files to your home dir with `cp -r /etc/skel/.config/* ~/.config`.
- Build and install the main package

Then, you can start sleex by selecting the sleex session on your greeter

## License
Sleex is licensed under the GNU General Public License v3.0

## Special thanks
- [@end-4](https://github.com/end-4/): Great inspiration | Sleex is based on his work
- [@xHyperVoid](https://github.com/xHyperVoid): Designer | Made the logo and the wallpapers
