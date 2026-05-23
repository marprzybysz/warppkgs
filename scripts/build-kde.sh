#!/bin/bash
# Buduje paczki KDE Plasma w prawidłowej kolejności zależności.
# Użycie: sudo bash scripts/build-kde.sh [--from PAKIET] [--dry-run]
#
# --from PAKIET  — zacznij od podanego pakietu (pomija wcześniejsze)
# --dry-run      — wypisz kolejność bez budowania
# Paczki .wrp + .sha256 zostają w katalogu kategorii (np. warppkgs/desktop/)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPTDIR="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="/tmp/kde-build-logs"
mkdir -p "$LOGDIR"

# --- Kolejność budowania (deps → dependenci) ---
PACKAGES=(
    # Layer 0: biblioteki bazowe (mogą już być zainstalowane)
    libs/hicolor-icon-theme
    libs/hwdata
    libs/libxcvt
    libs/lmdb
    libs/qrencode
    libs/cracklib
    libs/libxslt
    libs/libical
    libs/libepoxy
    libs/taglib
    libs/libpwquality
    libs/libdisplay-info
    libs/gsettings-desktop-schemas
    media/gstreamer
    media/gst-plugins-base
    audio/libcanberra

    # Layer 1: KDE Frameworks — bez zależności od innych KF
    desktop/plasma-wayland-protocols
    desktop/breeze-icons
    desktop/karchive
    desktop/kcodecs
    desktop/kitemmodels
    desktop/kitemviews
    desktop/kirigami
    desktop/kpty
    desktop/threadweaver
    desktop/solid
    desktop/sonnet

    # Layer 2: KDE Frameworks — zależą od Layer 1
    desktop/kconfig
    desktop/kcoreaddons
    desktop/kguiaddons
    desktop/ki18n
    desktop/kdbusaddons
    desktop/kwidgetsaddons
    desktop/kcolorscheme
    desktop/kwindowsystem
    desktop/kcrash
    desktop/kglobalaccel
    desktop/knotifications

    # Layer 3: KDE Frameworks — zależą od Layer 2
    desktop/kcompletion
    desktop/kconfigwidgets
    desktop/kiconthemes
    desktop/kjobwidgets
    desktop/ksyntaxhighlighting
    desktop/ktextwidgets
    desktop/kxmlgui
    desktop/kservice
    desktop/kpackage
    desktop/kidletime
    desktop/kfilemetadata
    desktop/krunner
    desktop/networkmanager-qt
    desktop/modemmanager-qt
    desktop/bluez-qt
    desktop/prison

    # Layer 4: KDE Frameworks — zależą od Layer 3
    desktop/kio
    desktop/kdeclarative
    desktop/knewstuff
    desktop/kparts
    desktop/ktexteditor
    desktop/kwallet
    desktop/ksvg
    desktop/kirigami-addons
    desktop/qqc2-desktop-style
    desktop/baloo

    # Layer 5: KDE Plasma — komponenty bazowe
    desktop/plasma-activities
    desktop/kdecoration
    desktop/kwayland
    desktop/layer-shell-qt
    desktop/libkscreen
    desktop/plasma5support
    desktop/libplasma

    # Layer 6: KDE Plasma — usługi
    desktop/kscreenlocker
    desktop/kglobalacceld
    desktop/libksysguard
    desktop/powerdevil
    desktop/drkonqi

    # Layer 7: KDE Plasma — interfejs
    desktop/breeze
    desktop/breeze-gtk
    desktop/plasma-integration
    desktop/plasma-nm
    desktop/plasma-pa
    desktop/kinfocenter
    desktop/systemsettings
    desktop/xdg-desktop-portal-kde
    desktop/plasma-desktop

    # Layer 8: KDE Plasma — workspace + apps
    desktop/plasma-workspace
    desktop/kwin
    desktop/konsole
    desktop/dolphin
    desktop/sddm
)

# --- Parsowanie argumentów ---
START_FROM=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)  START_FROM="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        *) echo "Nieznany argument: $1"; exit 1 ;;
    esac
done

# --- Filtruj od --from ---
SKIP=0
if [[ -n "$START_FROM" ]]; then
    SKIP=1
fi

BUILT=0
FAILED=0
SKIPPED=0
FAIL_LIST=()

echo -e "${CYAN}=== Budowanie KDE Plasma — ${#PACKAGES[@]} paczek ===${NC}"
echo ""

for pkg in "${PACKAGES[@]}"; do
    name=$(basename "$pkg")

    if [[ $SKIP -eq 1 ]]; then
        if [[ "$name" == "$START_FROM" || "$pkg" == "$START_FROM" ]]; then
            SKIP=0
        else
            ((SKIPPED++))
            continue
        fi
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "  ${CYAN}[$((BUILT+1))]${NC} $pkg"
        ((BUILT++))
        continue
    fi

    WARPBUILD="$SCRIPTDIR/$pkg/WARPBUILD"
    if [[ ! -f "$WARPBUILD" ]]; then
        echo -e "  ${YELLOW}[BRAK]${NC} $pkg — brak WARPBUILD, pomijam"
        ((SKIPPED++))
        continue
    fi

    category="$SCRIPTDIR/$(dirname "$pkg")"
    echo -e "${CYAN}[$((BUILT+1))/${#PACKAGES[@]}]${NC} Buduję ${GREEN}$name${NC} → $category/"
    LOGFILE="$LOGDIR/$name.log"

    if (cd "$category" && warp -buildI "$name/") > "$LOGFILE" 2>&1; then
        rm -rf /tmp/warp-build-*
        echo -e "  ${GREEN}✓${NC} $name"
        ((BUILT++))
    else
        rm -rf /tmp/warp-build-*
        echo -e "  ${RED}✗${NC} $name — log: $LOGFILE"
        ((FAILED++))
        FAIL_LIST+=("$name")
    fi
done

echo ""
echo -e "${CYAN}=== Podsumowanie ===${NC}"
echo -e "  Zbudowane:  ${GREEN}$BUILT${NC}"
[[ $SKIPPED -gt 0 ]] && echo -e "  Pominięte:  ${YELLOW}$SKIPPED${NC}"
[[ $FAILED -gt 0 ]] && echo -e "  Błędy:      ${RED}$FAILED${NC}"
if [[ ${#FAIL_LIST[@]} -gt 0 ]]; then
    echo -e "\n  ${RED}Nieudane paczki:${NC}"
    for f in "${FAIL_LIST[@]}"; do
        echo -e "    - $f (log: $LOGDIR/$f.log)"
    done
fi
echo ""
echo "Logi: $LOGDIR/"
