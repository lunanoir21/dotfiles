#!/usr/bin/env bash
# WindowRegistry.js'deki kayıtlı popup'ları numaralandırılmış menüden açar.
# Kullanım: ./open_popup.sh

SHELL_QML="$HOME/.config/hypr/scripts/quickshell/Main.qml"

# name:comp:açıklama  (sıra WindowRegistry.js'deki sırayla aynı)
POPUPS=(
    "sidebarcenter:sidebar-center/SidebarCenter.qml:Sidebar Center (üzerinde çalıştığımız panel)"
    "applauncher:applauncher/appLauncher.qml:Uygulama başlatıcı"
    "clipboard:clipboard/ClipboardManager.qml:Pano yöneticisi"
    "processes:processes/ProcessMonitor.qml:Süreç monitörü"
    "mixer:mixer/VolumeMixer.qml:Ses karıştırıcı (uygulama başına ses)"
    "workspaces:workspaces/WorkspaceOverview.qml:Çalışma alanı önizleme"
    "wallpaper:wallpaper/WallpaperPicker.qml:Duvar kağıdı seçici"
    "settings:settings/SettingsWindow.qml:Ayarlar penceresi"
)

ipc() {
    qs -p "$SHELL_QML" ipc call main handleCommand "$@" >/dev/null 2>&1
}

if ! pgrep -x quickshell >/dev/null 2>&1; then
    echo "Uyarı: quickshell çalışmıyor gibi görünüyor. exec-once ile başlatıldığından emin ol." >&2
fi

while true; do
    echo
    echo "==== Popup Listesi ===="
    for i in "${!POPUPS[@]}"; do
        IFS=":" read -r name comp desc <<< "${POPUPS[$i]}"
        printf "%2d) %-14s %s\n" "$((i+1))" "$name" "$desc"
    done
    echo " 0) Kapat (hidden)"
    echo " q) Çıkış"
    echo "========================"
    read -rp "Seçim: " choice

    case "$choice" in
        q|Q) break ;;
        0) ipc close; echo "-> kapatıldı" ;;
        ''|*[!0-9]*) echo "Geçersiz giriş." ;;
        *)
            idx=$((choice-1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#POPUPS[@]}" ]; then
                IFS=":" read -r name comp desc <<< "${POPUPS[$idx]}"
                ipc open "$name" ""
                echo "-> açıldı: $name ($comp)"
            else
                echo "Geçersiz numara."
            fi
            ;;
    esac
done
