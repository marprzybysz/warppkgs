#!/bin/bash
# Plasma build v4 — fix 6 failed packages from v3
# Fixes: libplasma (wayland.xml path), kwin (Qt6Sensors), cascade deps
# Użycie: cd ~/warppkgs && sudo bash scripts/plasma-build-v4.sh
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
# Fix: libplasma — wayland.xml path + PKG_CONFIG_PATH
# ============================================================
cat > "$SCRIPTDIR/desktop/libplasma/WARPBUILD" << 'EOF'
pkgname=libplasma
pkgver=6.2.5
description="Plasma library and runtime components"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,qt6-declarative,qt6-svg,karchive,kconfig,kconfigwidgets,kcoreaddons,kglobalaccel,kguiaddons,ki18n,kiconthemes,kio,kirigami,knotifications,kpackage,ksvg,kwindowsystem,kcolorscheme,plasma-activities,wayland
makedeps=gcc,cmake,ninja,extra-cmake-modules,plasma-wayland-protocols,qt6-wayland
source=https://download.kde.org/stable/plasma/6.2.5/libplasma-6.2.5.tar.xz
sha256=af770f5fef978512c70491889516fb769d340f00a02270987d2d1d17753658ec

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DWayland_DATADIR=/usr/share/wayland \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
# Fix: kscreenlocker — wayland.xml path + PKG_CONFIG_PATH
# ============================================================
cat > "$SCRIPTDIR/desktop/kscreenlocker/WARPBUILD" << 'EOF'
pkgname=kscreenlocker
pkgver=6.2.5
description="Library and components for secure lock screen"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,kconfig,kcoreaddons,kcrash,kglobalaccel,ki18n,kidletime,knotifications,ksvg,kwindowsystem,layer-shell-qt,pam,wayland
makedeps=gcc,cmake,ninja,extra-cmake-modules,plasma-wayland-protocols,qt6-wayland
source=https://download.kde.org/stable/plasma/6.2.5/kscreenlocker-6.2.5.tar.xz
sha256=3a3ed2d040394dc2a80cf25cdd2a6c4022146aca54e72c44af16e8982e8b8e4e

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DWayland_DATADIR=/usr/share/wayland \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
# Fix: kwayland — PKG_CONFIG_PATH + Wayland_DATADIR
# ============================================================
cat > "$SCRIPTDIR/desktop/kwayland/WARPBUILD" << 'EOF'
pkgname=kwayland
pkgver=6.2.5
description="Qt-style client and server library wrapper for Wayland"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,wayland,wayland-protocols
makedeps=gcc,cmake,ninja,extra-cmake-modules,plasma-wayland-protocols
source=https://download.kde.org/stable/plasma/6.2.5/kwayland-6.2.5.tar.xz
sha256=2a17a8ce5643fd51c3cf787542032c1050da3a1fb00dcc9a32dea288bd38d7d2

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DWayland_DATADIR=/usr/share/wayland \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
# Fix: kwin — sed out Sensors + disable Breeze
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
    sed -i '/    Sensors/d' CMakeLists.txt
    sed -i '/Qt::Sensors/d' src/CMakeLists.txt

    mkdir -p src/stub
    printf '#pragma once\nclass QOrientationReading {\npublic:\n    enum Orientation { Undefined=0, TopUp=1, TopDown=2, LeftUp=3, RightUp=4, FaceUp=5, FaceDown=6 };\n    void setOrientation(Orientation) {}\n    Orientation orientation() const { return Undefined; }\n};\n' > src/stub/QOrientationReading
    sed -i 's|#include <QOrientationReading>|#include "stub/QOrientationReading"|' src/outputconfigurationstore.cpp
    # Replace orientationsensor.h — remove unique_ptr members, no-op class
    printf '#pragma once\n#include <QObject>\nclass QOrientationReading;\nnamespace KWin {\nclass OrientationSensor : public QObject {\n    Q_OBJECT\npublic:\n    explicit OrientationSensor();\n    ~OrientationSensor();\n    void setEnabled(bool enable);\n    QOrientationReading *reading() const;\nQ_SIGNALS:\n    void orientationChanged();\nprivate:\n    void update();\n};\n}\n' > src/utils/orientationsensor.h
    # Replace orientationsensor.cpp — no-op, no Qt Sensors dependency
    printf '#include "orientationsensor.h"\n#include "stub/QOrientationReading"\nnamespace KWin {\nstatic QOrientationReading s_reading;\nOrientationSensor::OrientationSensor() {}\nOrientationSensor::~OrientationSensor() = default;\nvoid OrientationSensor::setEnabled(bool) {}\nQOrientationReading *OrientationSensor::reading() const { return const_cast<QOrientationReading*>(&s_reading); }\nvoid OrientationSensor::update() {}\n}\n#include "moc_orientationsensor.cpp"\n' > src/utils/orientationsensor.cpp

    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_Breeze=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_XKB=OFF \
          -DWayland_DATADIR=/usr/share/wayland \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
