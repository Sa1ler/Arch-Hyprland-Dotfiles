#!/usr/bin/env bash
# bootstrap: bash <(curl -fsSL https://raw.githubusercontent.com/USER/rice/main/install.sh)
set -Eeuo pipefail

RICE_REPO="${RICE_REPO:-Sa1ler/Arch-Hyprland-Dotfiles}"
RICE_BRANCH="${RICE_BRANCH:-main}"
RICE_DIR="${RICE_DIR:-$HOME/.local/share/rice}"
URL="https://github.com/$RICE_REPO.git"

say(){ printf '\e[1;36m==>\e[0m %s\n' "$*"; }
die(){ printf '\e[1;31m✗\e[0m %s\n' "$*" >&2; exit 1; }

[[ -f /etc/arch-release ]] || die "это не Arch Linux"
(( EUID != 0 ))            || die "запускай от обычного пользователя, не от root"
[[ -t 0 ]]                 || die "нужен интерактивный stdin. Запусти: bash <(curl -fsSL URL)"
curl -fsSI https://archlinux.org >/dev/null || die "нет сети"

say "Система + базовые зависимости"
sudo -v
sudo pacman -Syu --needed --noconfirm base-devel git rsync curl

if [[ -d "$RICE_DIR/.git" ]]; then
  say "Репозиторий уже есть — обновляю"
  git -C "$RICE_DIR" pull --ff-only || true
else
  say "Клонирую $URL"
  mkdir -p "$(dirname "$RICE_DIR")"
  git clone --branch "$RICE_BRANCH" "$URL" "$RICE_DIR"
fi

mkdir -p "$HOME/.local/bin"
chmod +x "$RICE_DIR/bin/rice"
ln -sfn "$RICE_DIR/bin/rice" "$HOME/.local/bin/rice"

say "Разворачиваю систему"
bash "$RICE_DIR/bin/rice" deploy

say "Готово. Дальше:"
echo "  • auth для push: gh auth login   либо   git -C $RICE_DIR remote set-url origin git@github.com:$RICE_REPO.git"
echo "  • синхронизация: rice sync"