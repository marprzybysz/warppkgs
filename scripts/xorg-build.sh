#!/bin/bash
# Buduje Xorg + xinit — brakujące zależności + serwer X + startx
# Użycie: cd ~/warppkgs && sudo bash scripts/xorg-build.sh
set -uo pipefail
export MAKEFLAGS="-j1"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
SCRIPTDIR="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="/tmp/xorg-build-logs"
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

echo -e "\n${YELLOW}=== Xorg: brakujące zależności ===${NC}\n"

build_pkg libs pixman
build_pkg x11 libxcomposite
build_pkg x11 xkeyboard-config
build_pkg x11 libfontenc
build_pkg x11 font-util
build_pkg x11 libxkbfile
build_pkg x11 libxfont2
build_pkg x11 xkbcomp
build_pkg x11 libpciaccess

echo -e "\n${YELLOW}=== Xorg: serwer ===${NC}\n"

build_pkg display xorg-server

echo -e "\n${YELLOW}=== Xorg: xinit (startx) ===${NC}\n"

build_pkg display xorg-xinit

echo -e "\n${YELLOW}=== Podsumowanie ===${NC}\n"
echo -e "Zbudowano: $BUILT | Pominięto: $SKIPPED | Nieudane: $FAILED"
echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}Xorg gotowy! Odpal:${NC}"
    echo '  echo "exec konsole" > ~/.xinitrc'
    echo '  startx'
else
    echo -e "${RED}Są błędy — sprawdź logi: $LOGDIR/${NC}"
fi
