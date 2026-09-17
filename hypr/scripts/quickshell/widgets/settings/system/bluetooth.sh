#!/usr/bin/env bash
# Bluetooth: adaptor durumu, bilinen cihazlar, eslestirme ve baglanti.
#
# bluetoothctl cihaz basina sorgulanirsa cok yavas (her cagri kendi REPL'ini
# acip kapatiyor). Bunun yerine uc toplu cagri yapip kesisimlerini aliyoruz:
# tum cihazlar, eslesmisler, bagli olanlar.
#
# TARAMA HAKKINDA (onemli): bluez'de kesif oturumu onu baslatan D-Bus
# istemcisine bagli. `bluetoothctl scan on` etkilesimsiz cagrildiginda komutu
# yollayip HEMEN cikiyor, cikisiyla birlikte kesif de kapaniyor: adaptor
# "Discovering: no" kaliyor ve hicbir yeni cihaz bulunmuyordu. Bu yuzden
# tarayiciyi omru boyunca ayakta tutuyoruz (--timeout, yoksa borudan beslenen
# etkilesimli oturum) ve PID'ini saklayip sonra oldururuz.
#
# Kullanim:
#   bluetooth.sh status
#   bluetooth.sh power-toggle | scan-on | scan-off
#   bluetooth.sh connect <mac> | disconnect <mac> | pair <mac> | remove <mac>
#   bluetooth.sh service-start

ACTION="${1:-status}"
VALUE="$2"

BTCTL="timeout 4 bluetoothctl"

RUNDIR="${XDG_RUNTIME_DIR:-/tmp}/quickshell"
SCAN_PIDFILE="$RUNDIR/bt_scan.pid"
SCAN_SECS=180   # tarayicinin kendiliginden sonecegi sure; pil icin siniri var

result() { # $1 = ok (true/false), $2 = mesaj
    jq -n -c --argjson ok "$1" --arg m "$2" '{ ok: $ok, msg: $m }'
}

# bluetoothctl ciktisindaki son anlamli hata satiri; yoksa bos.
err_line() { grep -iE 'fail|error|not available|not ready|no default|does not exist' <<< "$1" | tail -n1; }

# Cihazin gercek durumu. bluetoothctl basarisiz islemde de 0 donup "success"
# benzeri satirlar basabildigi icin ciktiyi degil, islemden sonraki durumu
# sorguyoruz: tek dogru kaynak bu.
dev_prop() { # $1 = mac, $2 = ozellik adi (Connected/Paired/Trusted)
    $BTCTL info "$1" 2>/dev/null | sed -n "s/^[[:space:]]*$2:[[:space:]]*//p" | head -n1
}

# MAC listesini satir satir basar: "Device AA:BB:.. Ad" -> "AA:BB:..|Ad"
devices_of() { # $1 = "" | Paired | Connected
    $BTCTL devices $1 2>/dev/null \
        | awk '/^Device / { mac = $2; $1 = ""; $2 = ""; sub(/^[[:space:]]+/, "");
                            printf "%s|%s\n", mac, $0 }'
}

has_timeout_flag() { bluetoothctl --help 2>&1 | grep -q -- '--timeout'; }

scan_stop() {
    if [ -f "$SCAN_PIDFILE" ]; then
        read -r p < "$SCAN_PIDFILE" 2>/dev/null
        if [ -n "$p" ]; then
            kill -- "-$p" 2>/dev/null   # setsid ile ayri oturum: grubu birden gonder
            kill "$p" 2>/dev/null
        fi
        rm -f "$SCAN_PIDFILE"
    fi
    # PID dosyasi kaybolduysa ya da onceki surumden kalan bir tarayici varsa.
    pkill -f "bluetoothctl --timeout $SCAN_SECS scan on" >/dev/null 2>&1
    pkill -f "bluetoothctl scan on" >/dev/null 2>&1
    $BTCTL scan off >/dev/null 2>&1
}

scan_start() {
    scan_stop
    mkdir -p "$RUNDIR" 2>/dev/null
    if has_timeout_flag; then
        setsid bluetoothctl --timeout "$SCAN_SECS" scan on >/dev/null 2>&1 &
    else
        # --timeout yoksa (eski bluez): stdin'i acik tutmak da oturumu ayakta
        # tutuyor. Boru kapaninca bluetoothctl cikar, kesif de kapanir.
        setsid bash -c "{ printf 'scan on\n'; sleep $SCAN_SECS; } | bluetoothctl" >/dev/null 2>&1 &
    fi
    echo $! > "$SCAN_PIDFILE"
}

