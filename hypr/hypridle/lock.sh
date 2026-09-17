#!/usr/bin/env bash
# Aktif kilit ekranı sarmalayıcısı.
# Hangi tasarımın kullanılacağını ~/.config/hypr/hypridle/active-lock dosyasından
# okur (1-4). Seçici bu dosyayı LockscreenPicker.qml üzerinden yazıyor.

DIR="$HOME/.config/hypr/hypridle"
LOCKSCREENS="$HOME/.config/hypr/scripts/quickshell/lockscreens"

# Zaten kilitliyse ikinci bir örnek başlatma (lock+suspend aynı anda tetiklenirse olur)
if pgrep -f "quickshell.*lockscreens/" >/dev/null 2>&1; then
    exit 0
fi

ACTIVE="$(cat "$DIR/active-lock" 2>/dev/null | tr -d '[:space:]')"
case "$ACTIVE" in
    1) FILE="01-monolit.qml" ;;
    2) FILE="02-terminal.qml" ;;
    3) FILE="03-nokta-matris.qml" ;;
    4) FILE="04-buzlu-serit.qml" ;;
    *) FILE="01-monolit.qml" ;;
esac

exec quickshell -p "$LOCKSCREENS/$FILE"
