#!/bin/bash
# Plasma build v3 — FINAL: qt6-base+wayland DONE, buduje resztę
# Użycie: cd ~/warppkgs && sudo bash scripts/plasma-build-v3.sh
set -uo pipefail
export MAKEFLAGS="-j1"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
SCRIPTDIR="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="/tmp/plasma-build-logs"
mkdir -p "$LOGDIR"
FAILED=0
BUILT=0
SKIPPED=0
FAILED_LIST=""

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; echo "  Log: $LOGDIR/$2.log"; tail -30 "$LOGDIR/$2.log" 2>/dev/null | grep -i 'error\|not found\|failed\|missing' | tail -5; }

build_pkg() {
    local cat="$1" name="$2"
    if warp -A 2>/dev/null | grep -qi "^$name "; then
        echo -e "${CYAN}[skip]${NC} $name — already installed"
        SKIPPED=$((SKIPPED+1))
        return 0
    fi
    echo -e "${CYAN}[build]${NC} $name"
    rm -rf /tmp/warp-build-*
    find "$SCRIPTDIR/$cat/$name" -name "*.wrp" -delete 2>/dev/null
    if (cd "$SCRIPTDIR/$cat" && warp -buildI "$name/") > "$LOGDIR/$name.log" 2>&1; then
        rm -rf /tmp/warp-build-*
        ok "$name"
        BUILT=$((BUILT+1))
        return 0
    else
        rm -rf /tmp/warp-build-*
        fail "$name" "$name"
        FAILED=$((FAILED+1))
        FAILED_LIST="$FAILED_LIST $name"
        return 1
    fi
}

# ============================================================
# Fix: libksysguard — wyłącz NL (libnl) i Sensors (lm-sensors)
# ============================================================
cat > "$SCRIPTDIR/desktop/libksysguard/WARPBUILD" << 'EOF'
pkgname=libksysguard
pkgver=6.2.5
description="KDE system monitor library"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,kconfig,kcoreaddons,ki18n,knewstuff,kio,kservice
makedeps=gcc,cmake,ninja,extra-cmake-modules
source=https://download.kde.org/stable/plasma/6.2.5/libksysguard-6.2.5.tar.xz
sha256=9694f3d6b5078b4d82eb8e6ed34eb20e2d109ed7c2234c59a640bc32f31c76ab

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_NL=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_Sensors=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_libpcap=ON \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
# Fix: kwin — wyłącz opcjonalne deps
# ============================================================
cat > "$SCRIPTDIR/desktop/kwin/WARPBUILD" << 'EOF'
pkgname=kwin
pkgver=6.2.5
description="KDE Plasma window manager"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,qt6-wayland,kconfig,kcoreaddons,kwindowsystem,kdbusaddons,kglobalaccel,libxkbcommon,wayland,libinput,mesa,libdrm,libxcb,kdecoration,kcmutils,kcrash,ksvg,ki18n,kiconthemes,kservice,kauth,kpackage,kcolorscheme,kirigami,kscreenlocker,libkscreen,kglobalacceld,layer-shell-qt
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools,wayland-protocols,plasma-wayland-protocols,knotifications
source=https://download.kde.org/stable/plasma/6.2.5/kwin-6.2.5.tar.xz
sha256=5cc450a6e41105c8c49929b72550b331237f96aafb294690f4707bdc5f776848

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_Breeze=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_XKB=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
# Fix: plasma-workspace — wyłącz Positioning + opcjonalne
# ============================================================
cat > "$SCRIPTDIR/desktop/plasma-workspace/WARPBUILD" << 'EOF'
pkgname=plasma-workspace
pkgver=6.2.5
description="KDE Plasma workspace components"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,qt6-svg,qt6-wayland,kwin,kconfig,kcoreaddons,kwindowsystem,kiconthemes,kservice,kio,knotifications,kpackage,polkit,elogind,dbus,wayland,fontconfig,freetype,libplasma,plasma-activities,plasma5support,krunner,baloo,ki18n,karchive,kcrash,kdbusaddons,kglobalaccel,kguiaddons,kidletime,kitemmodels,knewstuff,ksvg,kwidgetsaddons,kcmutils,kcolorscheme,kirigami,kscreenlocker,kauth,qqc2-desktop-style
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools,wayland-protocols,plasma-wayland-protocols
source=https://download.kde.org/stable/plasma/6.2.5/plasma-workspace-6.2.5.tar.xz
sha256=b82511e46f62e1b8f60b969c828c8d8d32fc7928401a70cc28c29f85f46c412f

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    sed -i '/Positioning/d' CMakeLists.txt
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_PackageKitQt6=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_KExiv2Qt6=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_KF6DocTools=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_Phonon4Qt6=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_Gpsd=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_KPipeWire=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_Canberra=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_KF6NetworkManagerQt=ON \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
# Fix: plasma-integration — wyłącz FontNotoSans
# ============================================================
cat > "$SCRIPTDIR/desktop/plasma-integration/WARPBUILD" << 'EOF'
pkgname=plasma-integration
pkgver=6.2.5
description="Qt platform theme integration for Plasma"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,kconfig,kcoreaddons,ki18n,kiconthemes,kio,knotifications,kstatusnotifieritem,kwidgetsaddons,kwindowsystem,kxmlgui,plasma-wayland-protocols,breeze,qqc2-desktop-style,wayland
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-wayland
source=https://download.kde.org/stable/plasma/6.2.5/plasma-integration-6.2.5.tar.xz
sha256=5795e52285deea10877fd56474473d061071cb425ba87cef3366832d50764729

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_FontNotoSans=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_FontHack=ON \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
# Fix: plasma-desktop — wyłącz DocTools + opcjonalne
# ============================================================
cat > "$SCRIPTDIR/desktop/plasma-desktop/WARPBUILD" << 'EOF'
pkgname=plasma-desktop
pkgver=6.2.5
description="KDE Plasma desktop shell"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,qt6-svg,karchive,kauth,kconfig,kconfigwidgets,kcoreaddons,kcrash,kdbusaddons,kdeclarative,kglobalaccel,kguiaddons,ki18n,kiconthemes,kio,kitemmodels,kitemviews,knewstuff,knotifications,kpackage,krunner,kservice,ksvg,kwidgetsaddons,kwindowsystem,kxmlgui,libplasma,plasma-activities,plasma5support,baloo,qqc2-desktop-style,kcmutils
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools,plasma-wayland-protocols
source=https://download.kde.org/stable/plasma/6.2.5/plasma-desktop-6.2.5.tar.xz
sha256=b73d29202031b7049485d84e615d7bd0a3ca890dcb2c22d8116eb8fe6fe9d068

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_KF6DocTools=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_PackageKitQt6=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_Synaptics=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_XorgLibinput=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_Xorg=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_SDL2=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_GLIB2=ON \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

