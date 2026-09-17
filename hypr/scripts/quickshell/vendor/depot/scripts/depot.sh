#!/usr/bin/env bash
# Depot's package backend. Detects the system package manager and wraps its
# search, install and remove. Every action prints exactly one JSON line.
#
#   depot.sh detect
#   depot.sh featured
#   depot.sh search  <query_b64>
#   depot.sh install <package_b64> <repo|aur>
#   depot.sh remove  <package_b64>
#
# Arguments arrive base64-encoded so nothing a user types can turn into a
# shell word or an option on the way in.
set -uo pipefail
export LC_ALL=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
featured_file="${DEPOT_FEATURED_FILE:-$script_dir/../data/featured.json}"
result_limit=40

b64d() { printf '%s' "${1:-}" | base64 -d 2>/dev/null; }

# type -P, not command -v: an alias such as apt-get='man pacman' must not
# count as a package manager.
detect_backend() {
    if type -P pacman >/dev/null; then
        echo pacman
    elif type -P apt-get >/dev/null && type -P dpkg-query >/dev/null; then
        echo apt
    elif type -P dnf >/dev/null; then
        echo dnf
    fi
}

# DEPOT_AUR_HELPER=yay|paru picks one when both are installed; =none hides AUR.
detect_aur_helper() {
    [ "${1:-}" = pacman ] || return 0
    case "${DEPOT_AUR_HELPER:-}" in
        none) return 0 ;;
        yay|paru)
            if type -P "$DEPOT_AUR_HELPER" >/dev/null; then echo "$DEPOT_AUR_HELPER"; fi
            return 0
            ;;
    esac
    local helper
    for helper in yay paru; do
        if type -P "$helper" >/dev/null; then echo "$helper"; return 0; fi
    done
}

# A hint only. Agents are matched by process name; desktops that run the agent
# inside their shell (GNOME, Cinnamon) are matched by that shell.
polkit_agent_running() {
    pgrep -u "$(id -u)" -f 'polkit-kde-authentication-agent|polkit-gnome-authentication-agent|hyprpolkitagent|lxpolkit|lxqt-policykit-agent|polkit-mate-authentication-agent|mate-polkit|xfce-polkit|budgie-polkit|polkit-efl|soteria|gnome-shell|cinnamon' >/dev/null
}

installed_names() {
    case "${1:-}" in
        pacman) pacman -Qq 2>/dev/null ;;
        apt) dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null | awk '$1 == "ii" { print $2 }' ;;
        dnf) rpm -qa --qf '%{NAME}\n' 2>/dev/null ;;
    esac
}

installed_json() {
    installed_names "${1:-}" | jq -R -s -c 'split("\n") | map(select(length > 0) | {(.): true}) | add // {}'
}

# pacman and apt-cache read search terms as POSIX extended regexes; without
# this, searching "c++" matches every package with a "c" in it.
escape_ere() { printf '%s' "$1" | sed -e 's/[][\\.*^$+?(){}|]/\\&/g'; }

