import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "widgets"

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

    IpcHandler {
        target: "topbar"

        function toggleTheme()          { island.setMode(island.modeTheme) }
        function toggleLauncher()       { island.setMode(island.modeLauncher) }
        function toggleScreenshot()     { island.setMode(island.modeScreenshot) }
        function toggleSettings()  { island.setMode(island.modeSettings) }

        function closeTheme()          { island.closeMode(island.modeTheme) }
        function closeLauncher()       { island.closeMode(island.modeLauncher) }
        function closeScreenshot()     { island.closeMode(island.modeScreenshot) }
        function closeSettings()   { island.closeMode(island.modeSettings) }
    }

    DynamicIsland {
        id: island
        visible: true

        theme: themeManager.theme
        themeManager: themeManager
        soundManager: soundManager
        settingsManager: settingsMgr
    }
}