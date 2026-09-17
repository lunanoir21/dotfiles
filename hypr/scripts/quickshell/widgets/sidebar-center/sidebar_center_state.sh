#!/usr/bin/env bash
# Tek seferde Sidebar Center'ın ihtiyaç duyduğu tüm sistem durumunu JSON olarak basar.
#
# HIZ NOTU: bu script poll döngüsünde çalışıyor, o yüzden "kullanıcı arayüzü
# CLI'ı" olan araçlardan (bluetoothctl, powerprofilesctl) kaçınıyoruz:
#   * bluetoothctl interaktif bir REPL — argümanla çağrılsa bile prompt'u
#     kapatmak için beklediğinden `timeout 0.5` süresinin tamamını yakıyordu.
#   * powerprofilesctl bir Python script'i; sırf yorumlayıcı açılışı ~150ms.
# İkisinin de yerine doğrudan D-Bus (busctl, ~3ms) ve sysfs okuması var.
#
# DND bayrağının dizini QML'den env ile geliyor (Caching.qml -> getCacheDir("dnd")).

DND_DIR="${QS_CACHE_DND:-$HOME/.cache/quickshell/dnd}"

# --- Uptime -----------------------------------------------------------------
read -r up_secs _ < /proc/uptime
up_secs=${up_secs%.*}
up_d=$((up_secs / 86400))
up_h=$(((up_secs % 86400) / 3600))
up_m=$(((up_secs % 3600) / 60))
if [ "$up_d" -gt 0 ]; then
    UPTIME="${up_d}d ${up_h}h"
elif [ "$up_h" -gt 0 ]; then
    UPTIME="${up_h}h ${up_m}m"
else
    UPTIME="${up_m}m"
fi

# --- Pil --------------------------------------------------------------------
BAT_PRESENT=false
BAT_CAPACITY=0
BAT_CHARGING=false
for bat in /sys/class/power_supply/BAT*; do
    [ -d "$bat" ] || continue
    BAT_PRESENT=true
    read -r BAT_CAPACITY < "$bat/capacity" 2>/dev/null || BAT_CAPACITY=0
    read -r bat_status < "$bat/status" 2>/dev/null || bat_status=""
    [ "$bat_status" = "Charging" ] && BAT_CHARGING=true
    break
done

# --- Ses / mikrofon ---------------------------------------------------------
read_wp() { # $1 = @DEFAULT_AUDIO_SINK@ | @DEFAULT_AUDIO_SOURCE@
    local raw vol muted
    raw=$(LC_ALL=C timeout 1 wpctl get-volume "$1" 2>/dev/null)
    if [ -z "$raw" ]; then echo "0 false"; return; fi
    vol=$(awk '{print int($2 * 100 + 0.5)}' <<< "$raw")
    if [[ "$raw" == *MUTED* ]]; then muted="true"; else muted="false"; fi
    echo "${vol:-0} $muted"
}
read -r VOLUME VOL_MUTED <<< "$(read_wp @DEFAULT_AUDIO_SINK@)"
read -r MIC MIC_MUTED <<< "$(read_wp @DEFAULT_AUDIO_SOURCE@)"

# --- Parlaklık --------------------------------------------------------------
# brightnessctl yerine sysfs: fork yok, ~0ms.
BRIGHT_PRESENT=false
BRIGHTNESS=0
for bl in /sys/class/backlight/*; do
    [ -d "$bl" ] || continue
    read -r bl_cur < "$bl/brightness" 2>/dev/null || continue
    read -r bl_max < "$bl/max_brightness" 2>/dev/null || continue
    [ "${bl_max:-0}" -gt 0 ] || continue
    BRIGHT_PRESENT=true
    BRIGHTNESS=$(((bl_cur * 100 + bl_max / 2) / bl_max))
    break
done

# --- rfkill (Wi-Fi / Bluetooth radyo durumu, saf dosya okuması) -------------
rfkill_on() { # $1 = wlan | bluetooth  -> 0 = açık
    local d t soft hard
    for d in /sys/class/rfkill/rfkill*; do
        [ -d "$d" ] || continue
        read -r t < "$d/type" 2>/dev/null || continue
        [ "$t" = "$1" ] || continue
        read -r soft < "$d/soft" 2>/dev/null || soft=1
        read -r hard < "$d/hard" 2>/dev/null || hard=1
        [ "$soft" = "0" ] && [ "$hard" = "0" ] && return 0
        return 1
    done
    return 1
}

# --- Wi-Fi ------------------------------------------------------------------
WIFI_ON=false
WIFI_SSID=""
WIFI_SIGNAL=0
if rfkill_on wlan; then
    WIFI_ON=true
    WIFI_SSID=$(LC_ALL=C timeout 1 nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
        | awk -F: '/802-11-wireless/ {print $1; exit}')
    WIFI_SIGNAL=$(LC_ALL=C awk 'NR==3 {gsub(/\./,"",$3); print int($3 * 100 / 70)}' /proc/net/wireless 2>/dev/null)
    WIFI_SIGNAL=${WIFI_SIGNAL:-0}
fi

# --- Bluetooth --------------------------------------------------------------
# bluez çalışmıyorsa D-Bus'a hiç dokunma: aksi halde busctl her seferinde
# servisi activate etmeye çalışıp hem gecikir hem de boşuna daemon uyandırır.
BT_ON=false
BT_DEVICE=""
if [ "$(systemctl is-active bluetooth 2>/dev/null)" = "active" ] && rfkill_on bluetooth; then
    bt_powered=$(busctl --no-pager get-property org.bluez /org/bluez/hci0 \
        org.bluez.Adapter1 Powered 2>/dev/null)
    if [ "$bt_powered" = "b true" ]; then
        BT_ON=true
        # Bağlı ilk cihazın adı: tek ObjectManager çağrısı, cihaz başına
        # ayrı sorgu yok.
        BT_DEVICE=$(busctl --no-pager call org.bluez / \
            org.freedesktop.DBus.ObjectManager GetManagedObjects 2>/dev/null \
            | grep -o '"Alias" s "[^"]*"[^|]*"Connected" b true' \
            | head -n1 | sed -n 's/^"Alias" s "\([^"]*\)".*/\1/p')
    fi