# Fix: plasma-workspace — Positioning + opcjonalne + wayland path
# ============================================================
cat > "$SCRIPTDIR/desktop/plasma-workspace/WARPBUILD" << 'EOF'
pkgname=plasma-workspace
pkgver=6.2.5
description="KDE Plasma workspace components"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,qt6-svg,qt6-wayland,kwin,kconfig,kcoreaddons,kwindowsystem,kiconthemes,kservice,kio,knotifications,kpackage,polkit,elogind,dbus,wayland,fontconfig,freetype,libplasma,plasma-activities,plasma5support,krunner,baloo,ki18n,karchive,kcrash,kdbusaddons,kglobalaccel,kguiaddons,kidletime,kitemmodels,knewstuff,ksvg,kwidgetsaddons,kcmutils,kcolorscheme,kirigami,kscreenlocker,kauth,qqc2-desktop-style,kded,kunitconversion,plasma-activities-stats,libcanberra,prison
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools,wayland-protocols,plasma-wayland-protocols
source=https://download.kde.org/stable/plasma/6.2.5/plasma-workspace-6.2.5.tar.xz
sha256=b82511e46f62e1b8f60b969c828c8d8d32fc7928401a70cc28c29f85f46c412f

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    # Qt6: strip Positioning (qt6-positioning niezbudowane) + QCoro6 (nieużywane po wyłączeniu freespacenotifier)
    sed -i 's/ Positioning//' CMakeLists.txt
    sed -i '/find_package(QCoro6/d' CMakeLists.txt
    # KF6 COMPONENTS: usuń TYLKO słowo TextEditor (interactiveconsole wyłączone); Prison zostaje (budujemy prison)
    sed -i 's/ TextEditor//' CMakeLists.txt
    # Phonon4Qt6 (REQUIRED, nieużywany dla nas) — usuń find + set_package_properties + subdir
    sed -i '/pkg_check_modules(QALCULATE/d' CMakeLists.txt
    sed -i '/find_package(Phonon4Qt6/d' CMakeLists.txt
    sed -i '/set_package_properties(Phonon4Qt6/,+2d' CMakeLists.txt
    sed -i '/add_subdirectory(phonon)/d' CMakeLists.txt
    rm -rf phonon/
    # Wyłącz subdiry których deps nie budujemy:
    #   freespacenotifier -> QCoro,  interactiveconsole -> KF6::TextEditor,  libcolorcorrect/kded -> Qt6::Positioning
    sed -i '/add_subdirectory(freespacenotifier)/d' CMakeLists.txt
    sed -i '/add_subdirectory(interactiveconsole)/d' CMakeLists.txt
    sed -i '/add_subdirectory(kded)/d' libcolorcorrect/CMakeLists.txt
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DGLIBC_LOCALE_GEN=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_PackageKitQt6=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_KExiv2Qt6=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_KF6DocTools=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_Gpsd=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_KPipeWire=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_KF6NetworkManagerQt=ON \
          -DWayland_DATADIR=/usr/share/wayland \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
