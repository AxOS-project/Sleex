pkgname="sleex"
pkgver="1.16"
pkgrel="1"
pkgdesc="Desktop environment focused on aesthetics and performance"
arch=("x86_64")
depends=(
	# Audio
	'cava' 'pavucontrol-qt' 'wireplumber' 'libdbusmenu-gtk3' 'playerctl'
	# Backlight
	'hyprsunset' 'geoclue' 'brightnessctl' 'ddcutil'
	# Basic
	"axel" "bc" "coreutils" "cliphist" "cmake" "curl" "rsync" "wget" "ripgrep" "jq" "meson" "xdg-user-dirs" "foot" "power-profiles-daemon" "mission-center" "kvantum" "inotify-tools" "lm_sensors"
	# Cursor
	"sleex-bibata-modern-classic-bin"
	# Fonts & Themes
	'adw-gtk-theme' 'breeze-plus' 'eza' 'fish' 'fontconfig' 'kde-material-you-colors' 'kitty' 'matugen-bin' 'starship' 'ttf-gabarito-git' 'ttf-jetbrains-mono-nerd' 'ttf-material-design-icons-extended' 'ttf-material-symbols-variable' 'ttf-readex-pro' 'ttf-rubik-vf' 'ttf-twemoji'
	# Hyprland dependencies
	'hyprutils' 'hyprpicker' 'hyprlang' 'hypridle' 'hyprland-qt-support' 'hyprland-qtutils' 'hyprcursor' 'hyprwayland-scanner' 'hyprland' 'xdg-desktop-portal-hyprland' 'wl-clipboard' 'hyprlock'
	# QT/KDE dependencies
	'bluedevil' 'gnome-keyring' 'networkmanager' 'plasma-nm' 'polkit-kde-agent' 'pcmanfm-qt' 'kwrite' "libnm" "gio-qt" "qt6-connectivity"
	# Microtex
	"sleex-microtex-git"
	# Portal
	'xdg-desktop-portal'
	# Python deps
	'clang' 'uv' 'gtk4' 'libadwaita' 'libsoup3' 'libportal-gtk4' 'gobject-introspection' 'sassc' 'python-setproctitle' 'python-pywayland'
	# Screencast/Screenrecord
	'hyprshot' 'ksnip' 'wf-recorder' 'slurp' 'grim' 'tesseract' 'tesseract-data-eng'
	# Tools
	'kdialog' 'qt6-5compat' 'qt6-avif-image-plugin' 'qt6-base' 'qt6-declarative' 'qt6-imageformats' 'qt6-multimedia' 'qt6-positioning' 'qt6-quicktimeline' 'qt6-sensors' 'qt6-svg' 'qt6-tools' 'qt6-translations' 'qt6-virtualkeyboard' 'qt6-wayland' 'syntax-highlighting' 'upower' 'wtype' 'ydotool' 'fprintd'
	# Widgets
	'fuzzel' 'nm-connection-editor' 'quickshell' 'swww' 'translate-shell' 'wlogout'
	# User config
	"sleex-user-config"
)
optdepends=(
	"hyprwayland-scanner: Wayland protocol scanner for Hyprland"
	"neofetch: Fancy system info in your terminal"
	"firefox: Web browser"
	"pipewire-pulse: PulseAudio replacement via PipeWire"
	"papirus-icon-theme: Pretty icons"
	"inxi: Show system info like a nerd"
	"power-profiles-daemon: Manage power profiles"
	"fwupd: Firmware updater for Linux"
	"gnome-autoar: Automatic archive handling in GNOME"
	"overskride: Bluetooth stuff"
	"gnome-system-monitor: Task manager but GNOMEy"
	"baobab: Disk usage analyzer"
	"gparted: Partition editor"
	"gnome-calculator: Yep, a calculator"
	"loupe: Image viewer"
	"nwg-displays: Display arrangement tool"
)

build() {
    cd "$srcdir/share/sleex"
    cmake -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j
}

package() {
    mkdir -p "$pkgdir/usr/bin"
    cp -r "$srcdir/bin/"* "$pkgdir/usr/bin/"

    mkdir -p "$pkgdir/usr/share/sleex"
    cd "$srcdir/share/sleex"
    cmake --install build --prefix "$pkgdir/"
    rm -rf build
    cp -r "$srcdir/share/sleex/" "$pkgdir/usr/share/"

    mkdir -p "$pkgdir/usr/share/wayland-sessions"
    cp -r "$srcdir/share/wayland-sessions/"* "$pkgdir/usr/share/wayland-sessions/"
}