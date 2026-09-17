#!/usr/bin/env bash
# Sidebar Center'daki her kontrolün gerçek sistem karşılığı.
# Kullanım: sidebar_center_action.sh <eylem> [değer]
#
# Cache dizinleri QML'den env ile gelir:
#   QS_CACHE_DND        -> DND bayrağı
#   QS_CACHE_SIDEBARCENTER -> idle inhibitor için hypridle hatırlatıcısı

DND_DIR="${QS_CACHE_DND:-$HOME/.cache/quickshell/dnd}"
MC_DIR="${QS_CACHE_SIDEBARCENTER:-$HOME/.cache/quickshell/sidebar-center}"
mkdir -p "$DND_DIR" "$MC_DIR" 2>/dev/null

# systemd-inhibit süreci bu imzayla başlatılır; state script'i de aynı deseni arar.
INHIBIT_MATCH="systemd-inhibit --what=idle:sleep --who=SidebarCenter"
HYPRIDLE_FLAG="$MC_DIR/hypridle_was_running"

ACTION="$1"
VALUE="$2"
VALUE2="$3"

# Wi-Fi eylemlerinde SSID ve parola base64 gelir: icinde bosluk, tirnak ya da
# '$' olan SSID'ler tek tirnakli QML komut satirindan saglam gecemiyordu.
b64d() { printf '%s' "$1" | base64 -d 2>/dev/null; }

# Wi-Fi eylemleri sonucu JSON basar; QML bunu okuyup hata metnini gosteriyor.
wifi_result() { # $1 = exit kodu, $2 = nmcli ciktisi
    if [ "$1" -eq 0 ]; then
        jq -n -c '{ ok: true, msg: "" }'
    else
        jq -n -c --arg m "$(printf '%s' "$2" | tail -n1)" '{ ok: false, msg: $m }'
    fi
}

wifi_saved() { # $1 = ssid -> 0 = kayitli profil var
    LC_ALL=C timeout 2 nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | sed 's/\\:/@@C@@/g' \
        | awk -F: -v s="$1" '$2 == "802-11-wireless" { gsub(/@@C@@/, ":", $1); if ($1 == s) found = 1 }
                             END { exit found ? 0 : 1 }'
}

