#!/usr/bin/env bash
set -euo pipefail
chmod +x "$HOME"/.local/bin/* 2>/dev/null || true
have(){ command -v "$1" >/dev/null 2>&1; }
have fc-cache && fc-cache -f >/dev/null 2>&1 || true
have hyprctl  && hyprctl reload >/dev/null 2>&1 || true
# have quickshell && { pkill -x quickshell || true; hyprctl dispatch exec quickshell; }
# chsh -s /usr/bin/zsh
exit 0