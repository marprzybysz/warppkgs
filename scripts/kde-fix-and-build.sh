#!/bin/bash
# Skoncentrowany build: polkit → kauth → kio → kparts → konsole + dolphin
# Naprawia WARPBUILDy w locie i buduje TYLKO ścieżkę krytyczną
# Użycie: sudo bash scripts/kde-fix-and-build.sh
set -uo pipefail
export MAKEFLAGS="-j1"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
SCRIPTDIR="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="/tmp/kde-build-logs"
rm -rf "$LOGDIR"
mkdir -p "$LOGDIR"
FAILED=0
BUILT=0
SKIPPED=0

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
        return 1
    fi
}

# ============================================================
echo -e "\n${YELLOW}=== Fix 1: polkit WARPBUILD ===${NC}"
echo -e "${YELLOW}  Usuwam gobject-introspection z makedeps, dodaję -Dintrospection=false${NC}\n"
# ============================================================

cat > "$SCRIPTDIR/libs/polkit/WARPBUILD" << 'POLKIT_EOF'
pkgname=polkit
pkgver=124
description="Application-level authorization toolkit"
arch=x86_64
license=LGPL-2.0
deps=glibc,glib,dbus,pam,duktape
makedeps=gcc,meson,ninja,pkg-config,python3
source=https://github.com/polkit-org/polkit/archive/refs/tags/124.tar.gz
sha256=72457d96a0538fd03a3ca96a6bf9b7faf82184d4d67c793eb759168e4fd49e20

