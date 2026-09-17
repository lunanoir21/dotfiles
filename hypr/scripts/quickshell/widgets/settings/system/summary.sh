#!/usr/bin/env bash
# Tek cagride sistem ozeti: sol gezinme cubugundaki canli rozetleri ve
# Genel Bakis sayfasini besler.
#
# Amac hiz: her alan icin en ucuz kaynak secildi (sysfs > /proc > tek nmcli cagrisi).
# Tum donanim ve masaustu gostergelerini canli JSON olarak dondurur.

# --- Ag ---------------------------------------------------------------------
NET_TYPE=""; NET_NAME=""; NET_UP=false; NET_IP=""
while IFS=: read -r dev typ state conn; do
    [ "$state" = "connected" ] || continue
    case "$typ" in
        wifi)     NET_TYPE="wifi";     NET_NAME="$conn"; NET_UP=true; break ;;
        ethernet) NET_TYPE="ethernet"; NET_NAME="$conn"; NET_UP=true; break ;;
    esac
done < <(LC_ALL=C timeout 2 nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null)

WIFI_ON=false
WIFI_RADIO=$(LC_ALL=C timeout 2 nmcli radio wifi 2>/dev/null)
if [ "$WIFI_RADIO" = "enabled" ] || [ "$WIFI_RADIO" = "etkin" ]; then
    WIFI_ON=true
elif [ "$NET_TYPE" = "wifi" ] && [ "$NET_UP" = true ]; then
    WIFI_ON=true
else
    for rfk in /sys/class/rfkill/*; do
        if [ -d "$rfk" ] && [ "$(< "$rfk/type" 2>/dev/null)" = "wlan" ]; then
            [ "$(< "$rfk/state" 2>/dev/null)" = "1" ] && WIFI_ON=true && break
        fi
    done
fi

if [ "$NET_UP" = true ]; then
    NET_IP=$(ip -4 -o addr show scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')
fi

# --- Bluetooth --------------------------------------------------------------
BT_RUNNING=false; BT_POWERED=false; BT_CONNECTED=0; BT_DEV=""
if [ "$(systemctl is-active bluetooth 2>/dev/null)" = "active" ]; then
    BT_RUNNING=true
    bt_show=$(timeout 2 bluetoothctl show 2>/dev/null)
    grep -q "Powered: yes" <<< "$bt_show" && BT_POWERED=true
    if [ "$BT_POWERED" = true ]; then
        BT_CONNECTED=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | grep -c '^Device ')
        BT_DEV=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | head -n1 | sed -E 's/^Device [^ ]+ //')
    fi
fi

# --- Ses --------------------------------------------------------------------
SINK_NAME=""; VOLUME=0; MUTED=false
def_sink=$(timeout 2 pactl get-default-sink 2>/dev/null)
if [ -n "$def_sink" ]; then
    SINK_NAME=$(timeout 2 pactl -f json list sinks 2>/dev/null \
        | jq -r --arg d "$def_sink" '.[] | select(.name == $d)
            | (.properties["device.profile.description"]
               // .properties["node.nick"] // .description // "")' 2>/dev/null | head -n1)
fi
raw=$(LC_ALL=C timeout 1 wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
if [ -n "$raw" ]; then
    VOLUME=$(awk '{ print int($2 * 100 + 0.5) }' <<< "$raw")
    [[ "$raw" == *MUTED* ]] && MUTED=true
fi

# --- Pil & Guc --------------------------------------------------------------
BAT_PRESENT=false; CAPACITY=0; CHARGING=false
for bat in /sys/class/power_supply/BAT*; do
    [ -d "$bat" ] || continue
    BAT_PRESENT=true
    read -r CAPACITY < "$bat/capacity" 2>/dev/null || CAPACITY=0
    read -r bstate < "$bat/status" 2>/dev/null || bstate=""
    [ "$bstate" = "Charging" ] && CHARGING=true
    break
done

PROFILE=$(busctl --no-pager get-property net.hadess.PowerProfiles \
    /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null)
[ -z "$PROFILE" ] && PROFILE=$(busctl --no-pager get-property \
    org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles \
    org.freedesktop.UPower.PowerProfiles ActiveProfile 2>/dev/null)
PROFILE=$(sed -n 's/^s "\(.*\)"$/\1/p' <<< "$PROFILE")

# --- Sistem & Islemci -------------------------------------------------------
read -r up_secs _ < /proc/uptime 2>/dev/null || up_secs=0
up_secs=${up_secs%.*}
up_d=$((up_secs / 86400)); up_h=$(((up_secs % 86400) / 3600)); up_m=$(((up_secs % 3600) / 60))
if   [ "$up_d" -gt 0 ]; then UPTIME="${up_d} gün ${up_h} saat"
elif [ "$up_h" -gt 0 ]; then UPTIME="${up_h} saat ${up_m} dakika"
else                         UPTIME="${up_m} dakika"; fi

KERNEL=$(uname -r)
DISTRO=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")
[ -z "$DISTRO" ] && DISTRO="Linux"
HOSTNAME=$(uname -n 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "linux")
HYPR_VER=$(timeout 1 hyprctl version 2>/dev/null | awk '/^Hyprland/ { print $2; exit }')
[ -z "$HYPR_VER" ] && HYPR_VER="v0.x"

# CPU
CPU_MODEL=$(awk -F: '/model name/ { gsub(/^[ \t]+/, "", $2); print $2; exit }' /proc/cpuinfo 2>/dev/null)
[ -z "$CPU_MODEL" ] && CPU_MODEL=$(lscpu 2>/dev/null | awk -F: '/Model name/ { gsub(/^[ \t]+/, "", $2); print $2; exit }')
[ -z "$CPU_MODEL" ] && CPU_MODEL="İşlemci"
CPU_CORES=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
LOAD_AVG=$(awk '{ print $1 }' /proc/loadavg 2>/dev/null || echo "0.0")

CPU_TEMP=""
for tz in /sys/class/thermal/thermal_zone*/temp; do
    if [ -f "$tz" ]; then
        t=$(< "$tz" 2>/dev/null)
        if [ -n "$t" ] && [ "$t" -gt 0 ] 2>/dev/null; then
            CPU_TEMP="$((t / 1000))°C"
            break
        fi
    fi
