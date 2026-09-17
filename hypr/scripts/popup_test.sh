#!/usr/bin/env bash
# popup_test.sh — kayitli popup'lari tek tek acip incelemek icin.
#
# "Bu widget neydi, hala kullaniyor muyum?" sorusunu cevaplamak icin yazildi:
# listeden secersin, acar; bakarsin, kapatirsin, digerine gecersin.
#
# Liste WindowRegistry.js'ten CANLI okunur - kayit ekleyip cikardikca bu betigi
# guncellemek gerekmez.

set -uo pipefail

HYPR_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)"
QS_DIR="$HYPR_DIR/scripts/quickshell"
REGISTRY="$QS_DIR/WindowRegistry.js"
MANAGER="$HYPR_DIR/scripts/qs_manager.sh"

C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
C_CYAN=$'\033[36m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'

[ -r "$REGISTRY" ] || { echo "WindowRegistry.js bulunamadi: $REGISTRY" >&2; exit 1; }

# --- registry'yi oku: ad + bilesen yolu ------------------------------------
# Ayristirma python ile: sed/grep zinciri bazi satirlarda sessizce eslesmiyordu,
# python3 zaten bu yapilandirmanin zorunlu bagimliligi.
mapfile -t ENTRIES < <(
    python3 - "$REGISTRY" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
for name, comp in re.findall(r'"([a-z]+)"\s*:\s*\{.*?comp:\s*"([^"]*)"', src, re.S):
    if comp:                      # comp'u bos olan "hidden" gibi kayitlar atlanir
        print(f"{name}|{comp}")
PY
)

[ "${#ENTRIES[@]}" -gt 0 ] || { echo "Registry'de kayitli popup bulunamadi." >&2; exit 1; }

open_popup() {
    bash "$MANAGER" open "$1" >/dev/null 2>&1
}
close_popup() {
    bash "$MANAGER" close >/dev/null 2>&1
}

print_menu() {
    printf '\n%s%s Popup Test %s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
    printf '%s  secersin -> acilir -> bakarsin -> kapatirsin%s\n\n' "$C_DIM" "$C_RESET"

    local i=1
    for entry in "${ENTRIES[@]}"; do
        local name="${entry%%|*}" comp="${entry#*|}"
        local path="$QS_DIR/$comp"
        local meta
        if [ -f "$path" ]; then
            meta="$(wc -l < "$path") satir"
        else
            meta="${C_RED}DOSYA YOK${C_RESET}"
        fi
        printf '  %s%2d)%s %-16s %s%s%s  %s\n' \
            "$C_CYAN" "$i" "$C_RESET" "$name" "$C_DIM" "$comp" "$C_RESET" "$meta"
        i=$((i + 1))
    done

    printf '\n  %ss)%s  ScreenshotOverlay   %s(ayri surec olarak acilir)%s\n' \
        "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
    printf '  %sl)%s  Lock ekrani         %s%sEKRANI KILITLER - sifreni bilmen gerekir%s\n' \
        "$C_CYAN" "$C_RESET" "$C_YELLOW" "⚠ " "$C_RESET"
    printf '  %sa)%s  hepsini sirayla ac  %s(her birinde Enter bekler)%s\n' \
        "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
    printf '  %sc)%s  aciki kapat\n' "$C_CYAN" "$C_RESET"
    printf '  %sq)%s  cikis\n\n' "$C_CYAN" "$C_RESET"
}

walk_all() {
    for entry in "${ENTRIES[@]}"; do
        local name="${entry%%|*}"
        printf '\n%s>> %s%s  (Enter: sonraki, x: bitir)\n' "$C_GREEN" "$name" "$C_RESET"
        open_popup "$name"
        read -r ans
        [ "$ans" = "x" ] && { close_popup; return; }
    done
    close_popup
    printf '%sHepsi gosterildi.%s\n' "$C_GREEN" "$C_RESET"
}

while true; do
    print_menu
    printf 'Secim: '
    read -r choice || break

    case "$choice" in
        q|Q|"") close_popup; echo "Cikildi."; break ;;
        c|C)    close_popup; echo "Kapatildi." ;;
        a|A)    walk_all ;;
        s|S)
            printf '%sScreenshotOverlay aciliyor (Esc ile kapat)...%s\n' "$C_DIM" "$C_RESET"
            setsid quickshell -p "$QS_DIR/ScreenshotOverlay.qml" >/dev/null 2>&1 &
            ;;
        l|L)
            printf '%s%sEkran KILITLENECEK. Emin misin? [e/H]:%s ' "$C_BOLD" "$C_YELLOW" "$C_RESET"
            read -r yn
            case "$yn" in
                e|E|evet) setsid quickshell -p "$QS_DIR/Lock.qml" >/dev/null 2>&1 & ;;
                *) echo "Iptal." ;;
            esac
            ;;
        ''|*[!0-9]*) echo "Gecersiz secim." ;;
        *)
            if [ "$choice" -ge 1 ] && [ "$choice" -le "${#ENTRIES[@]}" ]; then
                entry="${ENTRIES[$((choice - 1))]}"
                name="${entry%%|*}"
                printf '%s%s aciliyor...%s\n' "$C_DIM" "$name" "$C_RESET"
                open_popup "$name"
            else
                echo "Gecersiz secim."
            fi
            ;;
    esac
done
