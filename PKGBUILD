pkgname="sleex"
pkgver="1.15"
pkgrel="1"
pkgdesc="Third desktop environment for AxOS"
arch=("x86_64")
depends=(
	# "sleex-ags"
	"sleex-audio"
	"sleex-backlight"
	"sleex-basic"
	"sleex-bibata-modern-classic-bin"
	"sleex-fonts-themes"
	"sleex-hyprland"
	"sleex-kde"
	"sleex-microtex-git"
	"sleex-portal"
	"sleex-python"
	"sleex-screencapture"
	"sleex-toolkit"
	"sleex-widgets"
	"sleex-user-config"

	"libnm"
	"gio-qt"
	"qt6-connectivity"
)
# optdepends=(
# 	"sleex-optional: Optional packages"
# )

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

