#!/usr/bin/env bash
# Sıfırdan klonlanan bir makinede bu rice'ı çalışır hâle getiren tek giriş noktası.
#
# settings_watcher.sh ve (artık kaldırılmış) update_notifier.sh bu dosyaya "install.sh
# tarafından çağrılıyor" diye referans veriyordu ama dosyanın kendisi hiç yoktu — bu
# script o boşluğu dolduruyor. Yaptığı tek şey: donanıma özgü env değişkenlerini
# (GPU sürücüsü) tespit edip settings.json'daki hardwareEnvs anahtarına yazmak, sonra
# settings_watcher.sh'ı --compile ile bir kez çalıştırıp config/*.conf dosyalarını
# üretmek. Idempotent'tir; zaten dolu bir hardwareEnvs'in üzerine --force verilmeden
# yazmaz.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="$REPO_DIR/settings.json"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

echo "==> $REPO_DIR için kurulum kontrolü"

# ---------------------------------------------------------------------------
# 1. Gerekli araçların varlığını kontrol et (kurmuyor, sadece uyarıyor —
#    paket yönetimi restore.sh / related-configs/packages-pacman.txt'nin işi)
# ---------------------------------------------------------------------------
missing=()
for bin in jq hyprctl xdg-user-dir; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "UYARI: eksik komutlar bulundu: ${missing[*]}"
    echo "       Bunlar olmadan settings_watcher.sh çalışmaz. Devam ediliyor,"
    echo "       ama önce bunları kurman gerekecek."
fi

# ---------------------------------------------------------------------------
# 2. settings.json yoksa boş bir iskelet oluştur (settings_watcher.sh'ın
#    kendi varsayılanıyla aynı davranış)
# ---------------------------------------------------------------------------
[ ! -f "$SETTINGS_FILE" ] && echo "{}" > "$SETTINGS_FILE"

# ---------------------------------------------------------------------------
# 3. Donanım env'lerini tespit et (yalnızca hardwareEnvs boşsa ya da --force
#    verildiyse — elle ayarlanmış bir değeri sessizce ezme)
# ---------------------------------------------------------------------------
EXISTING_HW=$(jq -r '.hardwareEnvs // [] | length' "$SETTINGS_FILE")

if [ "$EXISTING_HW" -gt 0 ] && [ "$FORCE" -eq 0 ]; then
    echo "==> hardwareEnvs zaten dolu ($EXISTING_HW satır), donanım tespiti atlandı."
    echo "    Yeniden tespit etmek için: $0 --force"
else
    echo "==> GPU tespit ediliyor..."
    GPU_INFO=""
    command -v lspci >/dev/null 2>&1 && GPU_INFO=$(lspci -nnk 2>/dev/null | grep -A2 -Ei 'VGA|3D controller' || true)

    HW_LINES=()
    if echo "$GPU_INFO" | grep -qi intel; then
        echo "    Intel GPU bulundu -> VAAPI: iHD"
        HW_LINES+=("# Intel GPU tespit edildi — VAAPI donanım hızlandırmasını iHD sürücüsüne pinle.")
        HW_LINES+=("env = LIBVA_DRIVER_NAME,iHD")
        HW_LINES+=("env = MOZ_ENABLE_WAYLAND,1")
    fi
    if echo "$GPU_INFO" | grep -qi amd; then
        echo "    AMD GPU bulundu -> VAAPI: radeonsi"
        HW_LINES+=("# AMD GPU tespit edildi — VAAPI donanım hızlandırmasını radeonsi sürücüsüne pinle.")
        HW_LINES+=("env = LIBVA_DRIVER_NAME,radeonsi")
        HW_LINES+=("env = MOZ_ENABLE_WAYLAND,1")
    fi
    if echo "$GPU_INFO" | grep -qi nvidia; then
        echo "    NVIDIA GPU bulundu -> Wayland ipuçları ekleniyor"
        HW_LINES+=("# NVIDIA GPU tespit edildi — Wayland/GBM ipuçları.")
        HW_LINES+=("env = GBM_BACKEND,nvidia-drm")
        HW_LINES+=("env = __GLX_VENDOR_LIBRARY_NAME,nvidia")
        HW_LINES+=("env = LIBVA_DRIVER_NAME,nvidia")
    fi

    if [ "${#HW_LINES[@]}" -eq 0 ]; then
        echo "    GPU tespit edilemedi (lspci yok ya da tanınmayan donanım) — hardwareEnvs boş bırakıldı."
    fi

    HW_JSON=$(printf '%s\n' "${HW_LINES[@]:-}" | jq -R . | jq -s 'map(select(length > 0))')
    jq --argjson hw "$HW_JSON" '.hardwareEnvs = $hw' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
    mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
fi

# ---------------------------------------------------------------------------
# 4. Tüm config/*.conf dosyalarını settings.json'dan üret
# ---------------------------------------------------------------------------
echo "==> Konfigürasyonlar üretiliyor (settings_watcher.sh --compile)..."
bash "$REPO_DIR/scripts/settings_watcher.sh" --compile

echo "==> Kurulum tamam. Hyprland'ı başlat ya da 'hyprctl reload' çalıştır."
echo "    İlk açılışta Ayarlar > Güç & pil'den cihaz türünü (laptop/masaüstü) seç."
