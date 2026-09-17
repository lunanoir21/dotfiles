#!/usr/bin/env bash

# Source and initialize quickshell dynamic caching
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "lock"

# Gerçek kilit ekranı artık ~/.config/hypr/hypridle/lock.sh üzerinden seçiliyor
# (bkz. SUPER+SHIFT+L picker'ı, ~/.config/hypr/hypridle/active-lock).
exec bash "$HOME/.config/hypr/hypridle/lock.sh"