done

CPU_PERCENT=$(awk -v l="$LOAD_AVG" -v c="$CPU_CORES" 'BEGIN {
    p = int((l / c) * 100);
    if (p > 100) p = 100;
    if (p < 1 && l > 0) p = 1;
    print p
}')

# Bellek: /proc/meminfo
read -r MEM_TOTAL MEM_AVAIL < <(awk '/MemTotal/ { t = $2 } /MemAvailable/ { a = $2 } END { print t, a }' /proc/meminfo 2>/dev/null)
if [ -n "$MEM_TOTAL" ] && [ -n "$MEM_AVAIL" ] && [ "$MEM_TOTAL" -gt 0 ]; then
    MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
    MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))
    MEM_USED_G=$(awk -v u="$MEM_USED" 'BEGIN { printf "%.1f GiB", u / 1048576 }')
    MEM_TOTAL_G=$(awk -v t="$MEM_TOTAL" 'BEGIN { printf "%.1f GiB", t / 1048576 }')
    MEM_TEXT="${MEM_USED_G} / ${MEM_TOTAL_G}"
else
    MEM_PERCENT=0; MEM_USED_G="—"; MEM_TOTAL_G="—"; MEM_TEXT="—"
fi

# Depolama (Disk - root /)
read -r DISK_TOTAL_B DISK_USED_B DISK_AVAIL_B DISK_PCT < <(df -B1 / 2>/dev/null | awk 'NR==2 { gsub(/%/,"",$5); print $2, $3, $4, $5 }')
if [ -n "$DISK_TOTAL_B" ] && [ "$DISK_TOTAL_B" -gt 0 ]; then
    DISK_PERCENT="${DISK_PCT:-0}"
    DISK_USED_G=$(awk -v u="$DISK_USED_B" 'BEGIN { printf "%.0f GB", u / (1024*1024*1024) }')
    DISK_TOTAL_G=$(awk -v t="$DISK_TOTAL_B" 'BEGIN { printf "%.0f GB", t / (1024*1024*1024) }')
    DISK_FREE_G=$(awk -v a="$DISK_AVAIL_B" 'BEGIN { printf "%.0f GB", a / (1024*1024*1024) }')
    DISK_TEXT="${DISK_FREE_G} boş / ${DISK_TOTAL_G}"
