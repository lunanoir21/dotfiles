#!/usr/bin/env bash
set -euo pipefail

settings_file="${DOCK_SETTINGS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/settings.json}"
action="${1:-list}"
pin_id="${2:-}"
defaults='["firefox","alacritty","thunar","code"]'

read_pins() {
    if [[ ! -f "$settings_file" ]]; then
        printf '%s\n' "$defaults"
        return
    fi

    jq -c --argjson defaults "$defaults" '
        (.dockPinned // $defaults)
        | map(tostring | ascii_downcase)
        | reduce .[] as $item ([]; if index($item) then . else . + [$item] end)
    ' "$settings_file"
}

# Tek bir yazımın atomik olması yetmiyor: iki ayrı çağrı (ör. app launcher'da
# iki uygulama art arda sabitlendiğinde) dosyayı aynı anda okuyup her biri
# yalnızca kendi değişikliğini içeren tam bir dosya yazıyor ve ikinci mv
# birincisini sessizce siliyordu. Oku-değiştir-yaz döngüsünün tamamı süreçler
# arası bir kilidin içinde.
_lock_held=0
with_lock() {
    [[ "$_lock_held" == "1" ]] && return 0
    local lock_file="$settings_file.lock"
    mkdir -p "$(dirname "$settings_file")"
    exec 200>"$lock_file"
    flock -w 5 200 || {
        printf 'dock_pins: could not lock %s\n' "$lock_file" >&2
        exit 3
    }
    _lock_held=1
}

write_pins() {
    local pins="$1"
    local temp_file
    with_lock
    [[ -f "$settings_file" ]] || printf '{}\n' > "$settings_file"
    temp_file="$(mktemp "$settings_file.dock-pins.XXXXXX")"
    jq --argjson pins "$pins" '.dockPinned = $pins' "$settings_file" > "$temp_file"
    chmod --reference="$settings_file" "$temp_file" 2>/dev/null || true
    mv "$temp_file" "$settings_file"
}

pin_id="${pin_id,,}"
pin_id="${pin_id#${pin_id%%[![:space:]]*}}"
pin_id="${pin_id%${pin_id##*[![:space:]]}}"
case "$action" in
    add|remove|toggle) with_lock ;;
esac

pins="$(read_pins)"

case "$action" in
    list)
        printf '%s\n' "$pins"
        ;;
    has)
        [[ -n "$pin_id" ]] && jq -e --arg id "$pin_id" 'index($id) != null' <<< "$pins" >/dev/null
        ;;
    add|remove|toggle)
        [[ -n "$pin_id" ]] || { printf 'dock_pins: empty application id\n' >&2; exit 2; }
        case "$action" in
            add) next="$(jq -c --arg id "$pin_id" 'if index($id) then . else . + [$id] end' <<< "$pins")" ;;
            remove) next="$(jq -c --arg id "$pin_id" 'map(select(. != $id))' <<< "$pins")" ;;
            toggle) next="$(jq -c --arg id "$pin_id" 'if index($id) then map(select(. != $id)) else . + [$id] end' <<< "$pins")" ;;
        esac
        write_pins "$next"
        printf '%s\n' "$next"
        ;;
    *)
        printf 'Usage: %s {list|has|add|remove|toggle} [application-id]\n' "$0" >&2
        exit 2
        ;;
esac
