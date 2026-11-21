#!/usr/bin/env bash
floating=$(hyprctl activewindow -j | jq -r '.floating')

if [ "$floating" = "true" ]; then
    # вернуть в тайлинг
    hyprctl dispatch togglefloating
else
    # в плавающий режим, уменьшить и в центр
    hyprctl --batch "dispatch togglefloating ; dispatch resizeactive exact 60% 60% ; dispatch centerwindow"
fi
