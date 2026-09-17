#!/usr/bin/env bash
# Guc & pil: batarya durumu ve sagligi, guc profili, bosta kalma davranisi.
#
# Kullanim:
#   power.sh status
#   power.sh profile <performance|balanced|power-saver>
#   power.sh set-lock <saniye|0>      0 = otomatik kilidi kapat
#   power.sh set-suspend <saniye|0>   0 = otomatik uykuyu kapat
#   power.sh hypridle-toggle

HYPRIDLE_CONF="$HOME/.config/hypr/hypridle.conf"

ACTION="${1:-status}"
VALUE="$2"

# --- hypridle listener'lari -------------------------------------------------
# Her listener bir timeout + on-timeout cifti. Hangisinin ne yaptigini
# on-timeout komutundan anliyoruz; sirasina guvenmiyoruz cunku kullanici
# dosyayi elle duzenlemis olabilir.
read_timeout() { # $1 = on-timeout icinde aranacak desen
    awk -v pat="$1" '
        /listener[[:space:]]*\{/ { inb = 1; t = ""; next }
        # "on-timeout" da "timeout" iceriyor: satir basina demirlemezsek
        # komut satiri sayiyi eziyor ve her zaman 0 okunuyor.
        inb && /^[[:space:]]*timeout[[:space:]]*=/ { gsub(/[^0-9]/, "", $0); t = $0 }
        inb && /on-timeout/ && $0 ~ pat { found = t }
        inb && /\}/ { inb = 0 }
        END { print (found == "" ? 0 : found) }
    ' "$HYPRIDLE_CONF" 2>/dev/null
}

# Bir listener'in timeout satirini yerinde degistirir. Listener bulunamazsa
# hicbir sey yazmaz — dosyaya yeni blok eklemek kullanicinin duzenini bozar.
write_timeout() { # $1 = desen, $2 = yeni saniye
    [ -f "$HYPRIDLE_CONF" ] || return 1
    awk -v pat="$1" -v newv="$2" '
        /listener[[:space:]]*\{/ { inb = 1; buf = $0; n = 0; hit = 0; next }
        inb {
            n++; lines[n] = $0
            if ($0 ~ /on-timeout/ && $0 ~ pat) hit = 1
            if ($0 ~ /\}/) {
                print buf
                for (i = 1; i <= n; i++) {
                    if (hit && lines[i] ~ /timeout[[:space:]]*=/ && lines[i] !~ /on-timeout/) {
                        sub(/=[[:space:]]*[0-9]+/, "= " newv, lines[i])
                    }
                    print lines[i]
                }
                inb = 0
            }
            next
        }
        { print }
    ' "$HYPRIDLE_CONF" > "$HYPRIDLE_CONF.tmp" 2>/dev/null \
        && mv "$HYPRIDLE_CONF.tmp" "$HYPRIDLE_CONF"
}

restart_hypridle() {
    pkill -x hypridle >/dev/null 2>&1
    sleep 0.2
    setsid hypridle >/dev/null 2>&1 &
}

