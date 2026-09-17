#!/usr/bin/env bash
# Ag: Wi-Fi agları, kablolu baglanti, VPN profilleri ve aktif baglantinin
# adres bilgileri.
#
# SSID ve parola base64 gelir: icinde bosluk, tirnak ya da '$' olan SSID'ler
# tek tirnakli komut satirindan saglam gecemiyor.
#
# Kullanim:
#   network.sh status [rescan]
#   network.sh wifi-toggle
#   network.sh connect <ssid_b64> [parola_b64]
#   network.sh disconnect <ssid_b64> | forget <ssid_b64>
#   network.sh vpn-up <ad_b64> | vpn-down <ad_b64>
#   network.sh device-up <ad_b64> | device-down <ad_b64>

ACTION="${1:-status}"
VALUE="$2"
VALUE2="$3"

b64d() { printf '%s' "$1" | base64 -d 2>/dev/null; }

result() { # $1 = exit kodu, $2 = nmcli ciktisi
    if [ "$1" -eq 0 ]; then
        jq -n -c '{ ok: true, msg: "" }'
    else
        jq -n -c --arg m "$(printf '%s' "$2" | tail -n1)" '{ ok: false, msg: $m }'
    fi
}

wifi_saved() { # $1 = ssid
    LC_ALL=C timeout 2 nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | sed 's/\\:/@@C@@/g' \
        | awk -F: -v s="$1" '$2 == "802-11-wireless" { gsub(/@@C@@/, ":", $1); if ($1 == s) f = 1 }
                             END { exit f ? 0 : 1 }'
}