build() {
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    # Patch: polkit 124 bug — systemd_dep undefined when using libelogind
    sed -i "s|systemd_sysusers_dir = systemd_dep.*|systemd_sysusers_dir = '/usr/lib/sysusers.d'|" meson.build
    meson setup build \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --buildtype=release \
        -Dsession_tracking=libelogind \
        -Dintrospection=false \
        -Dman=false \
        -Dtests=false
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
POLKIT_EOF

# ============================================================
echo -e "\n${YELLOW}=== Fix 2: konsole WARPBUILD ===${NC}"
echo -e "${YELLOW}  Patch: usuwam Multimedia z find_package Qt6${NC}\n"
# ============================================================

cat > "$SCRIPTDIR/desktop/konsole/WARPBUILD" << 'KONSOLE_EOF'
pkgname=konsole
pkgver=24.08.3
description="KDE terminal emulator"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,kcoreaddons,kconfig,kwidgetsaddons,kiconthemes,kservice,kio,ksyntaxhighlighting,knotifications,kparts,ktextwidgets,knotifyconfig,kpty
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools,ki18n
source=https://download.kde.org/stable/release-service/24.08.3/src/konsole-24.08.3.tar.xz
sha256=687498a7eb8050549fd9a5bc94212f1cc7f33b81fee406b64a1ef6b7c65058da

build() {
    # 1. Usun Multimedia z CMake
    sed -i 's/ Multimedia//' CMakeLists.txt
    find . -name CMakeLists.txt -exec sed -i '/Qt::Multimedia/d' {} +

    # 2. Usun #include QMediaPlayer/QAudioOutput
    sed -i '/#include.*QMediaPlayer/d' src/Vt102Emulation.h
    sed -i '/#include.*QAudioOutput/d' src/Vt102Emulation.cpp

    # 3. Usun slot declaration i member variable z headera
    sed -i '/deletePlayer.*QMediaPlayer/d' src/Vt102Emulation.h
    sed -i '/QMediaPlayer.*\*player/d' src/Vt102Emulation.h

    # 4. Usun player(nullptr) z listy inicjalizacyjnej konstruktora
    sed -i '/player(nullptr)/d' src/Vt102Emulation.cpp

    # 5. Usun blok if (inlineMedia) { ... } z cpp
    sed -i '/if (inlineMedia) {/,/^        }$/d' src/Vt102Emulation.cpp

    # 5. Usun cala funkcje deletePlayer
    sed -i '/^void Vt102Emulation::deletePlayer/,/^}/d' src/Vt102Emulation.cpp

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
KONSOLE_EOF

# ============================================================
echo -e "\n${YELLOW}=== Fix 3: ktexteditor WARPBUILD ===${NC}"
echo -e "${YELLOW}  Patch: usuwam TextToSpeech z find_package Qt6${NC}\n"
# ============================================================

cat > "$SCRIPTDIR/desktop/ktexteditor/WARPBUILD" << 'KTE_EOF'
pkgname=ktexteditor
pkgver=6.7.0
description="Advanced embeddable text editor"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,qt6-declarative,karchive,kconfig,kguiaddons,ki18n,kio,kparts,ksyntaxhighlighting,ktextwidgets
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools
source=https://download.kde.org/stable/frameworks/6.7/ktexteditor-6.7.0.tar.xz
sha256=ed76f72324225a926e00c2c970d48d7f11a576e942e48d092e9837bda79d6991

build() {
    sed -i 's/TextToSpeech//' CMakeLists.txt
    sed -i '/Qt6::TextToSpeech/d' src/CMakeLists.txt
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
KTE_EOF

# ============================================================
echo -e "\n${YELLOW}=== Fix 4: dolphin WARPBUILD ===${NC}"
echo -e "${YELLOW}  Dodaję flagi na wyłączenie opcjonalnych deps${NC}\n"
# ============================================================

cat > "$SCRIPTDIR/desktop/dolphin/WARPBUILD" << 'DOLPHIN_EOF'
pkgname=dolphin
pkgver=24.08.3
description="KDE file manager"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,kcoreaddons,kconfig,kwidgetsaddons,kiconthemes,kservice,kio,solid,knotifications,kcmutils,kparts
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools,ki18n
source=https://download.kde.org/stable/release-service/24.08.3/src/dolphin-24.08.3.tar.xz
sha256=95bbce876019fb0c7cc6ca4a5fd8ec1f625f70fd511fe883df12446a5285806d

build() {
    sed -i 's/find_package(Phonon4Qt6 CONFIG REQUIRED)/find_package(Phonon4Qt6 CONFIG QUIET)/' CMakeLists.txt
    sed -i '/Phonon::/d' src/dolphinmainwindow.cpp src/CMakeLists.txt 2>/dev/null
    sed -i '/kdoctools_install/d' CMakeLists.txt
    sed -i '/add_subdirectory(doc)/d' CMakeLists.txt
    sed -i 's/FATAL_ERROR_WHEN_REQUIRED/DESCRIPTION/' CMakeLists.txt
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_KF6Baloo=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_KF6BalooWidgets=ON \
          -DCMAKE_DISABLE_FIND_PACKAGE_PackageKitQt6=ON \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
DOLPHIN_EOF

# ============================================================
echo -e "\n${YELLOW}=== Fix 5: breeze WARPBUILD ===${NC}"
echo -e "${YELLOW}  Dodaję -DBUILD_QT5=OFF${NC}\n"
# ============================================================

cat > "$SCRIPTDIR/desktop/breeze/WARPBUILD" << 'BREEZE_EOF'
pkgname=breeze
pkgver=6.2.5
description="Breeze visual style for Plasma"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,kconfig,kcoreaddons,kguiaddons,ki18n,kiconthemes,kwindowsystem,kconfigwidgets,kirigami,kcolorscheme,kdecoration
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools
source=https://download.kde.org/stable/plasma/6.2.5/breeze-6.2.5.tar.xz
sha256=1d3bd4481bb7cd274a13ac5d5852be51ff2975e620872dfc22fbd531bad04e25

build() {
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DBUILD_QT5=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
BREEZE_EOF

# ============================================================
echo -e "\n${YELLOW}=== Fix 6: plasma-activities WARPBUILD ===${NC}"
echo -e "${YELLOW}  Dodaję -DCMAKE_DISABLE_FIND_PACKAGE_Boost=ON${NC}\n"
# ============================================================

cat > "$SCRIPTDIR/desktop/plasma-activities/WARPBUILD" << 'PA_EOF'
pkgname=plasma-activities
pkgver=6.2.5
description="Runtime and library to organize work in separate activities"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,kconfig,kcoreaddons
makedeps=gcc,cmake,ninja,extra-cmake-modules
source=https://download.kde.org/stable/plasma/6.2.5/plasma-activities-6.2.5.tar.xz
sha256=77ea739c7ce5170d92d78d6f3765e19a32f0e24b741f525555d59dc7de15e6c7

build() {
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_Boost=ON \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
PA_EOF

# ============================================================
echo -e "\n${YELLOW}=== Fix 7: sddm WARPBUILD ===${NC}"
echo -e "${YELLOW}  Dodaję -DBUILD_WITH_QT6=ON (wymusza Qt6)${NC}\n"
# ============================================================

cat > "$SCRIPTDIR/desktop/sddm/WARPBUILD" << 'SDDM_EOF'
pkgname=sddm
pkgver=0.21.0
description="Simple Desktop Display Manager (login manager, OpenRC compatible)"
arch=x86_64
license=GPL-2.0
deps=glibc,qt6-base,qt6-declarative,elogind,pam,libxcb,libx11
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools
source=https://github.com/sddm/sddm/archive/refs/tags/v0.21.0.tar.gz
sha256=f895de2683627e969e4849dbfbbb2b500787481ca5ba0de6d6dfdae5f1549abf

build() {
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DBUILD_WITH_QT6=ON \
          -DUSE_ELOGIND=ON \
          -DENABLE_WAYLAND=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
SDDM_EOF

# ============================================================
# ============================================================
echo -e "\n${YELLOW}=== Fix 8: duktape — brakujący duk_config.h ===${NC}"
echo -e "${YELLOW}  Dodaję duk_config.h do package()${NC}\n"
# ============================================================

cat > "$SCRIPTDIR/libs/duktape/WARPBUILD" << 'DUKTAPE_EOF'
pkgname=duktape
pkgver=2.7.0
description="Embeddable JavaScript engine w C — mały, używany przez różne narzędzia"
arch=x86_64
license=MIT
deps=glibc
makedeps=gcc,make,python3
source=https://duktape.org/duktape-2.7.0.tar.xz
sha256=90f8d2fa8b5567c6899830ddef2c03f3c27960b11aca222fa17aa7ac613c2890

build() {
    make $MAKEFLAGS -f Makefile.sharedlibrary
}

package() {
    install -Dm755 libduktape.so.207.20700 "$DESTDIR/usr/lib/libduktape.so.207.20700"
    ln -sf libduktape.so.207.20700 "$DESTDIR/usr/lib/libduktape.so.207"
    ln -sf libduktape.so.207 "$DESTDIR/usr/lib/libduktape.so"
    install -Dm644 src/duktape.h "$DESTDIR/usr/include/duktape.h"
    install -Dm644 src/duk_config.h "$DESTDIR/usr/include/duk_config.h"
}
DUKTAPE_EOF

# Doinstaluj brakujący header bez przebudowy
if [ ! -f /usr/include/duk_config.h ]; then
    echo -e "${CYAN}[hotfix]${NC} Instaluję brakujący duk_config.h..."
    rm -rf /tmp/warp-build-*
    find "$SCRIPTDIR/libs/duktape" -name "*.wrp" -delete 2>/dev/null
    if (cd "$SCRIPTDIR/libs" && warp -buildI duktape/) > "$LOGDIR/duktape-rebuild.log" 2>&1; then
        ok "duktape (rebuild z duk_config.h)"
        BUILT=$((BUILT+1))
    else
        fail "duktape rebuild" "duktape-rebuild"
        echo -e "${RED}STOP: duktape rebuild failed${NC}"; exit 1
    fi
    rm -rf /tmp/warp-build-*
fi

echo -e "\n${CYAN}=== Build: ścieżka krytyczna do Konsole + Dolphin ===${NC}\n"
# ============================================================

# Etap 1: polkit → kauth
build_pkg libs polkit || { echo -e "${RED}STOP: polkit failed, nie można kontynuować${NC}"; exit 1; }
build_pkg desktop kauth || { echo -e "${RED}STOP: kauth failed${NC}"; exit 1; }

# Fix kio: disable opcjonalnych deps
cat > "$SCRIPTDIR/desktop/kio/WARPBUILD" << 'KIO_EOF'
pkgname=kio
pkgver=6.7.0
description="Network transparent access to files"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,kservice,solid,kauth,kdbusaddons,kjobwidgets,kbookmarks
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools,qt5compat
source=https://download.kde.org/stable/frameworks/6.7/kio-6.7.0.tar.xz
sha256=df235019a07acd579920f6c655050e02dacf847c706f4b8279e755be46f9d990

build() {
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DCMAKE_DISABLE_FIND_PACKAGE_KF6DocTools=ON \
          -DWITH_WAYLAND=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
KIO_EOF

# Etap 2: qt5compat (dep kio) + kio
build_pkg libs qt5compat || { echo -e "${RED}STOP: qt5compat failed${NC}"; exit 1; }
build_pkg desktop kio || { echo -e "${RED}STOP: kio failed${NC}"; exit 1; }

# Etap 3: kparts (wymaga kio)
build_pkg desktop kparts || { echo -e "${RED}STOP: kparts failed${NC}"; exit 1; }

# Etap 4: ktexteditor (opcjonalny dla konsole, ale zbudujmy)
build_pkg desktop ktexteditor || echo -e "${YELLOW}WARN: ktexteditor failed, konsole może działać bez niego${NC}"

# Etap 5: brakujące frameworki i zależności
build_pkg libs icu || { echo -e "${RED}STOP: icu failed${NC}"; exit 1; }
build_pkg desktop kcmutils || echo -e "${YELLOW}WARN: kcmutils failed${NC}"
build_pkg desktop knotifyconfig || echo -e "${YELLOW}WARN: knotifyconfig failed${NC}"
build_pkg desktop kpty || echo -e "${YELLOW}WARN: kpty failed${NC}"

# Etap 6: aplikacje docelowe
echo -e "\n${CYAN}=== Build: Konsole + Dolphin ===${NC}\n"
build_pkg desktop konsole || echo -e "${RED}FAIL: konsole${NC}"
build_pkg desktop dolphin || echo -e "${RED}FAIL: dolphin${NC}"

# Etap 6: bonus — jeśli jest czas
echo -e "\n${CYAN}=== Build: bonus (optional) ===${NC}\n"
build_pkg desktop plasma-activities || true
build_pkg desktop breeze || true
build_pkg desktop qqc2-desktop-style || true
build_pkg desktop sddm || true

# ============================================================
echo -e "\n${CYAN}=== Podsumowanie ===${NC}\n"
# ============================================================
echo "Zbudowano: $BUILT | Pominięto: $SKIPPED | Nieudane: $FAILED"
echo ""
echo "Zainstalowane KDE pakiety:"
warp -A 2>/dev/null | grep -iE 'konsole|dolphin|kauth|polkit|kio|kparts|ktexteditor|breeze|sddm|plasma-act' || true
echo ""
echo "Logi: $LOGDIR/"