# Fix: plasma-integration — FontNotoSans + wayland path
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
          -DBUILD_QT5=OFF \
          -DWayland_DATADIR=/usr/share/wayland \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

# ============================================================
# Fix: plasma-desktop — DocTools + opcjonalne + wayland path
# ============================================================
cat > "$SCRIPTDIR/desktop/plasma-desktop/WARPBUILD" << 'EOF'
pkgname=plasma-desktop
pkgver=6.2.5
description="KDE Plasma desktop shell"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,qt6-svg,karchive,kauth,kconfig,kconfigwidgets,kcoreaddons,kcrash,kdbusaddons,kdeclarative,kglobalaccel,kguiaddons,ki18n,kiconthemes,kio,kitemmodels,kitemviews,knewstuff,knotifications,kpackage,krunner,kservice,ksvg,kwidgetsaddons,kwindowsystem,kxmlgui,libplasma,plasma-activities,plasma-activities-stats,plasma5support,baloo,qqc2-desktop-style,kcmutils
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools,plasma-wayland-protocols
source=https://download.kde.org/stable/plasma/6.2.5/plasma-desktop-6.2.5.tar.xz
sha256=b73d29202031b7049485d84e615d7bd0a3ca890dcb2c22d8116eb8fe6fe9d068

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    sed -i '/    DocTools/d' CMakeLists.txt
    # doc/ buduje handbooki przez kdoctools_create_handbook (KF6DocTools wyłączone) — wytnij cały subdir
    sed -i '/add_subdirectory(doc)/d' CMakeLists.txt
    # top-level kdoctools_install (manuale) też wymaga KF6DocTools — wytnij
    sed -i '/kdoctools_install/d' CMakeLists.txt
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DBUILD_KCM_MOUSE_X11=OFF \
          -DBUILD_KCM_TOUCHPAD_X11=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_PackageKitQt6=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_Synaptics=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_XorgLibinput=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_Xorg=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_SDL2=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_GLIB2=ON \
          -DWayland_DATADIR=/usr/share/wayland \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

echo -e "\n${YELLOW}=== Etap 1: libplasma ===${NC}\n"
build_pkg desktop libplasma

echo -e "\n${YELLOW}=== Etap 2: kscreenlocker ===${NC}\n"
build_pkg desktop kscreenlocker

echo -e "\n${YELLOW}=== Etap 3: kwindowsystem rebuild + kwayland + kwin ===${NC}\n"

# Rebuild kwindowsystem z Wayland ON
cat > "$SCRIPTDIR/desktop/kwindowsystem/WARPBUILD" << 'EOF'
pkgname=kwindowsystem
pkgver=6.7.0
description="Window system access abstractions"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,qt6-wayland,wayland,wayland-protocols,plasma-wayland-protocols
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools
source=https://download.kde.org/stable/frameworks/6.7/kwindowsystem-6.7.0.tar.xz
sha256=62c0f0b4a9507939d84aeeda55bbd4300b88c04e37953e5189b139003310a8f4

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DKWINDOWSYSTEM_WAYLAND=ON \
          -DWayland_DATADIR=/usr/share/wayland \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF

