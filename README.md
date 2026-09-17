# dotfiles

Hyprland + Quickshell tabanlı bir masaüstü kurulumu (rice): özel bir Dynamic
Island overlay'i, tamamen QML'de yazılmış bir ayar uygulaması, sabit bir renk
teması ve `settings.json`'dan üretilen konfigürasyon dosyaları.

## Yapı

Her uygulamanın config'i kendi klasöründe, `~/.config/<app>` ile aynı isimde:

```
dotfiles/
├── hypr/     -> ~/.config/hypr
├── kitty/    -> ~/.config/kitty
├── fish/     -> ~/.config/fish
├── packages/ -> dağıtıma göre kürate edilmiş paket listeleri
└── install.sh
```

`install.sh` her klasörü ilgili `~/.config/<app>` yoluna symlink'ler — var olan
bir config varsa üzerine yazmadan önce `.bak-<tarih>` olarak yedekler.

## Kurulum

```bash
git clone --recurse-submodules <bu repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh`:
1. Paket yöneticini tespit eder (pacman/apt/dnf/zypper) ve `packages/<dağıtım>.txt`'i kurar.
   Arch dışındaki dağıtımlarda bu **best-effort** — Hyprland ekosistemi (quickshell,
   awww, cava, cliphist, grimblast, satty, swayosd) çoğu dağıtımın resmi
   deposunda yok; ilgili `packages/*.txt` dosyasının başındaki notlara bak.
2. `hypr/`, `kitty/`, `fish/`'i `~/.config/`'a symlink'ler.
3. `hypr/install.sh`'ı çalıştırıp donanıma özgü env değişkenlerini (GPU
   sürücüsü) tespit eder ve `hypr/config/*.conf` dosyalarını üretir.

## İçerik

- `hypr/` — Hyprland core config, `scripts/quickshell/` (Dynamic Island,
  Quay dock, applauncher, mixer, settings uygulaması vb.), tema/shader'lar
- `hypr/scripts/quickshell/vendor/` — ayrı repo/lisansı olan git submodule'ler
  (`dynamic-island`, `quay`, `flare`)
- `kitty/`, `fish/` — terminal ve shell config'leri
- `packages/` — dağıtım başına kürate edilmiş bağımlılık listeleri

## Lisans

MIT — bkz. [`LICENSE`](LICENSE). `hypr/scripts/quickshell/vendor/*` kendi ayrı
lisanslarına sahip.
