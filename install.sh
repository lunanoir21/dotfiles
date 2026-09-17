#!/usr/bin/env bash
# Bu dotfiles reposunu sıfırdan bir makinede kurar.
#
# Yapar:
#   1. İşletim sistemini/paket yöneticisini tespit eder (pacman/apt/dnf/zypper)
#   2. packages/<distro>.txt içindeki paketleri kurar (Arch dışında best-effort —
#      bkz. packages/debian.txt ve packages/fedora.txt başındaki uyarılar)
#   3. hypr/, kitty/, fish/ klasörlerini ~/.config/{hypr,kitty,fish} olarak
#      symlink'ler (var olan bir config varsa üzerine yazmadan önce yedekler)
#   4. hypr/install.sh'ı çalıştırıp donanım tespiti + config üretimini yapar
#
# Kullanım: ./install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 1. Dağıtım / paket yöneticisi tespiti
# ---------------------------------------------------------------------------
PKG_MANAGER=""
if command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
elif command -v apt >/dev/null 2>&1; then
    PKG_MANAGER="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
elif command -v zypper >/dev/null 2>&1; then
    PKG_MANAGER="zypper"
fi

echo "==> Tespit edilen paket yöneticisi: ${PKG_MANAGER:-bilinmiyor}"

case "$PKG_MANAGER" in
    pacman)
        echo "==> Arch tabanlı sistem. packages/arch.txt kuruluyor..."
        sudo pacman -S --needed - < "$REPO_DIR/packages/arch.txt"
        if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
            echo "UYARI: yay/paru bulunamadı. packages/arch.txt içindeki '-git' paketleri"
            echo "       (grimblast-git, swayosd-git) ve quickshell/localsend AUR'da —"
            echo "       bir AUR helper kurup elle ekle."
        fi
        ;;
    apt)
        echo "==> Debian/Ubuntu tespit edildi. packages/debian.txt (best-effort) kuruluyor..."
        echo "    NOT: Hyprland/quickshell/awww/cava/cliphist/grimblast/satty/swayosd"
        echo "         bu listede YOK — dosyanın başındaki uyarıya bak, kaynaktan"
        echo "         derlemen ya da COPR/PPA benzeri bir kaynak bulman gerekecek."
        sudo apt update
        sudo apt install -y $(grep -v '^#' "$REPO_DIR/packages/debian.txt")
        ;;
    dnf)
        echo "==> Fedora tespit edildi. packages/fedora.txt (best-effort) kuruluyor..."
        echo "    NOT: Hyprland ekosisteminin çoğu resmi repoda değil — COPR gerekebilir,"
        echo "         dosyanın başındaki uyarıya bak."
        sudo dnf install -y $(grep -v '^#' "$REPO_DIR/packages/fedora.txt")
        ;;
    zypper)
        echo "UYARI: openSUSE için küratе edilmiş bir paket listesi henüz yok."
        echo "       packages/arch.txt'teki isimlere bakıp Software Center'dan elle kur."
        ;;
    *)
        echo "UYARI: Tanınan bir paket yöneticisi bulunamadı (pacman/apt/dnf/zypper)."
        echo "       Paketleri elle kurman gerekecek — bkz. packages/arch.txt (referans liste)."
        ;;
esac

# ---------------------------------------------------------------------------
# 2. Symlink kurulumu — var olan config'i ezmeden yedekle
# ---------------------------------------------------------------------------
link_config() {
    local src="$1" dest="$2"
    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
        echo "==> $dest zaten $src'e bağlı, atlandı."
        return
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        local backup="${dest}.bak-$(date +%Y%m%d%H%M%S)"
        echo "==> Var olan $dest -> $backup olarak yedekleniyor."
        mv "$dest" "$backup"
    fi
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    echo "==> $dest -> $src symlink'lendi."
}

link_config "$REPO_DIR/hypr" "$HOME/.config/hypr"
link_config "$REPO_DIR/kitty" "$HOME/.config/kitty"
link_config "$REPO_DIR/fish" "$HOME/.config/fish"

# ---------------------------------------------------------------------------
# 3. Donanım tespiti + Hyprland config üretimi (hypr/install.sh'a devret)
# ---------------------------------------------------------------------------
echo "==> hypr/install.sh çalıştırılıyor (donanım tespiti + config üretimi)..."
bash "$REPO_DIR/hypr/install.sh" || echo "    hypr/install.sh başarısız oldu, elle çalıştır: $REPO_DIR/hypr/install.sh"

echo "==> Kurulum tamam. Hyprland oturumunu başlat ya da 'hyprctl reload' çalıştır."