case "$ACTION" in
    status)
        RESCAN="no"; [ "$VALUE" = "rescan" ] && RESCAN="yes"

        RADIO=$(LC_ALL=C timeout 2 nmcli radio wifi 2>/dev/null)
        WIFI_ON=false
        if [ "$RADIO" = "enabled" ] || [ "$RADIO" = "etkin" ]; then
            WIFI_ON=true
        else
            for rfk in /sys/class/rfkill/*; do
                if [ -d "$rfk" ] && [ "$(< "$rfk/type" 2>/dev/null)" = "wlan" ]; then
                    [ "$(< "$rfk/state" 2>/dev/null)" = "1" ] && WIFI_ON=true && break
                fi
            done
        fi

        # Aygitlar: kablolu/kablosuz ayrimi ve her birinin durumu.
        DEVICES=$(LC_ALL=C timeout 3 nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null \
            | sed 's/\\:/@@C@@/g')

        # Aktif baglantinin adresleri. Birden fazla aktif aygit olabilir
        # (wifi + vpn); ana yolu tasiyani IP4.GATEWAY'i olan aygit sayiyoruz.
        PRIMARY=$(LC_ALL=C timeout 2 nmcli -t -f DEVICE,STATE device status 2>/dev/null \
            | awk -F: '$2 == "connected" { print $1; exit }')
        IP=""; GW=""; DNS=""
        if [ -n "$PRIMARY" ]; then
            SHOW=$(LC_ALL=C timeout 3 nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show "$PRIMARY" 2>/dev/null)
            IP=$(awk -F: '/^IP4.ADDRESS/ { print $2; exit }' <<< "$SHOW")
            GW=$(awk -F: '/^IP4.GATEWAY/ { print $2; exit }' <<< "$SHOW")
            DNS=$(awk -F: '/^IP4.DNS/ { sub(/#.*/, "", $2); a[++n] = $2 }
                            END { for (i = 1; i <= n; i++) printf "%s%s", (i > 1 ? ", " : ""), a[i] }' <<< "$SHOW")
        fi

        # VPN profilleri: kayitli olanlar + o an acik olanlar.
        VPNS=$(LC_ALL=C timeout 2 nmcli -t -f NAME,TYPE,ACTIVE connection show 2>/dev/null \
            | sed 's/\\:/@@C@@/g' \
            | awk -F: '$2 ~ /vpn|wireguard/ { print $1 ":" $3 }')

        # Wi-Fi agları (radyo kapaliysa hic tarama yapma).
        LIST=""
        if [ "$WIFI_ON" = true ]; then
            if [ "$RESCAN" = "yes" ]; then LT=15; else LT=4; fi
            LIST=$(LC_ALL=C timeout "$LT" nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY \
                dev wifi list --rescan "$RESCAN" 2>/dev/null)
        fi
        SAVED=$(LC_ALL=C timeout 2 nmcli -t -f NAME,TYPE connection show 2>/dev/null \
            | sed 's/\\:/@@C@@/g' \
            | awk -F: '$2 == "802-11-wireless" { gsub(/@@C@@/, ":", $1); print $1 }')

        jq -n -c \
            --argjson wifiOn "$WIFI_ON" \
            --arg devices "$DEVICES" --arg vpns "$VPNS" \
            --arg list "$LIST" --arg saved "$SAVED" \
            --arg ip "$IP" --arg gw "$GW" --arg dns "$DNS" '
            def unesc: gsub("@@C@@"; ":");

            ($saved | split("\n") | map(select(length > 0))) as $sv

            | ($devices | split("\n") | map(select(length > 0))
               | map(split(":") | {
                     name: (.[0] // "" | unesc),
                     type: (.[1] // ""),
                     state: (.[2] // "" | unesc),
                     connection: (.[3] // "" | unesc)
                 })
               | map(select(.type != "loopback" and .type != "wifi-p2p"))) as $devs

            | ($vpns | split("\n") | map(select(length > 0))
               | map(split(":") | { name: (.[0] // "" | unesc), active: ((.[1] // "") == "yes") })) as $vpnList

            | ($list | split("\n") | map(select(length > 0))
               | map( (gsub("\\\\:"; "@@C@@") | split(":")) as $f
                      | { inUse: ($f[0] == "*"),
                          ssid: (($f[1] // "") | unesc),
                          signal: ((($f[2] // "0") | tonumber?) // 0),
                          security: (($f[3] // "") | unesc) } )
               | map(select(.ssid != ""))
               | group_by(.ssid) | map(max_by(.signal))
               | map(.ssid as $s | . + {
                     secured: (.security != "" and .security != "--"),
                     saved: (($sv | index($s)) != null),
                     visible: true })) as $nets

            | ($nets + ( $sv
                | map(select(. as $s | ($nets | map(.ssid) | index($s)) == null))
                | map({ inUse: false, ssid: ., signal: 0, security: "",
                        secured: true, saved: true, visible: false }) )
               | sort_by([ (if .inUse then 0 else 1 end),
                           (if .visible then 0 else 1 end),
                           -.signal ])) as $allNets

            | {
                wifiOn: $wifiOn,
                devices: $devs,
                vpns: $vpnList,
                nets: $allNets,
                address: { ip: $ip, gateway: $gw, dns: $dns }
              }'
        ;;
    wifi-toggle)
        cur=$(LC_ALL=C nmcli radio wifi 2>/dev/null)
        if [ "$cur" = "enabled" ] || [ "$cur" = "etkin" ]; then
            LC_ALL=C nmcli radio wifi off >/dev/null 2>&1
        else
            LC_ALL=C nmcli radio wifi on >/dev/null 2>&1
        fi
        jq -n -c '{ ok: true, msg: "" }'
        ;;
    connect)
        ssid=$(b64d "$VALUE"); pass=$(b64d "$VALUE2")
        [ -n "$ssid" ] || exit 0
        if [ -n "$pass" ]; then
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
        result "$rc" "$out"
        ;;
    disconnect)
        ssid=$(b64d "$VALUE"); [ -n "$ssid" ] || exit 0
        out=$(timeout 15 nmcli connection down id "$ssid" 2>&1); rc=$?
        result "$rc" "$out"
        ;;
    forget)
        ssid=$(b64d "$VALUE"); [ -n "$ssid" ] || exit 0
        out=$(timeout 15 nmcli connection delete id "$ssid" 2>&1); rc=$?
        result "$rc" "$out"
        ;;
    vpn-up)
        name=$(b64d "$VALUE"); [ -n "$name" ] || exit 0
        out=$(timeout 45 nmcli connection up id "$name" 2>&1); rc=$?
        result "$rc" "$out"
        ;;
    vpn-down)
        name=$(b64d "$VALUE"); [ -n "$name" ] || exit 0
        out=$(timeout 15 nmcli connection down id "$name" 2>&1); rc=$?
        result "$rc" "$out"
        ;;
    device-up)
        dev=$(b64d "$VALUE"); [ -n "$dev" ] || exit 0
        out=$(timeout 30 nmcli device connect "$dev" 2>&1); rc=$?
        result "$rc" "$out"
        ;;
    device-down)
        dev=$(b64d "$VALUE"); [ -n "$dev" ] || exit 0
        out=$(timeout 15 nmcli device disconnect "$dev" 2>&1); rc=$?
        result "$rc" "$out"
        ;;
esac
