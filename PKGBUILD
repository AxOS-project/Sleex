pkgname="sleex"
pkgver="1.24"
pkgrel="3"
pkgdesc="Desktop environment focused on aesthetics and performance"
arch=("x86_64")
depends=(
	# Audio
	'cava' 'pavucontrol-qt' 'wireplumber' 'libdbusmenu-gtk3' 'playerctl'
	# Backlight
	'hyprsunset' 'geoclue' 'brightnessctl' 'ddcutil'
	# Basic
	"axel" "bc" "coreutils" "cliphist" "cmake" "curl" "rsync" "wget" "ripgrep" "jq" "meson" "xdg-user-dirs" "foot" "power-profiles-daemon" "mission-center" "kvantum" "inotify-tools" "lm_sensors" "qt5ct" "qt6ct"
	# Cursor
	"sleex-bibata-modern-classic-bin"
	# Fonts & Themes
	'adw-gtk-theme' 'breeze-plus' 'eza' 'fish' 'fontconfig' 'kde-material-you-colors' 'kitty' 'matugen-bin' 'starship' 'ttf-gabarito-git' 'ttf-jetbrains-mono-nerd' 'ttf-material-design-icons-extended' 'ttf-material-symbols-variable' 'ttf-readex-pro' 'ttf-rubik-vf' 'ttf-twemoji'
	# Hyprland dependencies
	'hyprutils' 'hyprpicker' 'hyprlang' 'hyprland-qt-support' 'hyprland-guiutils' 'hyprcursor' 'hyprwayland-scanner' 'hyprland' 'xdg-desktop-portal-hyprland' 'wl-clipboard' 'hyprlock'
	# QT/KDE dependencies
	'bluedevil' 'gnome-keyring' 'networkmanager' 'polkit-kde-agent' 'pcmanfm-qt' 'kwrite' "libnm" "gio-qt" "qt6-connectivity"
	# Microtex
	"sleex-microtex-git"
	# Portal
	'xdg-desktop-portal'
	# Python deps
	'clang' 'uv' 'gtk4' 'libadwaita' 'libsoup3' 'libportal-gtk4' 'gobject-introspection' 'sassc' 'python-setproctitle' 'python-pywayland'
	# Screencast/Screenrecord
	'hyprshot' 'ksnip' 'wf-recorder' 'slurp' 'grim' 'tesseract' 'tesseract-data-eng'
	# Tools
	'kdialog' 'qt6-5compat' 'qt6-avif-image-plugin' 'qt6-base' 'qt6-declarative' 'qt6-imageformats' 'qt6-multimedia' 'qt6-positioning' 'qt6-quicktimeline' 'qt6-sensors' 'qt6-svg' 'qt6-tools' 'qt6-translations' 'qt6-virtualkeyboard' 'qt6-wayland' 'syntax-highlighting' 'upower' 'wtype' 'ydotool' 'fprintd' 'khal' 'vdirsyncer' 'python-aiohttp-oauthlib' 'swappy' 'hypnos'
	# Widgets
	'fuzzel' 'nm-connection-editor' 'quickshell-git' 'swww' 'translate-shell' 'wlogout'
	# User config
	"sleex-user-config"
	# Artworks
	"sleex-artworks"
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
    rm -rf build/
    cmake -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j
}

package() {
    mkdir -p "$pkgdir/usr/bin"
    cp -r "$srcdir/bin/"* "$pkgdir/usr/bin/"

    mkdir -p "$pkgdir/etc"
    cp -r "$srcdir/etc/"* "$pkgdir/etc/"

    mkdir -p "$pkgdir/usr/share/sleex"
    cd "$srcdir/share/sleex"
    cmake --install build --prefix "$pkgdir/"
    rm -rf build
	rsync -av --exclude='.qmlls.ini' --exclude='.qt/' --exclude='.rcc/' --exclude='.vscode' --exclude='build/' --exclude='CMakeFiles/' --exclude='CMakeCache.txt' --exclude='cmake_install.cmake' --exclude='Makefile' --exclude='qml/' "$srcdir/share/sleex/" "$pkgdir/usr/share/sleex/"

    mkdir -p "$pkgdir/usr/share/wayland-sessions"
    cp -r "$srcdir/share/wayland-sessions/"* "$pkgdir/usr/share/wayland-sessions/"

	mkdir -p "$pkgdir/usr/libalpm/hooks"
	cp -r "$srcdir/share/libalpm/hooks/"* "$pkgdir/usr/libalpm/hooks/"
}
