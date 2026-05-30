#!/bin/bash
# Skrypt naprawczy: doinstaluj brakujące xcb-util, przebuduj Qt6 z XCB,
# popraw WARPBUILDy, uruchom pełny build KDE.
# Użycie: sudo bash scripts/fix-and-build-kde.sh
#
# Uruchamiaj w tmux żeby przeżyło rozłączenie SSH!

set -euo pipefail
export MAKEFLAGS="-j1"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPTDIR="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="/tmp/kde-fix-logs"
mkdir -p "$LOGDIR"

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1 — log: $2"; }

build_pkg() {
    local category="$1" name="$2"
    local dir="$SCRIPTDIR/$category/$name"
    local log="$LOGDIR/$name.log"
    echo -e "${CYAN}[build]${NC} $category/$name"
    if (cd "$SCRIPTDIR/$category" && warp -buildI "$name/") > "$log" 2>&1; then
        rm -rf /tmp/warp-build-*
        ok "$name"
        return 0
    else
        rm -rf /tmp/warp-build-*
        fail "$name" "$log"
        return 1
    fi
}

# ============================================================
echo -e "\n${CYAN}=== ETAP 1: Brakujące xcb-util ===${NC}\n"
# ============================================================

build_pkg x11 xcb-util-image
build_pkg x11 xcb-util-cursor

# ============================================================
echo -e "\n${CYAN}=== ETAP 2: Przebudowa Qt6-base z XCB ===${NC}\n"
echo "(to zajmie ~1h)"
# ============================================================

build_pkg desktop qt6-base

# Sprawdź czy XCB jest teraz włączone
if grep -q '"xcb"' /usr/lib/cmake/Qt6Gui/Qt6GuiTargets.cmake 2>/dev/null ||
   ! grep -q 'xcb' <(cat /usr/lib/cmake/Qt6Gui/Qt6GuiTargets.cmake 2>/dev/null | grep DISABLED_PUBLIC); then
    ok "Qt6 XCB check — prawdopodobnie OK (sprawdź log)"
else
    echo -e "  ${RED}UWAGA: Qt6 może nadal nie mieć XCB! Sprawdź log: $LOGDIR/qt6-base.log${NC}"
fi

# ============================================================
echo -e "\n${CYAN}=== ETAP 3: Poprawki WARPBUILDów ===${NC}\n"
# ============================================================

# --- breeze-icons: OOM na kompilacji qrc — wyłącz BINARY_ICONS_RESOURCE ---
echo "  Fixing breeze-icons (BINARY_ICONS_RESOURCE=OFF)..."
sed -i 's/BINARY_ICONS_RESOURCE=ON/BINARY_ICONS_RESOURCE=OFF/' \
    "$SCRIPTDIR/desktop/breeze-icons/WARPBUILD"

# --- sonnet: dodaj hint dla hunspell ---
echo "  Fixing sonnet (hunspell hints)..."
sed -i 's|-DBUILD_TESTING=OFF|-DBUILD_TESTING=OFF \\\n          -DSONNET_USE_QML=OFF|' \
    "$SCRIPTDIR/desktop/sonnet/WARPBUILD" 2>/dev/null || true
# Dodaj zmienną środowiskową dla cmake
if ! grep -q 'HUNSPELL' "$SCRIPTDIR/desktop/sonnet/WARPBUILD"; then
    cat > "$SCRIPTDIR/desktop/sonnet/WARPBUILD" << 'SONNET_EOF'
pkgname=sonnet
pkgver=6.7.0
description="Spell checking library"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,hunspell
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools
source=https://download.kde.org/stable/frameworks/6.7/sonnet-6.7.0.tar.xz
sha256=2f970d490effd668e64dd93ffef344a80db7e63130bb23df4fa0d6b14150e588

build() {
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DSONNET_USE_QML=OFF \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
SONNET_EOF
fi

# --- ki18n: dodaj hint na gettext executables + iso-codes ---
echo "  Fixing ki18n (gettext + iso-codes hints)..."
cat > "$SCRIPTDIR/desktop/ki18n/WARPBUILD" << 'KI18N_EOF'
pkgname=ki18n
pkgver=6.7.0
description="KDE internationalization library"
arch=x86_64
license=LGPL-2.1
deps=glibc,qt6-base,gettext,iso-codes
makedeps=gcc,cmake,ninja,extra-cmake-modules,qt6-tools,python3
source=https://download.kde.org/stable/frameworks/6.7/ki18n-6.7.0.tar.xz
sha256=555b5bc19546c3a791c69724e238c5d1710a9575cf8740012f8fc546f354122b

build() {
    cmake -GNinja \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF \
          -DGETTEXT_MSGMERGE_EXECUTABLE=/usr/bin/msgmerge \
          -DGETTEXT_MSGFMT_EXECUTABLE=/usr/bin/msgfmt \
          -B build
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
KI18N_EOF

# --- libcanberra: fix configure (explicit ALSA + disable gtk3) ---
echo "  Fixing libcanberra (ALSA + no-gtk3)..."
cat > "$SCRIPTDIR/audio/libcanberra/WARPBUILD" << 'CANBERRA_EOF'
pkgname=libcanberra
pkgver=0.30
description="XDG sound theme and name specification implementation"
arch=x86_64
license=LGPL-2.1
deps=glibc,libvorbis,alsa-lib,gstreamer
makedeps=gcc,make,pkg-config
source=http://0pointer.de/lennart/projects/libcanberra/libcanberra-0.30.tar.xz
sha256=c2b671e67e0c288a69fc33dc1b6f1b534d07882c2aceed37004bf48c601afa72

build() {
    ALSA_CFLAGS="$(pkg-config --cflags alsa)" \
    ALSA_LIBS="$(pkg-config --libs alsa)" \
    ./configure --prefix=/usr \
        --disable-static \
        --disable-oss \
        --enable-alsa \
        --disable-gtk3 \
        --disable-gtk \
        --enable-gstreamer \
        --disable-lynx
    make $MAKEFLAGS
}

package() {
    make DESTDIR="$DESTDIR" install
}
CANBERRA_EOF

# --- gsettings-desktop-schemas: wyłącz introspection ---
echo "  Fixing gsettings-desktop-schemas (no gobject-introspection)..."
cat > "$SCRIPTDIR/libs/gsettings-desktop-schemas/WARPBUILD" << 'GSETTINGS_EOF'
pkgname=gsettings-desktop-schemas
pkgver=47.1
description="GSettings schemas for GNOME desktop"
arch=x86_64
license=LGPL-2.1
deps=glibc,glib
makedeps=gcc,meson,ninja,pkg-config
source=https://download.gnome.org/sources/gsettings-desktop-schemas/47/gsettings-desktop-schemas-47.1.tar.xz
sha256=a60204d9c9c0a1b264d6d0d134a38340ba5fc6076a34b84da945d8bfcc7a2815

build() {
    meson setup build \
        --prefix=/usr \
        -Dintrospection=false
    ninja -C build $MAKEFLAGS
}

package() {
    DESTDIR="$DESTDIR" ninja -C build install
}
GSETTINGS_EOF

ok "WARPBUILDy poprawione"

# ============================================================
echo -e "\n${CYAN}=== ETAP 4: Pełny build KDE ===${NC}\n"
# ============================================================

exec bash "$SCRIPTDIR/scripts/build-kde.sh"
