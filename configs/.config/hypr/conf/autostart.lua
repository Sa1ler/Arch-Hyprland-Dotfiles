-- =============================================================================
-- АВТОЗАПУСК
-- =============================================================================
-- Программы, запускающиеся при старте Hyprland
-- (демоны уведомлений, статус-бары, обои и т.д.)

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/quickshell/scripts/start.sh")
    hl.exec_cmd("swaybg -i /home/$USER/.config/hypr/walls/anime-style-cozy-home-interior-with-furnishings.jpg")
    hl.exec_cmd("wl-gammarelay-rs")
end)
