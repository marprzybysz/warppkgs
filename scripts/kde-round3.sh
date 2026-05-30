#!/bin/bash
# Runda 3: pełny build KDE-Minimal od zależności do konsole+dolphin
# Użycie: sudo bash scripts/kde-round3.sh
# Uruchamiaj w tmux/nohup!
set -uo pipefail
export MAKEFLAGS="-j1"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
SCRIPTDIR="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="/tmp/kde-build-logs"
mkdir -p "$LOGDIR"
FAILED=0
BUILT=0
SKIPPED=0
FAILED_LIST=""

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1 — log: $LOGDIR/$2.log"; }

build_pkg() {
    local cat="$1" name="$2" optional="${3:-}"
    if warp -A 2>/dev/null | grep -qi "^$name "; then
        echo -e "${CYAN}[skip]${NC} $cat/$name — already installed"
        SKIPPED=$((SKIPPED+1))
        return 0
    fi
    echo -e "${CYAN}[build]${NC} $cat/$name"
    rm -rf /tmp/warp-build-*
    # Usun cached .wrp zeby wymusic przebudowe z poprawionymi WARPBUILDami
    find "$SCRIPTDIR/$cat/$name" -name "*.wrp" -delete 2>/dev/null
    if (cd "$SCRIPTDIR/$cat" && warp -buildI "$name/") > "$LOGDIR/$name.log" 2>&1; then
        rm -rf /tmp/warp-build-*
        ok "$name"
        BUILT=$((BUILT+1))
    else
        rm -rf /tmp/warp-build-*
        fail "$name" "$name"
        FAILED=$((FAILED+1))
        FAILED_LIST="$FAILED_LIST $name"
        if [ "$optional" != "optional" ]; then
            return 1
        fi
        return 0
    fi
}

echo -e "\n${CYAN}=== Etap 1: Zależności bazowe ===${NC}\n"

build_pkg libs libgpg-error
build_pkg libs libgcrypt
build_pkg base audit
build_pkg base pam
build_pkg libs duktape
build_pkg libs libevdev
build_pkg libs mtdev
build_pkg libs libinput
build_pkg libs elogind
build_pkg libs polkit
build_pkg desktop kauth

echo -e "\n${CYAN}=== Etap 2: KDE Frameworks — brakujące ===${NC}\n"

build_pkg desktop kxmlgui
build_pkg desktop kidletime
build_pkg desktop kwallet optional
build_pkg desktop kbookmarks
build_pkg desktop kio
build_pkg desktop attica
build_pkg desktop syndication
build_pkg desktop kstatusnotifieritem
build_pkg desktop kparts optional
build_pkg desktop knewstuff optional
build_pkg desktop ktexteditor optional
build_pkg desktop qqc2-desktop-style optional
build_pkg desktop baloo optional

echo -e "\n${CYAN}=== Etap 3: Plasma komponenty ===${NC}\n"

build_pkg desktop plasma-activities optional
build_pkg desktop kwayland optional
build_pkg desktop layer-shell-qt optional
build_pkg desktop libkscreen optional
build_pkg desktop plasma5support optional
build_pkg desktop libplasma optional

echo -e "\n${CYAN}=== Etap 4: Plasma Desktop ===${NC}\n"

build_pkg desktop kscreenlocker optional
build_pkg desktop kglobalacceld optional
build_pkg desktop breeze optional
build_pkg desktop plasma-integration optional
build_pkg desktop kwin optional
build_pkg desktop plasma-workspace optional
build_pkg desktop plasma-desktop optional

echo -e "\n${CYAN}=== Etap 5: Aplikacje ===${NC}\n"

build_pkg desktop konsole optional
build_pkg desktop dolphin optional

echo -e "\n${CYAN}=== Etap 6: SDDM ===${NC}\n"

build_pkg desktop sddm optional

echo -e "\n${CYAN}=== Podsumowanie ===${NC}\n"
echo "Zbudowano: $BUILT | Pominięto: $SKIPPED | Nieudane: $FAILED"
if [ -n "$FAILED_LIST" ]; then
    echo -e "\n${RED}Nieudane pakiety:${NC}$FAILED_LIST"
    echo ""
    for name in $FAILED_LIST; do
        echo "--- $name (ostatnie 5 linii logu) ---"
        tail -5 "$LOGDIR/$name.log" 2>/dev/null
        echo ""
    done
fi
echo ""
echo "Zainstalowane KDE pakiety:"
warp -A 2>/dev/null | grep -iE 'k[a-z]|plasma|breeze|konsole|dolphin|sddm|sonnet|solid|threadweaver|kirigami|baloo|attica|syndication|qqc2' || true
echo ""
echo "Logi: $LOGDIR/"
