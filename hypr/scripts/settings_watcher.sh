#!/usr/bin/env bash

# File paths
SETTINGS_FILE="$HOME/.config/hypr/settings.json"
WEATHER_SCRIPT="$HOME/.config/hypr/scripts/weather.sh"
ENV_FILE="$HOME/.config/hypr/scripts/quickshell/widgets/calendar/.env"

# Target configuration files
CONF_DIR="$HOME/.config/hypr/config"
TMPL_DIR="$HOME/.config/hypr/templates"
SETTINGS_CONF="$CONF_DIR/settings.conf"
AUTOSTART_CONF="$CONF_DIR/autostart.conf"
ENV_CONF="$CONF_DIR/env.conf"
KEYBINDS_CONF="$CONF_DIR/keybindings.conf"
MONITORS_CONF="$CONF_DIR/monitors.conf"
ZSH_RC="$HOME/.zshrc"

# Ensure the required files and directories exist
mkdir -p "$CONF_DIR" "$TMPL_DIR" "$(dirname "$SETTINGS_FILE")" "$(dirname "$ENV_FILE")"
[ ! -f "$SETTINGS_FILE" ] && echo "{}" > "$SETTINGS_FILE"

CACHE_DIR="$HOME/.cache/settings_watcher"
mkdir -p "$CACHE_DIR"

