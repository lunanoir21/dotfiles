#!/usr/bin/env bash
# Depot's settings store. Every write goes through here so the whole
# read-modify-write cycle sits inside one cross-process lock.
set -euo pipefail

settings_file="${DEPOT_SETTINGS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/depot/settings.json}"
action="${1:-get}"

defaults() {
    cat <<'JSON'
{
  "schemaVersion": 1,
  "appearance": {
    "theme": "black",
    "language": "auto"
  }
}
JSON
}

option_paths='["appearance.theme","appearance.language"]'

_lock_held=0
with_lock() {
    [[ "$_lock_held" == "1" ]] && return 0
    mkdir -p "$(dirname "$settings_file")"
    exec 200>"$settings_file.lock"
    flock -w 5 200 || {
        printf 'depot_store: could not lock %s.lock\n' "$settings_file" >&2
        exit 3
    }
    _lock_held=1
}

# Reads always go through the defaults so a missing file or a half-written
# key still yields a complete document.
read_all() {
    if [[ -f "$settings_file" ]]; then
        jq -c --argjson d "$(defaults)" '$d * .' "$settings_file" 2>/dev/null || defaults | jq -c .
    else
        defaults | jq -c .
    fi
}

write_all() {
    local document="$1"
    local temp_file
    with_lock
    temp_file="$(mktemp "$settings_file.depot.XXXXXX")"
    printf '%s' "$document" | jq . > "$temp_file"
    [[ -f "$settings_file" ]] && chmod --reference="$settings_file" "$temp_file" 2>/dev/null || true
    mv "$temp_file" "$settings_file"
}

require_arg() {
    [[ -n "${1:-}" ]] || {
        printf 'depot_store: missing argument for %s\n' "$action" >&2
        exit 2
    }
}

case "$action" in
    get)
        # First run materialises the file so the watcher has something to watch.
        if [[ ! -f "$settings_file" ]]; then
            with_lock
            write_all "$(defaults | jq -c .)"
        fi
        read_all
        ;;

    get-option)
        path="${2:-}"
        require_arg "$path"
        read_all | jq -c --arg p "$path" 'getpath($p | split("."))'
        ;;

    set-option)
        path="${2:-}"
        value="${3:-}"
        require_arg "$path"
        require_arg "$value"
        if ! jq -ne --arg p "$path" --argjson allowed "$option_paths" \
                 '$allowed | index($p) != null' >/dev/null; then
            printf 'depot_store: unknown option path: %s\n' "$path" >&2
            exit 2
        fi
        with_lock
        write_all "$(read_all | jq -c --arg p "$path" --argjson v "$value" \
            'setpath($p | split("."); $v)')"
        read_all | jq -c --arg p "$path" 'getpath($p | split("."))'
        ;;

    reset)
        with_lock
        write_all "$(defaults | jq -c .)"
        ;;

    *)
        printf 'depot_store: unknown action: %s\n' "$action" >&2
        printf 'usage: depot_store.sh [get|get-option <path>|set-option <path> <json>|reset]\n' >&2
        exit 2
        ;;
esac