else
    DISK_PERCENT=0; DISK_USED_G="—"; DISK_TOTAL_G="—"; DISK_FREE_G="—"; DISK_TEXT="—"
fi

# Hyprland pencereleri ve ekranlar
WIN_COUNT=0; MON_INFO=""; WS_COUNT=0
if command -v hyprctl &>/dev/null; then
    WIN_COUNT=$(timeout 1 hyprctl clients -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
    WS_COUNT=$(timeout 1 hyprctl workspaces -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
    MON_INFO=$(timeout 1 hyprctl monitors -j 2>/dev/null | jq -r '.[0] | "\(.name) (\(.width)x\(.height)@\(.refreshRate | floor)Hz)"' 2>/dev/null || echo "")
fi

jq -n -c \
    --arg netType "$NET_TYPE" --arg netName "$NET_NAME" --argjson netUp "$NET_UP" --argjson wifiOn "$WIFI_ON" --arg netIp "$NET_IP" \
    --argjson btRunning "$BT_RUNNING" --argjson btPowered "$BT_POWERED" --argjson btConnected "${BT_CONNECTED:-0}" --arg btDev "$BT_DEV" \
    --arg sink "$SINK_NAME" --argjson volume "${VOLUME:-0}" --argjson muted "$MUTED" \
    --argjson batPresent "$BAT_PRESENT" --argjson capacity "${CAPACITY:-0}" --argjson charging "$CHARGING" \
    --arg profile "${PROFILE:-unavailable}" \
    --arg uptime "$UPTIME" --arg kernel "$KERNEL" --arg distro "$DISTRO" \
    --arg host "$HOSTNAME" --arg hypr "$HYPR_VER" \
    --arg mem "$MEM_TEXT" --argjson memPct "${MEM_PERCENT:-0}" --arg memUsed "$MEM_USED_G" --arg memTotal "$MEM_TOTAL_G" \
    --arg disk "$DISK_TEXT" --argjson diskPct "${DISK_PERCENT:-0}" --arg diskUsed "$DISK_USED_G" --arg diskTotal "$DISK_TOTAL_G" --arg diskFree "$DISK_FREE_G" \
    --arg cpuModel "$CPU_MODEL" --argjson cpuCores "${CPU_CORES:-1}" --argjson cpuPct "${CPU_PERCENT:-0}" --arg cpuTemp "$CPU_TEMP" --arg loadAvg "$LOAD_AVG" \
    --argjson winCount "${WIN_COUNT:-0}" --argjson wsCount "${WS_COUNT:-0}" --arg monInfo "$MON_INFO" \
    '{
        network:   { type: $netType, name: $netName, up: $netUp, wifiOn: $wifiOn, ip: $netIp },
        bluetooth: { running: $btRunning, powered: $btPowered, connected: $btConnected, device: $btDev },
        audio:     { sink: $sink, volume: $volume, muted: $muted },
        battery:   { present: $batPresent, capacity: $capacity, charging: $charging },
        profile:   $profile,
        system:    {
            uptime: $uptime, kernel: $kernel, distro: $distro,
            hostname: $host, hyprland: $hypr,
            memory: $mem, memPercent: $memPct, memUsed: $memUsed, memTotal: $memTotal,
            disk: $disk, diskPercent: $diskPct, diskUsed: $diskUsed, diskTotal: $diskTotal, diskFree: $diskFree,
            cpuModel: $cpuModel, cpuCores: $cpuCores, cpuPercent: $cpuPct, cpuTemp: $cpuTemp, loadAvg: $loadAvg,
            windowsCount: $winCount, workspacesCount: $wsCount, primaryMonitor: $monInfo
        }
    }'