fi

# --- EasyEffects ------------------------------------------------------------
EASYEFFECTS=false
if pgrep -x easyeffects >/dev/null 2>&1 \
   || [ "$(systemctl --user is-active easyeffects 2>/dev/null)" = "active" ]; then
    EASYEFFECTS=true
fi

# --- Güç profili (D-Bus; powerprofilesctl ~150ms Python açılışı) ------------
PPD_BUS="net.hadess.PowerProfiles"
PPD_PATH="/net/hadess/PowerProfiles"
PROFILE=$(busctl --no-pager get-property "$PPD_BUS" "$PPD_PATH" "$PPD_BUS" ActiveProfile 2>/dev/null)
if [ -z "$PROFILE" ]; then
    # power-profiles-daemon >= 0.30 isim alanını taşıdı.
    PPD_BUS="org.freedesktop.UPower.PowerProfiles"
    PPD_PATH="/org/freedesktop/UPower/PowerProfiles"
    PROFILE=$(busctl --no-pager get-property "$PPD_BUS" "$PPD_PATH" "$PPD_BUS" ActiveProfile 2>/dev/null)
fi
PROFILE=$(sed -n 's/^s "\(.*\)"$/\1/p' <<< "$PROFILE")
PROFILE=${PROFILE:-unavailable}

# Profiles özelliği aa{sv}; her girdide bir "Profile" s "<ad>" var.
PROFILES='[]'
profiles_raw=$(busctl --no-pager get-property "$PPD_BUS" "$PPD_PATH" "$PPD_BUS" Profiles 2>/dev/null)
if [ -n "$profiles_raw" ]; then
    mapfile -t plist < <(grep -o '"Profile" s "[a-z-]*"' <<< "$profiles_raw" \
        | sed 's/.*"\([a-z-]*\)"$/\1/')
    if [ "${#plist[@]}" -gt 0 ]; then
        PROFILES=$(printf '"%s",' "${plist[@]}")
        PROFILES="[${PROFILES%,}]"
    fi
fi

# --- Idle inhibitor (uyanık kal) --------------------------------------------
INHIBIT=false
pgrep -f "systemd-inhibit --what=idle:sleep --who=SidebarCenter" >/dev/null 2>&1 && INHIBIT=true

# --- Gece ışığı -------------------------------------------------------------
NIGHT=false
pgrep -x hyprsunset >/dev/null 2>&1 && NIGHT=true

# --- Rahatsız etmeyin -------------------------------------------------------
DND=false
[ "$(cat "$DND_DIR/state" 2>/dev/null)" = "1" ] && DND=true

# --- Pil tasarrufu paketi (Dynamic Island'ın uyguladığı profil+animasyon
# ikilisi) — "aktif" saymak için ikisi de gerçekleşmiş olmalı, sadece profil
# elden power-saver'a çekilmişse (animasyonlar açık kalmışsa) bu toggle'ı
# yanlışlıkla "açık" göstermesin.
ANIM_ENABLED=$(hyprctl -j getoption animations:enabled 2>/dev/null | jq -r '.int // 1')
BATTERY_SAVER=false
[ "$PROFILE" = "power-saver" ] && [ "$ANIM_ENABLED" = "0" ] && BATTERY_SAVER=true

jq -n -c \
    --arg uptime "$UPTIME" \
    --argjson batPresent "$BAT_PRESENT" --argjson batCapacity "${BAT_CAPACITY:-0}" --argjson batCharging "$BAT_CHARGING" \
    --argjson volume "${VOLUME:-0}" --argjson volMuted "$VOL_MUTED" \
    --argjson mic "${MIC:-0}" --argjson micMuted "$MIC_MUTED" \
    --argjson brightness "${BRIGHTNESS:-0}" --argjson brightPresent "$BRIGHT_PRESENT" \
    --argjson wifiOn "$WIFI_ON" --arg wifiSsid "$WIFI_SSID" --argjson wifiSignal "$WIFI_SIGNAL" \
    --argjson btOn "$BT_ON" --arg btDevice "$BT_DEVICE" \
    --argjson easyeffects "$EASYEFFECTS" \
    --arg profile "$PROFILE" --argjson profiles "$PROFILES" \
    --argjson inhibit "$INHIBIT" --argjson night "$NIGHT" --argjson dnd "$DND" \
    --argjson batterySaver "$BATTERY_SAVER" \
    '{
        uptime: $uptime,
        batPresent: $batPresent, batCapacity: $batCapacity, batCharging: $batCharging,
        volume: $volume, volMuted: $volMuted,
        mic: $mic, micMuted: $micMuted,
        brightness: $brightness, brightPresent: $brightPresent,
        wifiOn: $wifiOn, wifiSsid: $wifiSsid, wifiSignal: $wifiSignal,
        btOn: $btOn, btDevice: $btDevice,
        easyeffects: $easyeffects,
        profile: $profile, profiles: $profiles,
        inhibit: $inhibit, night: $night, dnd: $dnd,
        batterySaver: $batterySaver
    }'
