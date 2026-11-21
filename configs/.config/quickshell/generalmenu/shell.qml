import QtQuick
import Quickshell
import Quickshell.Io

import "." as Local          // Local.PanelWindow: наш файл, а не тип Quickshell

ShellRoot {
    id: root

    SettingsManager { id: settingsMgr }

    ThemeManager {
        id: themeManager
        settingsManager: settingsMgr
    }

    SoundManager {
        id: soundManager
        settingsManager: settingsMgr
    }

    Local.PanelWindow {
        id: panel
        theme: themeManager.theme
        themeManager: themeManager
        soundPlayer: soundManager
        settingsManager: settingsMgr
    }

    IpcHandler {
        target: "panel"

        function toggle(): void {
            if (panel.opened)
                panel.close()
            else
                panel.open()
        }
        function open(): void { panel.open() }
        function close(): void { panel.close() }
    }
}