rebuild_pkg() {
    local cat="$1" name="$2"
    echo -e "${YELLOW}[rebuild]${NC} $name"
    warp -D "$name" 2>/dev/null || true
    rm -rf /tmp/warp-build-*
    find "$SCRIPTDIR/$cat/$name" -name "*.wrp" -delete 2>/dev/null
    if (cd "$SCRIPTDIR/$cat" && warp -buildI "$name/") > "$LOGDIR/$name.log" 2>&1; then
        rm -rf /tmp/warp-build-*
        ok "$name (rebuild)"
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

# kwindowsystem jest już zainstalowany z Wayland ON — NIE rebuilduj (warp -D kaskadowo
# usuwa kwin, który od niego zależy, przez co kwin budował się co przebieg).
build_pkg desktop kwindowsystem
build_pkg desktop kwayland
build_pkg desktop kwin

echo -e "\n${YELLOW}=== Etap 4: deps ===${NC}\n"
build_pkg x11 libxft
build_pkg x11 libxtst

# Build kded (KDE daemon framework — provides KDED_DBUS_INTERFACE)
if ! warp -A 2>/dev/null | grep -qi "^kded "; then
    mkdir -p "$SCRIPTDIR/desktop/kded"
    cat > "$SCRIPTDIR/desktop/kded/WARPBUILD" << 'EOF'
pkgname=kded
pkgver=6.7.0
description="KDE daemon framework"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,kcoreaddons,kdbusaddons,kservice,kcrash
makedeps=gcc,cmake,ninja,extra-cmake-modules
source=https://download.kde.org/stable/frameworks/6.7/kded-6.7.0.tar.xz
sha256=22aa1b6543b40e094346138516131c0f7eb78a70e87296938457fd1386680a2f

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF
fi
build_pkg desktop kded

# Build kunitconversion (KF6::UnitConversion — weather dataengines)
if ! warp -A 2>/dev/null | grep -qi "^kunitconversion "; then
    mkdir -p "$SCRIPTDIR/desktop/kunitconversion"
    cat > "$SCRIPTDIR/desktop/kunitconversion/WARPBUILD" << 'EOF'
pkgname=kunitconversion
pkgver=6.7.0
description="KDE unit conversion library"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,ki18n
makedeps=gcc,cmake,ninja,extra-cmake-modules
source=https://download.kde.org/stable/frameworks/6.7/kunitconversion-6.7.0.tar.xz
sha256=b303601c623cd66edb66a66fd72e957415b8dd33e70305be8136fa6b43b1a40a

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF
fi
build_pkg desktop kunitconversion

# Build plasma-activities-stats (Plasma::ActivitiesStats — kicker launcher, runners)
if ! warp -A 2>/dev/null | grep -qi "^plasma-activities-stats "; then
    mkdir -p "$SCRIPTDIR/desktop/plasma-activities-stats"
    cat > "$SCRIPTDIR/desktop/plasma-activities-stats/WARPBUILD" << 'EOF'
pkgname=plasma-activities-stats
pkgver=6.2.5
description="Access usage statistics collected by the activity manager"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,kconfig,plasma-activities
makedeps=gcc,cmake,ninja,extra-cmake-modules
source=https://download.kde.org/stable/plasma/6.2.5/plasma-activities-stats-6.2.5.tar.xz
sha256=cddba25924651e0f5de74a6faabc8990301857bb31f4ee4ac1f69d7a0c48532c

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF
fi
build_pkg desktop plasma-activities-stats

# prison (KF6::Prison — kody QR w klipper/schowku); WITH_MULTIMEDIA=OFF bo skaner z kamery
# wymaga Qt6Multimedia (niezbudowane); generator QR działa bez niego
if ! warp -A 2>/dev/null | grep -qi "^prison "; then
    mkdir -p "$SCRIPTDIR/desktop/prison"
    cat > "$SCRIPTDIR/desktop/prison/WARPBUILD" << 'EOF'
pkgname=prison
pkgver=6.7.0
description="Barcode abstraction layer"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,qt6-declarative,qt6-svg,qrencode
makedeps=gcc,cmake,ninja,extra-cmake-modules
source=https://download.kde.org/stable/frameworks/6.7/prison-6.7.0.tar.xz
sha256=0a053a80beae232cef5da3f6525b14ee649b275cea64de0c0ffad41c3f2ec260

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DWITH_MULTIMEDIA=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
EOF
fi
build_pkg desktop prison

echo -e "\n${YELLOW}=== Etap 5: plasma-workspace + integration + desktop ===${NC}\n"
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