case "$ACTION" in
    status)
        # Servis hic kurulu degilse (ya da durdurulmussa) bluetoothctl'i
        # cagirmak D-Bus'i bosuna uyandirmaya calisiyor; erken cikiyoruz.
        UNIT=$(systemctl is-active bluetooth 2>/dev/null)
        AVAILABLE=false; RUNNING=false
        systemctl list-unit-files bluetooth.service >/dev/null 2>&1 && AVAILABLE=true
        [ "$UNIT" = "active" ] && RUNNING=true

        if [ "$RUNNING" != true ]; then
            jq -n -c --argjson available "$AVAILABLE" \
                '{ available: $available, running: false, powered: false,
                   discovering: false, devices: [] }'
            exit 0
        fi

        SHOW=$($BTCTL show 2>/dev/null)
        POWERED=false; DISCOVERING=false
        grep -q "Powered: yes" <<< "$SHOW" && POWERED=true
        grep -q "Discovering: yes" <<< "$SHOW" && DISCOVERING=true

        ALL=$(devices_of "")
        PAIRED=$(devices_of Paired)
        CONNECTED=$(devices_of Connected)

        jq -n -c \
            --argjson available "$AVAILABLE" --argjson powered "$POWERED" \
            --argjson discovering "$DISCOVERING" \
            --arg all "$ALL" --arg paired "$PAIRED" --arg connected "$CONNECTED" '
            def macs: split("\n") | map(select(length > 0) | split("|")[0]);

            ($paired | macs) as $p
            | ($connected | macs) as $c
            | {
                available: $available, running: true,
                powered: $powered, discovering: $discovering,
                devices: ( $all | split("\n") | map(select(length > 0))
                    | map(split("|") | { mac: .[0], name: ((.[1] // "") | if . == "" then .[0] else . end) })
                    | map(.mac as $m | . + {
                          paired: (($p | index($m)) != null),
                          connected: (($c | index($m)) != null) })
                    # Bagli olanlar uste, sonra eslesmisler, sonra gerisi.
                    | sort_by([ (if .connected then 0 else 1 end),
                                (if .paired then 0 else 1 end),
                                (.name | ascii_downcase) ]) )
              }'
        ;;
    power-toggle)
        if $BTCTL show 2>/dev/null | grep -q "Powered: yes"; then
            scan_stop
            $BTCTL power off >/dev/null 2>&1
        else
            $BTCTL power on >/dev/null 2>&1
        fi
        result true ""
        ;;
    scan-on)
        scan_start
        result true ""
        ;;
    scan-off)
        scan_stop
        result true ""
        ;;
    connect|disconnect|pair|remove)
        [ -n "$VALUE" ] || exit 0

        # Kesif acikken radyo surekli mesgul: baglanma/eslestirme cogu adaptorde
        # zaman asimina dusuyor. Once taramayi kapatiyoruz.
        case "$ACTION" in
            connect|pair) scan_stop ;;
        esac

        # bluez cihazi hic tanimiyorsa (tarama bitmis, kayit dusmus) `connect`
        # "not available" yazip yine de zaman asimina kadar asili kaliyor:
        # arayuz 30 saniye kilitleniyordu. Once tanidigini dogruluyoruz.
        if [ "$ACTION" != "remove" ] && [ -z "$(dev_prop "$VALUE" Paired)" ]; then
            result false "Cihaz artık görünmüyor. Yeniden arama yapıp tekrar deneyin."
            exit 0
        fi

        case "$ACTION" in
            pair)
                # Eslestirme bir ajan ister; etkilesimsiz kabukta soru soracak
                # kimse olmadigi icin NoInputNoOutput ile "just works" moduna
                # aliyoruz. Ajansiz cagri onay bekleyen cihazlarda sessizce
                # basarisiz oluyordu.
                out=$(timeout 40 bluetoothctl --agent NoInputNoOutput pair "$VALUE" 2>&1)
                if [ "$(dev_prop "$VALUE" Paired)" != "yes" ]; then
                    m=$(err_line "$out")
                    result false "${m:-Eşleştirilemedi. Cihazı eşleştirme moduna alıp tekrar deneyin.}"
                    exit 0
                fi
                # Guven vermezsek cihaz bir daha kendiliginden baglanmiyor.
                timeout 6 bluetoothctl trust "$VALUE" >/dev/null 2>&1
                # Eslestirme tek basina ses cihazini kullanilabilir yapmiyor;
                # kullanicinin bekledigi son durum "bagli".
                out2=$(timeout 30 bluetoothctl connect "$VALUE" 2>&1)
                if [ "$(dev_prop "$VALUE" Connected)" = "yes" ]; then
                    result true ""
                else
                    m=$(err_line "$out2")
                    result false "Eşleştirildi ama bağlanılamadı${m:+: $m}"
                fi
                ;;
            connect)
                # Eslesmemis cihaza dogrudan connect bluez tarafinda
                # basarisiz olur; once eslestirip sonra baglaniyoruz.
                if [ "$(dev_prop "$VALUE" Paired)" != "yes" ]; then
                    timeout 40 bluetoothctl --agent NoInputNoOutput pair "$VALUE" >/dev/null 2>&1
                fi
                timeout 6 bluetoothctl trust "$VALUE" >/dev/null 2>&1
                out=$(timeout 30 bluetoothctl connect "$VALUE" 2>&1)
                if [ "$(dev_prop "$VALUE" Connected)" = "yes" ]; then
                    result true ""
                else
                    m=$(err_line "$out")
                    result false "${m:-Bağlanılamadı. Cihaz açık ve menzilde mi?}"
                fi
                ;;
            disconnect)
                out=$(timeout 20 bluetoothctl disconnect "$VALUE" 2>&1)
                if [ "$(dev_prop "$VALUE" Connected)" = "no" ]; then
                    result true ""
                else
                    m=$(err_line "$out")
                    result false "${m:-Bağlantı kesilemedi}"
                fi
                ;;
            remove)
                out=$(timeout 20 bluetoothctl remove "$VALUE" 2>&1)
                # Silinmisse info artik cihazi bulamaz, ozellik bos doner.
                if [ -z "$(dev_prop "$VALUE" Paired)" ]; then
                    result true ""
                else
                    m=$(err_line "$out")
                    result false "${m:-Cihaz kaldırılamadı}"
                fi
                ;;
        esac
        ;;
    service-start)
        # Kullanici acikca istedi: servisi baslat (polkit parola sorabilir).
        systemctl start bluetooth >/dev/null 2>&1
        result true ""
        ;;
esac
