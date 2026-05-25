#!/bin/bash
# Buduje Qt6 + ECM — prerequisite przed build-kde.sh
# Użycie: sudo bash scripts/build-qt6.sh [--from PAKIET] [--dry-run]
#
# Najpierw robi warp --sync żeby zarejestrować systemowe pakiety,
# potem buduje Qt6 stack i ECM w prawidłowej kolejności.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPTDIR="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="/tmp/qt6-build-logs"
mkdir -p "$LOGDIR"

PACKAGES=(
    # Sync — zarejestruj systemowe pakiety w warp db
    __SYNC__

    # Qt6 stack
    desktop/qt6-base
    desktop/qt6-shadertools
    desktop/qt6-declarative
    desktop/qt6-svg
    desktop/qt6-tools
    desktop/qt6-wayland

    # ECM — wymagane przez wszystkie KDE Frameworks
    toolchain/extra-cmake-modules
)

START_FROM=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)  START_FROM="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        *) echo "Nieznany argument: $1"; exit 1 ;;
    esac
done

SKIP=0
if [[ -n "$START_FROM" ]]; then
    SKIP=1
fi

BUILT=0
FAILED=0
SKIPPED=0
FAIL_LIST=()

echo -e "${CYAN}=== Budowanie Qt6 + ECM — ${#PACKAGES[@]} kroków ===${NC}"
echo ""

for pkg in "${PACKAGES[@]}"; do
    name=$(basename "$pkg")

    if [[ $SKIP -eq 1 ]]; then
        if [[ "$name" == "$START_FROM" || "$pkg" == "$START_FROM" ]]; then
            SKIP=0
        else
            SKIPPED=$((SKIPPED+1))
            continue
        fi
    fi

    # Specjalny krok: warp --sync
    if [[ "$pkg" == "__SYNC__" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo -e "  ${CYAN}[sync]${NC} warp --sync"
            continue
        fi
        echo -e "${CYAN}[sync]${NC} Synchronizuję bazę pakietów..."
        if warp --sync > "$LOGDIR/sync.log" 2>&1; then
            echo -e "  ${GREEN}✓${NC} sync"
        else
            echo -e "  ${RED}✗${NC} sync — log: $LOGDIR/sync.log"
        fi
        continue
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "  ${CYAN}[$((BUILT+1))]${NC} $pkg"
        BUILT=$((BUILT+1))
        continue
    fi

    WARPBUILD="$SCRIPTDIR/$pkg/WARPBUILD"
    if [[ ! -f "$WARPBUILD" ]]; then
        echo -e "  ${YELLOW}[BRAK]${NC} $pkg — brak WARPBUILD, pomijam"
        SKIPPED=$((SKIPPED+1))
        continue
    fi

    category="$SCRIPTDIR/$(dirname "$pkg")"
    echo -e "${CYAN}[$((BUILT+1))/${#PACKAGES[@]}]${NC} Buduję ${GREEN}$name${NC} → $category/"
    LOGFILE="$LOGDIR/$name.log"

    if (cd "$category" && warp -buildI "$name/") > "$LOGFILE" 2>&1; then
        rm -rf /tmp/warp-build-*
        echo -e "  ${GREEN}✓${NC} $name"
        BUILT=$((BUILT+1))
    else
        rm -rf /tmp/warp-build-*
        echo -e "  ${RED}✗${NC} $name — log: $LOGFILE"
        FAILED=$((FAILED+1))
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

if [[ $FAILED -eq 0 && $DRY_RUN -eq 0 ]]; then
    echo -e "${GREEN}Qt6 + ECM gotowe! Teraz odpal:${NC}"
    echo "  sudo bash scripts/build-kde.sh"
fi