case "$ACTION" in
    status)
        # --- Pil (sysfs; upower fork'u ~40ms, sysfs okumasi bedava) ---
        BAT_PRESENT=false; CAPACITY=0; BAT_STATE=""; HEALTH=0
        for bat in /sys/class/power_supply/BAT*; do
            [ -d "$bat" ] || continue
            BAT_PRESENT=true
            read -r CAPACITY < "$bat/capacity" 2>/dev/null || CAPACITY=0
            read -r BAT_STATE < "$bat/status" 2>/dev/null || BAT_STATE=""
            # Saglik = simdiki tam kapasite / tasarim kapasitesi.
            full=$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null)
            design=$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null)
            if [ -n "$full" ] && [ -n "$design" ] && [ "$design" -gt 0 ] 2>/dev/null; then
                HEALTH=$(( full * 100 / design ))
            fi
            break
        done

        # Kalan sure: upower zaten hesapliyor, tekrar turetmeye gerek yok.
        TIME_TEXT=""
        if [ "$BAT_PRESENT" = true ] && command -v upower >/dev/null 2>&1; then
            bat_path=$(timeout 2 upower -e 2>/dev/null | grep -m1 -i 'BAT')
            if [ -n "$bat_path" ]; then
                TIME_TEXT=$(timeout 2 upower -i "$bat_path" 2>/dev/null \
                    | awk -F: '/time to empty|time to full/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }')
            fi
        fi

        # --- Guc profili ---
        PPD_BUS="net.hadess.PowerProfiles"; PPD_PATH="/net/hadess/PowerProfiles"
        PROFILE=$(busctl --no-pager get-property "$PPD_BUS" "$PPD_PATH" "$PPD_BUS" ActiveProfile 2>/dev/null)
        if [ -z "$PROFILE" ]; then
            PPD_BUS="org.freedesktop.UPower.PowerProfiles"
            PPD_PATH="/org/freedesktop/UPower/PowerProfiles"
            PROFILE=$(busctl --no-pager get-property "$PPD_BUS" "$PPD_PATH" "$PPD_BUS" ActiveProfile 2>/dev/null)
        fi
        PROFILE=$(sed -n 's/^s "\(.*\)"$/\1/p' <<< "$PROFILE")
        PROFILE=${PROFILE:-unavailable}

        PROFILES='[]'
        praw=$(busctl --no-pager get-property "$PPD_BUS" "$PPD_PATH" "$PPD_BUS" Profiles 2>/dev/null)
        if [ -n "$praw" ]; then
            mapfile -t plist < <(grep -o '"Profile" s "[a-z-]*"' <<< "$praw" | sed 's/.*"\([a-z-]*\)"$/\1/')
            if [ "${#plist[@]}" -gt 0 ]; then
                PROFILES=$(printf '"%s",' "${plist[@]}"); PROFILES="[${PROFILES%,}]"
            fi
        fi

        # --- Bosta kalma ---
        HYPRIDLE=false
        pgrep -x hypridle >/dev/null 2>&1 && HYPRIDLE=true
        LOCK_T=$(read_timeout "lock-session")
        SUSPEND_T=$(read_timeout "suspend")

        jq -n -c \
            --argjson present "$BAT_PRESENT" --argjson capacity "${CAPACITY:-0}" \
            --arg state "$BAT_STATE" --argjson health "${HEALTH:-0}" --arg timeText "${TIME_TEXT}" \
            --arg profile "$PROFILE" --argjson profiles "$PROFILES" \
            --argjson hypridle "$HYPRIDLE" \
            --argjson lockT "${LOCK_T:-0}" --argjson suspendT "${SUSPEND_T:-0}" \
            '{
                battery: { present: $present, capacity: $capacity, state: $state,
                           health: $health, timeText: $timeText },
                profile: $profile, profiles: $profiles,
                idle: { running: $hypridle, lock: $lockT, suspend: $suspendT }
            }'
        ;;
    profile)
        [ -n "$VALUE" ] || exit 0
        busctl --no-pager set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles \
            net.hadess.PowerProfiles ActiveProfile s "$VALUE" 2>/dev/null \
        || busctl --no-pager set-property org.freedesktop.UPower.PowerProfiles \
            /org/freedesktop/UPower/PowerProfiles \
            org.freedesktop.UPower.PowerProfiles ActiveProfile s "$VALUE" 2>/dev/null \
        || powerprofilesctl set "$VALUE" 2>/dev/null
        jq -n -c '{ ok: true, msg: "" }'
        ;;
    set-lock|set-suspend)
        [ -n "$VALUE" ] || exit 0
        # Ilk duzenlemede bir kereye mahsus yedek: kullanicinin elle yazdigi
        # yapilandirmayi geri alabilecegi bir nokta kalsin.
        [ -f "$HYPRIDLE_CONF.bak-settings" ] || cp "$HYPRIDLE_CONF" "$HYPRIDLE_CONF.bak-settings" 2>/dev/null
        if [ "$ACTION" = "set-lock" ]; then pat="lock-session"; else pat="suspend"; fi
        if write_timeout "$pat" "$VALUE"; then
            restart_hypridle
            jq -n -c '{ ok: true, msg: "" }'
        else
            jq -n -c '{ ok: false, msg: "hypridle.conf yazilamadi" }'
        fi
        ;;
    hypridle-toggle)
        if pgrep -x hypridle >/dev/null 2>&1; then
            pkill -x hypridle >/dev/null 2>&1
        else
            setsid hypridle >/dev/null 2>&1 &
        fi
        jq -n -c '{ ok: true, msg: "" }'
        ;;
esac
