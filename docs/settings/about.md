# About Sleex & System Information User Experience

The About Settings page (`src/share/sleex/modules/settings/About.qml`) provides a visual summary of the operating system, Linux kernel, active Material 3 color palette chips, hardware specifications, and project community resources.

---

## 1. Operating System Banner

```
+-----------------------------------------------------------------------------------------------+
|  Distro Information                                                                           |
|                                                                                               |
|  +-------------+   <b>AxOS Linux</b>                                                          |
|  |             |   Kernel: 6.12.4-arch1-1 (x86_64)                                            |
|  |  (OS Logo)  |                                                                              |
|  |             |   Material 3 Color Palette:                                                  |
|  +-------------+   ( Primary ) ( Secondary ) ( Tertiary ) ( Error ) ( Surface ) ( Outline )   |
|                                                                                               |
|  [ 🌐 Website ]    [ 🐙 GitHub ]    [ 📖 Docs ]    [ 🐛 Report an Issue ]                     |
+-----------------------------------------------------------------------------------------------+
```

- **Distribution Emblem**: Displays the high-resolution vector emblem of the running Linux distribution (AxOS, Arch, NixOS, Fedora, Debian, Ubuntu, etc.) via `SystemInfo.logo`.
- **Distribution Name & Version**: Large bold heading with the OS release name.
- **Kernel & Architecture**: Current running Linux kernel release and system architecture.
- **Active Color Palette Swatch**:
  - Displays a row of overlapping circular chips rendering the currently active Material 3 color variables:
    - Primary (`m3primary`)
    - Secondary (`m3secondary`)
    - Tertiary (`m3tertiary`)
    - Error (`m3error`)
    - Primary Container (`m3primaryContainer`)
    - Secondary Container (`m3secondaryContainer`)
- **Quick Links Buttons**:
  - `Website`: Opens official project website in the default browser.
  - `GitHub`: Direct link to repository source code.
  - `Docs`: Launches local or online documentation.
  - `Report an Issue`: Quick shortcut to GitHub issue tracker.

---

## 2. Hardware Specifications Summary

Below the OS banner, the About page queries `SystemInfo` to display a clean hardware breakdown:

```
+-----------------------------------------------------------------------------------------------+
|  Hardware Details                                                                             |
|                                                                                               |
|  • Device Model:   Lenovo ThinkPad X1 Carbon Gen 10                                           |
|  • Processor (CPU):12th Gen Intel(R) Core(TM) i7-1260P (16 cores)                             |
|  • Graphics (GPU): Intel(R) Iris(R) Xe Graphics (ADL GT2)                                     |
|  • Memory (RAM):   16.0 GB (15.4 GB usable)                                                   |
|  • Window System:  Wayland (Hyprland Compositor)                                              |
+-----------------------------------------------------------------------------------------------+
```

- **Processor**: Full CPU brand string and total physical/logical core count.
- **Graphics Card**: Dedicated or integrated GPU device identifier.
- **Memory**: Installed physical RAM formatted in Gigabytes.
- **Display Server**: Confirms active Wayland session running on Hyprland with Quickshell.
