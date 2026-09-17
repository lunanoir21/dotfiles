#!/usr/bin/env bash
# Tek noktadan tema uygulama.
#
# Sistemde renk okuyan uc ayri yer var ve tema degistiginde ucu de degismeli:
#
#   1. quickshell/qs_colors.json  -> MatugenColors.qml'i kullanan her widget
#      (top bar, sidebar, ayarlar, uygulama baslatici, pano, kilit ekrani...)
#   2. hypr/colors.conf           -> Hyprland pencere kenarliklari
#   3. dynamic-island/settings.json -> adanin kendi paleti (kendi sema adlari
#      var; tema dosyasindaki "island" alani hangi paletine karsilik geldigini
#      soyluyor). Ada bu dosyayi izliyor, yazar yazmaz kendini boyuyor.
#
# Tema tanimlari ~/.config/hypr/themes/*.json — yeni tema eklemek icin oraya
# bir dosya birakmak yeterli, bu script otomatik gorur.
#
# Kullanim:
#   theme.sh list            -> temalar (JSON dizi)
#   theme.sh current         -> etkin temanin adi
#   theme.sh apply <isim>    -> uygula

THEME_DIR="$HOME/.config/hypr/themes"
QS_COLORS="$HOME/.config/hypr/scripts/quickshell/qs_colors.json"
HYPR_COLORS="$HOME/.config/hypr/colors.conf"
SETTINGS_JSON="$HOME/.config/hypr/settings.json"
ISLAND_SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/dynamic-island/settings.json"

ACTION="${1:-current}"
NAME="$2"

case "$ACTION" in
    list)
        # Ayarlar sayfasi bu listeyi cizer: ad, etiket, ipucu ve uc renklik
        # onizleme lekesi.
        jq -s -c '[ .[] | { name, label, hint, dark, swatch } ]' "$THEME_DIR"/*.json 2>/dev/null \
            || echo '[]'
        ;;
    current)
        jq -r '.theme // "black"' "$SETTINGS_JSON" 2>/dev/null || echo "black"
        ;;
    apply)
        FILE="$THEME_DIR/$NAME.json"
        if [ ! -f "$FILE" ]; then
            jq -n -c --arg n "$NAME" '{ ok: false, msg: ("Tema bulunamadı: " + $n) }'
            exit 1
        fi

        # --- 1) Quickshell renkleri -------------------------------------
        # Gecici dosyaya yazip taşıyoruz: MatugenColors saniyede bir okuyor,
        # yarim yazilmis bir JSON'a denk gelirse renkler bir kare bozuluyor.
        if jq -e '.colors' "$FILE" >/dev/null 2>&1; then
            jq '.colors' "$FILE" > "$QS_COLORS.tmp" && mv "$QS_COLORS.tmp" "$QS_COLORS"
        fi

        # --- 2) Hyprland kenarliklari -----------------------------------
        ACTIVE=$(jq -r '.border.active // "ffffffee"' "$FILE")
        INACTIVE=$(jq -r '.border.inactive // "888888aa"' "$FILE")
        printf '$active_border = rgba(%s)\n$inactive_border = rgba(%s)\n' \
            "$ACTIVE" "$INACTIVE" > "$HYPR_COLORS"

        # --- 3) Dynamic Island paleti -----------------------------------
        ISLAND=$(jq -r '.island // empty' "$FILE")
        if [ -n "$ISLAND" ]; then
            mkdir -p "$(dirname "$ISLAND_SETTINGS")"
            [ -f "$ISLAND_SETTINGS" ] || echo '{}' > "$ISLAND_SETTINGS"
            # Adanin diger ayarlarina dokunmadan yalnizca themeName'i degistir.
            jq --arg t "$ISLAND" '.themeName = $t' "$ISLAND_SETTINGS" > "$ISLAND_SETTINGS.tmp" \
                && mv "$ISLAND_SETTINGS.tmp" "$ISLAND_SETTINGS"
        fi

        # --- 4) Secimi hatirla ------------------------------------------
        [ -f "$SETTINGS_JSON" ] || echo '{}' > "$SETTINGS_JSON"
        jq --arg t "$NAME" '.theme = $t' "$SETTINGS_JSON" > "$SETTINGS_JSON.tmp" \
            && mv "$SETTINGS_JSON.tmp" "$SETTINGS_JSON"

        # --- 5) Hyprland'e kenarlik renklerini okut ---------------------
        hyprctl reload >/dev/null 2>&1

        jq -n -c '{ ok: true, msg: "" }'
        ;;
esac