echo -e "\n${YELLOW}=== Etap 1: Brakujące deps ===${NC}\n"

build_pkg desktop libksysguard
build_pkg desktop plasma5support
build_pkg desktop layer-shell-qt
build_pkg desktop libkscreen

echo -e "\n${YELLOW}=== Etap 2: Plasma core ===${NC}\n"

build_pkg desktop libplasma
build_pkg desktop kscreenlocker

echo -e "\n${YELLOW}=== Etap 3: KWin ===${NC}\n"

build_pkg desktop kwin

echo -e "\n${YELLOW}=== Etap 4: Plasma workspace + desktop ===${NC}\n"

build_pkg desktop plasma-workspace
build_pkg desktop plasma-integration
build_pkg desktop plasma-desktop

echo -e "\n${YELLOW}=== Podsumowanie ===${NC}\n"
echo -e "Zbudowano: $BUILT | Pominięto: $SKIPPED | Nieudane: $FAILED"
if [ -n "$FAILED_LIST" ]; then
    echo -e "${RED}Nieudane:$FAILED_LIST${NC}"
fi
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}Plasma Desktop gotowy!${NC}"
    echo ""
    echo "Odpal SDDM (graficzny login):"
    echo "  sudo rc-service sddm start"
    echo ""
    echo "Lub ręcznie:"
    echo '  echo "exec dbus-launch startplasma-x11" > ~/.xinitrc'
    echo "  startx"
else
    echo -e "${RED}Są błędy — sprawdź logi: $LOGDIR/${NC}"
fi

echo ""
echo "Zainstalowane Plasma pakiety:"
warp -A 2>/dev/null | grep -iE 'plasma|kwin|sddm|breeze|konsole|dolphin' || true
echo ""
echo "Logi: $LOGDIR/"