compile_settings() {
    echo "Regenerating configurations from templates..."

    # Hash existing configs before any changes, split by monitor vs non-monitor.
    # This means a pure uiScale/wallpaperDir/weatherApiKey write never triggers a reload.
    OLD_NONMON_HASH=$(md5sum "$SETTINGS_CONF" "$KEYBINDS_CONF" "$AUTOSTART_CONF" "$ENV_CONF" 2>/dev/null | md5sum)
    OLD_MON_HASH=$(md5sum "$MONITORS_CONF" 2>/dev/null | md5sum)

    # Read state from JSON (Using 'has' to safely parse booleans)
    LANG=$(jq -r '.language // "us"' "$SETTINGS_FILE")
    KB_OPT=$(jq -r '.kbOptions // "grp:alt_shift_toggle"' "$SETTINGS_FILE")
    WP_DIR=$(jq -r '.wallpaperDir // empty' "$SETTINGS_FILE")

    PIC_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
    VID_DIR="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")"

    # Read the hardware variables injected by install.sh directly out of the JSON
    HW_ENV=$(jq -r '.hardwareEnvs[]? // empty' "$SETTINGS_FILE")

    # 1. Regenerate env.conf using the template
    echo "Regenerating env.conf..."
    sed -e "s|{{XDG_PICTURES_DIR}}|$PIC_DIR|g" \
        -e "s|{{XDG_VIDEOS_DIR}}|$VID_DIR|g" \
        -e "s|{{WALLPAPER_DIR}}|$WP_DIR|g" \
        -e "s|{{SCRIPT_DIR}}|$HOME/.config/hypr/scripts|g" \
        "$TMPL_DIR/env.conf.template" > "${ENV_CONF}.tmp"

    # Use awk to safely substitute the multi-line HW_ENV array without breaking escapes
    awk -v hw="$HW_ENV" '{
        if (index($0, "{{HARDWARE_ENV}}")) {
            print hw
        } else {
            print $0
        }
    }' "${ENV_CONF}.tmp" > "$ENV_CONF"
    rm -f "${ENV_CONF}.tmp"

    # Sync ZSH_RC if Wallpaper Dir changed
    if [ -n "$WP_DIR" ] && [ -f "$ZSH_RC" ]; then
        sed -i "s|^export WALLPAPER_DIR=.*|export WALLPAPER_DIR=\"$WP_DIR\"|" "$ZSH_RC"
    fi

    # 2. Regenerate settings.conf using template
    #
    # Görünüm/davranış değerleri settings.json'daki "hypr" nesnesinden geliyor.
    # Her varsayılan, bu ayarlar UI'dan yönetilmeye başlamadan önceki sabit
    # kodlu değerin aynısı — yani "hypr" anahtarı hiç yokken üretilen conf,
    # eski template'in çıktısıyla birebir aynı kalıyor.
    echo "Regenerating settings.conf..."

    # jq_hypr <anahtar> <varsayılan>
    # Sadece anahtar yoksa/null ise varsayılana düşer. Burada `//` KULLANILMAZ:
    # jq'da `false // "true"` -> "true" olduğu için, kapatılan her boolean ayar
    # (blurEnabled: false gibi) sessizce varsayılanına geri dönerdi.
    jq_hypr() {
        local out
        out=$(jq -r --arg k "$1" --arg d "$2" \
            'if (.hypr[$k] == null) then $d else .hypr[$k] end | tostring' \
            "$SETTINGS_FILE" 2>/dev/null)
        [ -n "$out" ] && echo "$out" || echo "$2"
    }

    BORDER_SIZE=$(jq_hypr borderSize 2)
    GAPS_IN=$(jq_hypr gapsIn 4)
    GAPS_OUT=$(jq_hypr gapsOut 4)
    FLOAT_GAPS=$(jq_hypr floatGaps 6)
    RESIZE_ON_BORDER=$(jq_hypr resizeOnBorder true)

    ROUNDING=$(jq_hypr rounding 4)
    ACTIVE_OPACITY=$(jq_hypr activeOpacity 1.0)
    INACTIVE_OPACITY=$(jq_hypr inactiveOpacity 1.0)
    BLUR_ENABLED=$(jq_hypr blurEnabled true)
    BLUR_SIZE=$(jq_hypr blurSize 8)
    BLUR_PASSES=$(jq_hypr blurPasses 2)
    SHADOW_ENABLED=$(jq_hypr shadowEnabled false)

    SENSITIVITY=$(jq_hypr sensitivity 0)
    NATURAL_SCROLL=$(jq_hypr naturalScroll true)

    FONT_FAMILY=$(jq_hypr fontFamily "JetBrains Mono")
    ANIMATIONS_ENABLED=$(jq_hypr animationsEnabled true)
    ANIM_SPEED=$(jq_hypr animSpeed 5)

    sed -e "s|{{KB_LAYOUT}}|$LANG|g" \
        -e "s|{{KB_OPTIONS}}|$KB_OPT|g" \
        -e "s|{{BORDER_SIZE}}|$BORDER_SIZE|g" \
        -e "s|{{GAPS_IN}}|$GAPS_IN|g" \
        -e "s|{{GAPS_OUT}}|$GAPS_OUT|g" \
        -e "s|{{FLOAT_GAPS}}|$FLOAT_GAPS|g" \
        -e "s|{{RESIZE_ON_BORDER}}|$RESIZE_ON_BORDER|g" \
        -e "s|{{ROUNDING}}|$ROUNDING|g" \
        -e "s|{{ACTIVE_OPACITY}}|$ACTIVE_OPACITY|g" \
        -e "s|{{INACTIVE_OPACITY}}|$INACTIVE_OPACITY|g" \
        -e "s|{{BLUR_ENABLED}}|$BLUR_ENABLED|g" \
        -e "s|{{BLUR_SIZE}}|$BLUR_SIZE|g" \
        -e "s|{{BLUR_PASSES}}|$BLUR_PASSES|g" \
        -e "s|{{SHADOW_ENABLED}}|$SHADOW_ENABLED|g" \
        -e "s|{{SENSITIVITY}}|$SENSITIVITY|g" \
        -e "s|{{NATURAL_SCROLL}}|$NATURAL_SCROLL|g" \
        -e "s|{{FONT_FAMILY}}|$FONT_FAMILY|g" \
        -e "s|{{ANIMATIONS_ENABLED}}|$ANIMATIONS_ENABLED|g" \
        -e "s|{{ANIM_SPEED}}|$ANIM_SPEED|g" \
        "$TMPL_DIR/settings.conf.template" > "$SETTINGS_CONF"

    # 3. Regenerate autostart.conf
    echo "Regenerating autostart.conf..."
    cp "$TMPL_DIR/autostart.conf.template" "$AUTOSTART_CONF"

    # Dump normal startup entries
    jq -r '.startup[]? | "exec-once = \(.command)"' "$SETTINGS_FILE" >> "$AUTOSTART_CONF"

    # 4. Regenerate keybindings.conf
    echo "Regenerating keybindings.conf..."
    cp "$TMPL_DIR/keybinds.conf.template" "$KEYBINDS_CONF"
    jq -r '.keybinds[]? | "\(.type // "bind") = \(.mods // ""), \(.key // ""), \(.dispatcher // "exec")\(if .command and .command != "" then ", \(.command)" else "" end)"' "$SETTINGS_FILE" >> "$KEYBINDS_CONF"

    # 5. Regenerate monitors.conf
    echo "Regenerating monitors.conf..."
    cp "$TMPL_DIR/monitors.conf.template" "$MONITORS_CONF"
    MONITOR_COUNT=$(jq '.monitors | length' "$SETTINGS_FILE" 2>/dev/null)
    if [[ "$MONITOR_COUNT" -gt 0 ]]; then
        jq -r '.monitors[]? | "monitor = \(.name), \(.resW)x\(.resH)@\(.rate), \(.x)x\(.y), \(.scale)\(if .transform and .transform != 0 then ", transform, \(.transform)" else "" end)"' "$SETTINGS_FILE" >> "$MONITORS_CONF"
    else
        echo "monitor = , preferred, auto, 1" >> "$MONITORS_CONF"
    fi

    # Hash after changes
    NEW_NONMON_HASH=$(md5sum "$SETTINGS_CONF" "$KEYBINDS_CONF" "$AUTOSTART_CONF" "$ENV_CONF" 2>/dev/null | md5sum)
    NEW_MON_HASH=$(md5sum "$MONITORS_CONF" 2>/dev/null | md5sum)

    if [ "$OLD_MON_HASH" != "$NEW_MON_HASH" ]; then
        # Monitor layout actually changed — full reload needed
        echo "Monitor config changed, reloading Hyprland..."
        hyprctl reload
    elif [ "$OLD_NONMON_HASH" != "$NEW_NONMON_HASH" ]; then
        # Non-monitor settings changed (keybinds, autostart, input, env) — reload safe, no display flicker
        echo "Non-monitor config changed, reloading Hyprland..."
        hyprctl reload
    else
        # Nothing that affects Hyprland changed (e.g. uiScale, weatherApiKey) — skip reload entirely
        echo "No Hyprland config changes detected, skipping reload."
    fi
}

# If called with --compile, execute once and exit (used by install.sh)
if [[ "$1" == "--compile" ]]; then
    compile_settings
    exit 0
fi

echo "Started watching settings directories for changes..."

inotifywait -m -q -e close_write,moved_to --format '%w%f' "$(dirname "$SETTINGS_FILE")" "$(dirname "$ENV_FILE")" | while read -r filepath; do

    # ---------------------------------------------------------
    # SETTINGS JSON TRIGGER
    # ---------------------------------------------------------
    if [[ "$filepath" == "$SETTINGS_FILE" ]]; then
        compile_settings
    fi

    # ---------------------------------------------------------
    # .ENV WEATHER TRIGGER
    # ---------------------------------------------------------
    if [[ "$filepath" == "$ENV_FILE" ]]; then
        echo ".env updated! Forcing weather cache refresh..."
        if [ -x "$WEATHER_SCRIPT" ]; then
            "$WEATHER_SCRIPT" --getdata &
        else
            bash "$WEATHER_SCRIPT" --getdata &
        fi
    fi
done
