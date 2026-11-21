-- =============================================================================
-- ГОРЯЧИЕ КЛАВИШИ (Hyprland 0.56 Lua)
-- =============================================================================
-- Документация: https://wiki.hypr.land/Configuring/Binds/

local mainMod = "SUPER"

-- Порог, после которого движение мыши считается перетаскиванием, а не кликом.
-- Если блок binds у тебя уже есть в другом файле, перенеси drag_threshold туда.
hl.config({
    binds = {
        drag_threshold = 10,
    },
})

-- ----------------------------------------------------------------------------
-- ЗАПУСК ПРИЛОЖЕНИЙ И ОСНОВНЫЕ ДЕЙСТВИЯ
-- ----------------------------------------------------------------------------
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("qs -c bar ipc call topbar toggleTheme"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("qs -c bar ipc call topbar toggleLauncher"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("qs -c generalmenu ipc call panel toggle"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs -c bar ipc call topbar toggleClipboard"))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("qs -c bar ipc call topbar toggleSettings"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(vpn))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind("F10", hl.dsp.exec_cmd("qs -c bar ipc call topbar toggleScreenshot"))

-- ----------------------------------------------------------------------------
-- ЗВУК
-- ----------------------------------------------------------------------------
hl.bind("F2", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("F3", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"))

hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

-- ----------------------------------------------------------------------------
-- ЯРКОСТЬ
-- ----------------------------------------------------------------------------
hl.bind("F5", hl.dsp.exec_cmd("brightnessctl set 5%-"))
hl.bind("F6", hl.dsp.exec_cmd("brightnessctl set +5%"))

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))

-- ----------------------------------------------------------------------------
-- УПРАВЛЕНИЕ ПЛЕЕРОМ (locked — работает и при блокировке)
-- ----------------------------------------------------------------------------
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- ----------------------------------------------------------------------------
-- УПРАВЛЕНИЕ ФОКУСОМ
-- ----------------------------------------------------------------------------
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- ----------------------------------------------------------------------------
-- РАБОЧИЕ СТОЛЫ (1-10)
-- ----------------------------------------------------------------------------
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Прокрутка рабочих столов колёсиком
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- ----------------------------------------------------------------------------
-- SCRATCHPAD (special workspace)
-- ----------------------------------------------------------------------------
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- ----------------------------------------------------------------------------
-- ПЛАВАЮЩИЕ ОКНА
-- ----------------------------------------------------------------------------
-- SUPER + F: тайл <-> плавающее по центру (60% экрана)
hl.bind(mainMod .. " + F", function()
    local win = hl.get_active_window()
    if not win then return end

    if win.floating then
        hl.dispatch(hl.dsp.window.float({ action = "disable" }))
    else
        local mon = hl.get_active_monitor()
        hl.dispatch(hl.dsp.window.float({ action = "enable" }))
        hl.dispatch(hl.dsp.window.resize({
            x = math.floor(mon.width * 0.45),
            y = math.floor(mon.height * 0.45),
            relative = false,
        }))
        hl.dispatch(hl.dsp.window.center())
    end
end)

-- SUPER + ЛКМ (перетаскивание): двигать окно. Простой клик ничего не делает.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, drag = true })
-- SUPER + ПКМ: менять размер
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Ресайз с клавиатуры (для плавающих окон)
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true })