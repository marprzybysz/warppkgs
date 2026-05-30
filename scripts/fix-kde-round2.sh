#!/bin/bash
# Runda 2 poprawek KDE — naprawia 5 blokerów i buduje od nowa.
# Użycie: sudo bash scripts/fix-kde-round2.sh
set -uo pipefail
export MAKEFLAGS="-j1"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
SCRIPTDIR="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="/tmp/kde-build-logs"
mkdir -p "$LOGDIR"

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1 — log: $LOGDIR/$2.log"; }

build_pkg() {
    local cat="$1" name="$2"
    if warp -A 2>/dev/null | grep -qi "^$name "; then
        echo -e "${CYAN}[skip]${NC} $cat/$name — already installed"
        return 0
    fi
    echo -e "${CYAN}[build]${NC} $cat/$name"
    if (cd "$SCRIPTDIR/$cat" && warp -buildI "$name/") > "$LOGDIR/$name.log" 2>&1; then
        rm -rf /tmp/warp-build-*
        ok "$name"
    else
        rm -rf /tmp/warp-build-*
        fail "$name" "$name"
        return 1
    fi
}

# ============================================================
echo -e "\n${CYAN}=== FIX 1: libvorbis (dep libcanberra) ===${NC}\n"
# ============================================================
# libogg → libvorbis
build_pkg libs libogg
build_pkg libs libvorbis

# ============================================================
echo -e "\n${CYAN}=== FIX 2: kguiaddons — wyłącz wayland ===${NC}\n"
# ============================================================
cat > "$SCRIPTDIR/desktop/kguiaddons/WARPBUILD" << 'EOF'
pkgname=kguiaddons
pkgver=6.7.0
description="Non-graphical Qt GUI addons"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools
source=https://download.kde.org/stable/frameworks/6.7/kguiaddons-6.7.0.tar.xz
sha256=ac437ca6baf50b0178bc8bf0b4dd1e6e70e0e4ef1ac770259738a1c42d035bcc

build() {
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DWITH_WAYLAND=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF
build_pkg desktop kguiaddons

# ============================================================
echo -e "\n${CYAN}=== FIX 3: kwindowsystem — wyłącz wayland ===${NC}\n"
# ============================================================
cat > "$SCRIPTDIR/desktop/kwindowsystem/WARPBUILD" << 'EOF'
pkgname=kwindowsystem
pkgver=6.7.0
description="Window system access abstractions"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools
source=https://download.kde.org/stable/frameworks/6.7/kwindowsystem-6.7.0.tar.xz
sha256=62c0f0b4a9507939d84aeeda55bbd4300b88c04e37953e5189b139003310a8f4

build() {
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DKWINDOWSYSTEM_WAYLAND=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF
build_pkg desktop kwindowsystem

# ============================================================
echo -e "\n${CYAN}=== FIX 4: breeze-icons ===${NC}\n"
# ============================================================
# WARPBUILD already patched on VM (sed removes src/lib to avoid OOM)
build_pkg desktop breeze-icons

# ============================================================
echo -e "\n${CYAN}=== FIX 5: kconfigwidgets — bez kdoctools ===${NC}\n"
# ============================================================
cat > "$SCRIPTDIR/desktop/kconfigwidgets/WARPBUILD" << 'EOF'
pkgname=kconfigwidgets
pkgver=6.7.0
description="Configuration dialog widgets"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,kconfig,kcolorscheme,kcodecs,kguiaddons,ki18n,kwidgetsaddons
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools
source=https://download.kde.org/stable/frameworks/6.7/kconfigwidgets-6.7.0.tar.xz
sha256=91a2cb1df3afc5c98d0da69e6f16a7c6a34e764bc88ffe397da72a11f0fc3c71

build() {
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_KF6DocTools=ON \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
echo -e "\n${CYAN}=== FIX 6: libcanberra — z libvorbis ===${NC}\n"
# ============================================================
build_pkg audio libcanberra

# ============================================================
echo -e "\n${CYAN}=== Kaskada: budujemy resztę łańcucha ===${NC}\n"
# ============================================================

# kcolorscheme zależy od kguiaddons (teraz OK)
build_pkg desktop kcolorscheme

# kcrash zależy od kcoreaddons + kwindowsystem (teraz OK)
build_pkg desktop kcrash

# kconfigwidgets zależy od kguiaddons + kcolorscheme (teraz OK)
build_pkg desktop kconfigwidgets

# kglobalaccel
build_pkg desktop kglobalaccel

# knotifications zależy od kconfig, kcoreaddons, kwindowsystem
build_pkg desktop knotifications

# ksyntaxhighlighting — already installed, skip
# ktextwidgets
build_pkg desktop ktextwidgets

# kxmlgui zależy od kconfigwidgets + kiconthemes... kiconthemes zależy od breeze-icons
build_pkg desktop kiconthemes
build_pkg desktop kjobwidgets
build_pkg desktop kxmlgui

# kidletime, kfilemetadata, krunner — opcjonalne
build_pkg desktop kidletime
build_pkg desktop kfilemetadata || true

# kio — duży, zależy od wielu powyższych
build_pkg desktop kio

# kdeclarative, knewstuff, kparts, ktexteditor, kwallet
build_pkg desktop kdeclarative || true
build_pkg desktop knewstuff || true
build_pkg desktop kparts || true
build_pkg desktop ktexteditor || true
build_pkg desktop kwallet || true
build_pkg desktop ksvg || true
build_pkg desktop kirigami-addons || true
build_pkg desktop qqc2-desktop-style || true
build_pkg desktop baloo || true

# ============================================================
echo -e "\n${CYAN}=== Plasma komponenty ===${NC}\n"
# ============================================================
build_pkg desktop plasma-activities || true
build_pkg desktop kdecoration || true
build_pkg desktop kwayland || true
build_pkg desktop layer-shell-qt || true
build_pkg desktop libkscreen || true
build_pkg desktop plasma5support || true
build_pkg desktop libplasma || true

# ============================================================
echo -e "\n${CYAN}=== Plasma desktop ===${NC}\n"
# ============================================================
build_pkg desktop kscreenlocker || true
build_pkg desktop kglobalacceld || true
build_pkg desktop breeze || true
build_pkg desktop plasma-integration || true
build_pkg desktop plasma-desktop || true
build_pkg desktop plasma-workspace || true
build_pkg desktop kwin || true

# ============================================================
echo -e "\n${CYAN}=== Aplikacje (Konsole + Dolphin) ===${NC}\n"
# ============================================================
build_pkg desktop konsole || true
build_pkg desktop dolphin || true

# ============================================================
echo -e "\n${CYAN}=== SDDM ===${NC}\n"
# ============================================================
build_pkg desktop sddm || true

# ============================================================
echo -e "\n${CYAN}=== Podsumowanie ===${NC}\n"
# ============================================================
echo "Zainstalowane KDE pakiety:"
warp -A 2>/dev/null | grep -iE 'k[a-z]|plasma|breeze|konsole|dolphin|sddm|sonnet|solid|threadweaver|kirigami|baloo|prison' || true
echo ""
echo "Logi: $LOGDIR/"
