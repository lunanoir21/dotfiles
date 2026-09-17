#!/usr/bin/env bash
# Sidebar Center Wi-Fi listesi: gorunen aglari + kayitli profilleri JSON basar.
# Kullanim: wifi_list.sh [rescan]
#   rescan -> nmcli'ye taze tarama yaptirir (birkac saniye surebilir).
#
# Cikti:
#   { "on": bool, "nets": [ { ssid, signal, security, secured, saved, inUse } ] }
#
# NOT: nmcli terse ciktisinda ':' karakteri '\:' olarak kacirilir. Alanlara
# bolmeden once bunlari bir nobetci dizeye cevirip sonra geri koyuyoruz; aksi
# halde icinde ':' olan SSID'ler listeyi kaydiriyor.

RESCAN="no"
[ "$1" = "rescan" ] && RESCAN="yes"

RADIO=$(LC_ALL=C timeout 2 nmcli radio wifi 2>/dev/null)
if [ "$RADIO" != "enabled" ]; then
    jq -n -c '{ on: false, nets: [] }'
    exit 0
fi

# rescan yes bazen 10sn'ye kadar surebiliyor; timeout'u ona gore veriyoruz.
if [ "$RESCAN" = "yes" ]; then LIST_TIMEOUT=15; else LIST_TIMEOUT=4; fi

LIST=$(LC_ALL=C timeout "$LIST_TIMEOUT" nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY \
    dev wifi list --rescan "$RESCAN" 2>/dev/null)

SAVED=$(LC_ALL=C timeout 2 nmcli -t -f NAME,TYPE connection show 2>/dev/null \
    | sed 's/\\:/@@C@@/g' \
    | awk -F: '$2 == "802-11-wireless" { gsub(/@@C@@/, ":", $1); print $1 }')

jq -n -c --arg list "$LIST" --arg saved "$SAVED" '
    ($saved | split("\n") | map(select(length > 0))) as $sv
    | [ $list
        | split("\n")[]
        | select(length > 0)
        | (gsub("\\\\:"; "@@C@@") | split(":")) as $f
        | {
            inUse:    ($f[0] == "*"),
            ssid:     (($f[1] // "") | gsub("@@C@@"; ":")),
            signal:   ((($f[2] // "0") | tonumber?) // 0),
            security: (($f[3] // "") | gsub("@@C@@"; ":"))
          } ]
    | map(select(.ssid != ""))
    # Ayni SSID birden cok AP olarak gorunebilir: en guclu sinyali tut.
    | group_by(.ssid) | map(max_by(.signal))
    | map(.ssid as $s | . + {
        secured: (.security != "" and .security != "--"),
        saved:   (($sv | index($s)) != null),
        visible: true
      })
    # Menzil disindaki kayitli aglar da listede kalsin: kullanici oradan
    # "unut" diyebilsin diye. Sinyalsiz ve soluk gosteriliyorlar.
    | . as $nets
    | $nets + ( $sv
        | map(select(. as $s | ($nets | map(.ssid) | index($s)) == null))
        | map({ inUse: false, ssid: ., signal: 0, security: "",
                secured: true, saved: true, visible: false }) )
    # Bagli ag hep en ustte, sonra gorunurler, sonra sinyal gucune gore.
    | sort_by([ (if .inUse then 0 else 1 end),
                (if .visible then 0 else 1 end),
                -.signal ])
    | { on: true, nets: . }'