search_pacman() {
    local patterns=() term
    for term in "$@"; do patterns+=("$(escape_ere "$term")"); done
    timeout 15 pacman -Ss -- "${patterns[@]}" 2>/dev/null \
        | awk '/^[^ \t]/ { n = index($1, "/"); repo = substr($1, 1, n - 1); name = substr($1, n + 1); version = $2; next }
               /^    /   { sub(/^    /, ""); gsub(/\t/, " "); print repo "\t" name "\t" version "\t" $0 }' \
        | head -n 400 \
        | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t")
              | {repo: .[0], name: .[1], version: .[2], description: (.[3] // ""), source: "repo"})'
}

search_aur() {
    local query="$1" encoded
    if [ "${#query}" -lt 2 ] || ! type -P curl >/dev/null; then echo '[]'; return; fi
    encoded=$(jq -rn --arg q "$query" '$q | @uri')
    timeout 8 curl -fsS "https://aur.archlinux.org/rpc/v5/search/$encoded?by=name-desc" 2>/dev/null \
        | jq -c '[.results[]? | {repo: "aur", name: .Name, version: .Version,
                  description: (.Description // ""), source: "aur", popularity: (.Popularity // 0)}]' 2>/dev/null \
        || echo '[]'
}

search_apt() {
    local patterns=() term
    for term in "$@"; do patterns+=("$(escape_ere "$term")"); done
    timeout 15 apt-cache search -- "${patterns[@]}" 2>/dev/null \
        | head -n 400 \
        | awk '{ i = index($0, " - "); if (i) print substr($0, 1, i - 1) "\t" substr($0, i + 3) }' \
        | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t")
              | {repo: "", name: .[0], version: "", description: (.[1] // ""), source: "repo"})'
}

# dnf4 and dnf5 print `dnf search` differently; repoquery's queryformat is the
# one output both agree on. It matches names only.
search_dnf() {
    local glob
    glob="*$(IFS='*'; printf '%s' "$*")*"
    timeout 30 dnf -q repoquery --latest-limit=1 --qf '%{name}\t%{version}\t%{summary}\n' -- "$glob" 2>/dev/null \
        | head -n 400 \
        | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t")
              | {repo: "", name: .[0], version: (.[1] // ""), description: (.[2] // ""), source: "repo"})
              | unique_by(.name)'
}

emit_result() { # $1 exit code, $2 command output, [$3 reason]
    local rc="$1" text="$2" reason="${3:-}" msg
    msg=$(printf '%s' "$text" \
        | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' \
        | tr -d '\r' \
        | awk 'NF { line = $0 } END { print line }' \
        | cut -c1-240)
    if [ -z "$reason" ] && [ "$rc" -ne 0 ]; then
        case "$text" in
            *"No authentication agent found"*) reason="no-agent" ;;
            *"Request dismissed"*) reason="cancelled" ;;
            *"Not authorized"*) reason="denied" ;;
            *"unable to lock database"*|*"Could not get lock"*) reason="busy" ;;
            *)
                case "$rc" in
                    124) reason="timeout" ;;
                    126) reason="cancelled" ;;
                    127) reason="denied" ;;
                    *) reason="failed" ;;
                esac
                ;;
        esac
    fi
    jq -n -c --argjson code "$rc" --arg reason "$reason" --arg msg "$msg" \
        '{ok: ($code == 0 and $reason == ""), code: $code, reason: $reason, msg: $msg}'
}

action="${1:-}"

