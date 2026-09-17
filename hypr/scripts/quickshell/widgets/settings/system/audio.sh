#!/usr/bin/env bash
# Ses cihazlari: cikis/giris listesi, varsayilan secimi, seviye.
#
# pactl'in JSON kipi kullaniliyor (wpctl status'un agac ciktisini ayristirmak
# yerine): alan adlari sabit, tirnak/bosluk sorunu yok.
#
# Kullanim:
#   audio.sh status
#   audio.sh set-sink <name> | set-source <name>
#   audio.sh sink-volume <0-150> | source-volume <0-150>
#   audio.sh sink-mute | source-mute

ACTION="${1:-status}"
VALUE="$2"

# pactl'in `description` alani "Alder Lake PCH-P High Definition Audio
# Controller Speaker" gibi okunmaz seyler veriyor. Profil aciklamasi
# ("Speaker", "HDMI / DisplayPort 3 Output") baslik, kart adi alt bilgi:
# listede aygitlar birbirinden ilk kelimede ayrilsin.
list_json() { # $1 = sinks|sources, $2 = varsayilan aygitin adi
    timeout 3 pactl -f json list "$1" 2>/dev/null \
    | jq -c --arg def "$2" '
        [ .[]
          | select((.name // "") | test("\\.monitor$") | not)
          | {
              id:      .name,
              label:   ((.properties["device.profile.description"]
                         // .properties["node.nick"]
                         // .description // .name) | tostring),
              detail:  ((.properties["device.description"]
                         // .properties["alsa.card_name"] // "") | tostring),
              muted:   (.mute // false),
              volume:  (((.volume | to_entries | .[0].value.value_percent // "0%")
                         | rtrimstr("%") | tonumber?) // 0),
              default: (.name == $def)
            } ]' 2>/dev/null || echo '[]'
}

case "$ACTION" in
    status)
        DEF_SINK=$(timeout 2 pactl get-default-sink 2>/dev/null)
        DEF_SOURCE=$(timeout 2 pactl get-default-source 2>/dev/null)
        SINKS=$(list_json sinks "$DEF_SINK")
        SOURCES=$(list_json sources "$DEF_SOURCE")
        jq -n -c \
            --argjson sinks "${SINKS:-[]}" \
            --argjson sources "${SOURCES:-[]}" \
            '{ sinks: $sinks, sources: $sources }'
        ;;
    set-sink)
        [ -n "$VALUE" ] || exit 0
        # Varsayilani degistirmek yetmiyor: calan uygulamalar eski aygitta
        # kalir, kullanici "sesi degistirdim ama hala hoparlorden" der.
        timeout 3 pactl set-default-sink "$VALUE" >/dev/null 2>&1
        timeout 3 pactl -f json list sink-inputs 2>/dev/null \
            | jq -r '.[].index' 2>/dev/null \
            | while read -r idx; do
                  [ -n "$idx" ] && timeout 2 pactl move-sink-input "$idx" "$VALUE" >/dev/null 2>&1
              done
        jq -n -c '{ ok: true, msg: "" }'
        ;;
    set-source)
        [ -n "$VALUE" ] || exit 0
        timeout 3 pactl set-default-source "$VALUE" >/dev/null 2>&1
        timeout 3 pactl -f json list source-outputs 2>/dev/null \
            | jq -r '.[].index' 2>/dev/null \
            | while read -r idx; do
                  [ -n "$idx" ] && timeout 2 pactl move-source-output "$idx" "$VALUE" >/dev/null 2>&1
              done
        jq -n -c '{ ok: true, msg: "" }'
        ;;
    sink-volume)
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${VALUE:-0}%" >/dev/null 2>&1
        [ "${VALUE:-0}" -gt 0 ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1
        ;;
    source-volume)
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SOURCE@ "${VALUE:-0}%" >/dev/null 2>&1
        [ "${VALUE:-0}" -gt 0 ] && wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0 >/dev/null 2>&1
        ;;
    sink-mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1
        ;;
    source-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle >/dev/null 2>&1
        ;;
esac