case "$ACTION" in
    volume)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${VALUE:-0}%"
        [ "${VALUE:-0}" -gt 0 ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
        ;;
    volume-mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    mic)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SOURCE@ "${VALUE:-0}%"
        [ "${VALUE:-0}" -gt 0 ] && wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
        ;;
    mic-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;
    brightness)
        # 1'in altına inmek ekranı tamamen karartıyor, o yüzden taban %1.
        v=${VALUE:-1}
        [ "$v" -lt 1 ] && v=1
        brightnessctl -q set "${v}%"
        ;;
    wifi-toggle)
        if [ "$(nmcli radio wifi 2>/dev/null)" = "enabled" ]; then
            nmcli radio wifi off
        else
            nmcli radio wifi on
        fi
        ;;
    wifi-connect)
        # $2 = SSID (base64), $3 = parola (base64, opsiyonel)
        ssid=$(b64d "$VALUE")
        pass=$(b64d "$VALUE2")
        [ -n "$ssid" ] || exit 0
        if [ -n "$pass" ]; then
            # Parola verildiyse kayitli profil varsa da tazele: eski/yanlis psk
            # ile "up" demek sessizce basarisiz oluyordu.
            if wifi_saved "$ssid"; then
                timeout 10 nmcli connection modify id "$ssid" \
                    wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pass" >/dev/null 2>&1
                out=$(timeout 45 nmcli connection up id "$ssid" 2>&1); rc=$?
            else
                out=$(timeout 45 nmcli device wifi connect "$ssid" password "$pass" 2>&1); rc=$?
            fi
        elif wifi_saved "$ssid"; then
            out=$(timeout 45 nmcli connection up id "$ssid" 2>&1); rc=$?
        else
            out=$(timeout 45 nmcli device wifi connect "$ssid" 2>&1); rc=$?
        fi
        wifi_result "$rc" "$out"
        ;;
    wifi-disconnect)
        ssid=$(b64d "$VALUE")
        [ -n "$ssid" ] || exit 0
        out=$(timeout 15 nmcli connection down id "$ssid" 2>&1); rc=$?
        wifi_result "$rc" "$out"
        ;;
    wifi-forget)
        # Ayni SSID icin birden fazla profil olabilir; hepsini sil.
        ssid=$(b64d "$VALUE")
        [ -n "$ssid" ] || exit 0
        out=$(timeout 15 nmcli connection delete id "$ssid" 2>&1); rc=$?
        wifi_result "$rc" "$out"
        ;;
    bt-toggle)
        # Adaptor gucu tek yerden yonetiliyor: settings sayfasiyla ayni script.
        # Kapatirken arka planda dolasan tarayiciyi da o olduruyor, burada
        # ayrica ele almak gerekmiyor.
        bash "$(dirname "${BASH_SOURCE[0]}")/../settings/system/bluetooth.sh" \
            power-toggle >/dev/null 2>&1
        ;;
    easyeffects-toggle)
        if [ "$(systemctl --user is-active easyeffects 2>/dev/null)" = "active" ]; then
            systemctl --user stop easyeffects
        else
            systemctl --user start easyeffects
        fi
        ;;
    profile)
        # Doğrudan bir profile geç (performance / balanced / power-saver).
        # powerprofilesctl bir Python script'i — sırf yorumlayıcı açılışı ~150ms,
        # ki bu tıklama ile profilin gerçekten değişmesi arasındaki gecikmenin
        # neredeyse tamamıydı. Aynı işi yapan D-Bus set-property ~25ms.
        [ -n "$VALUE" ] || exit 0
        busctl --no-pager set-property \
            net.hadess.PowerProfiles /net/hadess/PowerProfiles \
            net.hadess.PowerProfiles ActiveProfile s "$VALUE" 2>/dev/null \
        || busctl --no-pager set-property \
            org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles \
            org.freedesktop.UPower.PowerProfiles ActiveProfile s "$VALUE" 2>/dev/null \
        || powerprofilesctl set "$VALUE" 2>/dev/null
        ;;
    inhibit-toggle)
        if pgrep -f "$INHIBIT_MATCH" >/dev/null 2>&1; then
            pkill -f "$INHIBIT_MATCH"
            # hypridle'ı biz durdurduysak geri başlat
            if [ -f "$HYPRIDLE_FLAG" ]; then
                rm -f "$HYPRIDLE_FLAG"
                pgrep -x hypridle >/dev/null 2>&1 || setsid hypridle >/dev/null 2>&1 &
            fi
        else
            # hypridle logind inhibitor'ını dinlemiyor; uyanık kalmanın tek
            # garantili yolu onu da duraklatmak, sonra geri açmak.
            if pgrep -x hypridle >/dev/null 2>&1; then
                touch "$HYPRIDLE_FLAG"
                pkill -x hypridle
            fi
            setsid systemd-inhibit --what=idle:sleep --who=SidebarCenter \
                --why="Uyanık kal" sleep infinity >/dev/null 2>&1 &
        fi
        ;;
    night-toggle)
        if pgrep -x hyprsunset >/dev/null 2>&1; then
            pkill -x hyprsunset
        else
            setsid hyprsunset -t "${VALUE:-4000}" >/dev/null 2>&1 &
        fi
        ;;
    dnd-toggle)
        if [ "$(cat "$DND_DIR/state" 2>/dev/null)" = "1" ]; then
            echo 0 > "$DND_DIR/state"
        else
            echo 1 > "$DND_DIR/state"
        fi
        ;;
    battery-saver-toggle)
        # Delegates to Dynamic Island's own apply/restore state machine
        # (power.sh profile + hyprctl animations) instead of reimplementing
        # capture/restore here — that state already lives there, and a second
        # independent copy could drift from it (e.g. restore to the wrong
        # "previous" profile if both fired around the same unplug event).
        qs -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" \
            ipc call dynamicIsland systemSaverToggle >/dev/null 2>&1 &
        ;;
    lock)
        setsid bash "$HOME/.config/hypr/scripts/lock.sh" >/dev/null 2>&1 &
        ;;
    suspend)
        # Uyanışta ekran kilitli gelsin diye önce kilit, sonra askıya alma.
        setsid bash "$HOME/.config/hypr/scripts/lock.sh" >/dev/null 2>&1 &
        sleep 0.4
        systemctl suspend
        ;;
    poweroff)
        systemctl poweroff
        ;;
    reboot)
        systemctl reboot
        ;;
    logout)
        setsid bash "$HOME/.config/hypr/scripts/exit.sh" >/dev/null 2>&1 &
        ;;
esac