case "$action" in
    detect)
        backend=$(detect_backend)
        helper=$(detect_aur_helper "$backend")
        agent=false; polkit_agent_running && agent=true
        pkexec=false; type -P pkexec >/dev/null && pkexec=true
        curl=false; type -P curl >/dev/null && curl=true
        jq -n -c --arg backend "$backend" --arg helper "$helper" \
            --argjson agent "$agent" --argjson pkexec "$pkexec" --argjson curl "$curl" \
            '{backend: $backend, aurHelper: $helper, polkitAgent: $agent,
              pkexec: $pkexec, curl: $curl, supported: ($backend != "")}'
        ;;

    # Package lists reach jq on stdin, never as arguments: one argument is
    # capped at 128 KiB, and a big system's installed list alone passes that.
    featured)
        if [ ! -r "$featured_file" ]; then echo '[]'; exit 0; fi
        backend=$(detect_backend)
        helper=$(detect_aur_helper "$backend")
        { cat "$featured_file"; installed_json "$backend"; } \
            | jq -s -c --arg backend "$backend" --arg helper "$helper" '
            .[1] as $installed
            | .[0]
            | map(
                (.packages[$backend] // "") as $native
                | (if $backend == "pacman" then (.packages.aur // "") else "" end) as $aur
                | (if $native != "" then {package: $native, source: "repo"}
                   elif $aur != "" then {package: $aur, source: "aur"}
                   else {package: "", source: ""} end) as $pick
                | del(.packages) + $pick + {
                    available: ($pick.package != "" and ($pick.source != "aur" or $helper != "")),
                    installed: ($pick.package != "" and ($installed[$pick.package] // false))
                  })' 2>/dev/null || echo '[]'
        ;;

    # pacman lists a package once per repo that carries it, highest priority
    # first, so the first listing is the one pacman would install.
    search)
        query=$(b64d "${2:-}" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//' | cut -c1-80)
        if [ -z "$query" ]; then echo '[]'; exit 0; fi
        read -r -a terms <<< "$query"
        backend=$(detect_backend)
        helper=$(detect_aur_helper "$backend")
        case "$backend" in
            pacman) repo_rows=$(search_pacman "${terms[@]}"); aur_rows=$(search_aur "$query") ;;
            apt) repo_rows=$(search_apt "${terms[@]}"); aur_rows='[]' ;;
            dnf) repo_rows=$(search_dnf "${terms[@]}"); aur_rows='[]' ;;
            *) echo '[]'; exit 0 ;;
        esac
        { printf '%s\n' "${repo_rows:-[]}" "${aur_rows:-[]}"; installed_json "$backend"; } \
            | jq -s -c --arg helper "$helper" --argjson limit "$result_limit" \
                --arg q "$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')" '
            .[2] as $installed
            | ($q | gsub(" "; "-")) as $joined
            | (reduce .[0][] as $row ({seen: {}, rows: []};
                if .seen[$row.name] then . else .seen[$row.name] = true | .rows += [$row] end)) as $repo
            | $repo.rows + (.[1] | map(select($repo.seen[.name] | not)))
            | map(. + {
                installed: ($installed[.name] // false),
                available: (.source != "aur" or $helper != ""),
                rank: ((.name | ascii_downcase) as $n
                    | if $n == $q or $n == $joined then 0
                      elif ($n | startswith($q)) or ($n | startswith($joined)) then 1
                      elif ($n | contains($q)) or ($n | contains($joined)) then 2
                      else 3 end)
              })
            | sort_by(.rank, (if .source == "aur" then 1 else 0 end), -(.popularity // 0), (.name | length), .name)
            | .[:$limit]
            | map(del(.rank, .popularity))'
        ;;

    install|remove)
        package=$(b64d "${2:-}")
        source="${3:-repo}"
        if [[ ! "$package" =~ ^[A-Za-z0-9@._+][A-Za-z0-9@._+-]*$ ]]; then
            emit_result 2 "invalid package name" invalid
            exit 0
        fi
        backend=$(detect_backend)
        if [ -z "$backend" ]; then
            emit_result 1 "no supported package manager" unsupported
            exit 0
        fi

        # AUR helpers refuse to run as root, so they run as the user and are
        # told to use pkexec for the one step that needs root. That keeps the
        # graphical polkit prompt instead of a sudo that has no terminal.
        if [ "$action" = install ] && [ "$source" = aur ]; then
            helper=$(detect_aur_helper "$backend")
            if [ -z "$helper" ]; then
                emit_result 1 "no AUR helper installed" no-helper
                exit 0
            fi
            case "$helper" in
                yay) cmd=(yay -S --noconfirm --needed --answerdiff None --answerclean None --sudo pkexec -- "$package") ;;
                paru) cmd=(paru -S --noconfirm --needed --skipreview --sudo pkexec -- "$package") ;;
            esac
            limit_seconds=1800
        else
            case "$backend:$action" in
                pacman:install) cmd=(pkexec "$(type -P pacman)" -S --noconfirm --needed -- "$package") ;;
                pacman:remove) cmd=(pkexec "$(type -P pacman)" -Rns --noconfirm -- "$package") ;;
                apt:install) cmd=(pkexec "$(type -P env)" DEBIAN_FRONTEND=noninteractive "$(type -P apt-get)" install -y "$package") ;;
                apt:remove) cmd=(pkexec "$(type -P env)" DEBIAN_FRONTEND=noninteractive "$(type -P apt-get)" remove -y "$package") ;;
                dnf:install) cmd=(pkexec "$(type -P dnf)" install -y "$package") ;;
                dnf:remove) cmd=(pkexec "$(type -P dnf)" remove -y "$package") ;;
            esac
            limit_seconds=900
        fi

        output=$(timeout "$limit_seconds" "${cmd[@]}" 2>&1 < /dev/null)
        emit_result "$?" "$output"
        ;;

    *)
        printf 'usage: depot.sh detect | featured | search <query_b64> | install <package_b64> <repo|aur> | remove <package_b64>\n' >&2
        exit 2
        ;;
esac
