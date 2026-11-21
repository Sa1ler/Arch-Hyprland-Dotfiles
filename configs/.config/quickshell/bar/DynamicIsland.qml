import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "widgets"

PanelWindow {
    id: root

    property var theme: null
    property var themeManager: null
    property var soundManager: null
    property var settingsManager: null
    property bool isHovered: false

    // Пока курсор над островом, таймеры автозакрытия volume/brightness стоят.
    // Когда курсор уходит — таймер запускается заново.
    onIsHoveredChanged: {
        if (root.currentMode === root.modeVolume) {
            if (isHovered) volumeHideTimer.stop()
            else volumeHideTimer.restart()
        } else if (root.currentMode === root.modeBrightness) {
            if (isHovered) brightnessHideTimer.stop()
            else brightnessHideTimer.restart()
        }
    }

    // === Алиасы настроек острова из SettingsManager ===
    readonly property bool islandEnabled: settingsManager ? settingsManager.island.enabled : true
    readonly property string islandShape: settingsManager ? settingsManager.island.shape : "capsule"
    readonly property int islandLength: settingsManager ? settingsManager.island.length : 220
    readonly property int islandHeight: settingsManager ? settingsManager.island.height : 34
    readonly property int islandMargin: settingsManager ? settingsManager.island.margin : 4
    readonly property bool indWorkspaces: settingsManager && settingsManager.island.indicators ? settingsManager.island.indicators.workspaces : true
    readonly property bool indNetwork: settingsManager && settingsManager.island.indicators ? settingsManager.island.indicators.network : true
    readonly property bool indBattery: settingsManager && settingsManager.island.indicators ? settingsManager.island.indicators.battery : true
    readonly property bool indClock: settingsManager && settingsManager.island.indicators ? settingsManager.island.indicators.clock : true

    readonly property bool isNotch: islandShape === "notch"
    readonly property bool islandShown: islandEnabled || root.anyModeActive

    readonly property int topMargin: root.isNotch ? 0 : islandMargin
    readonly property int capsuleHeight: islandHeight
    readonly property int capsulePadding: 18
    readonly property int earRadius: 12

    readonly property int modeNone: 0
    readonly property int modeTheme: 1
    readonly property int modeLauncher: 2
    readonly property int modeScreenshot: 3
    readonly property int modeVolume: 4
    readonly property int modeBrightness: 5
    readonly property int modeSettings: 6

    property int currentMode: modeNone
    readonly property bool anyModeActive: currentMode !== modeNone

    readonly property int themeWidth: 580
    readonly property int themeHeight: 280
    readonly property int launcherWidth: 400
    readonly property int launcherHeight: 340
    readonly property int screenshotWidth: 250
    readonly property int screenshotHeight: 76
    readonly property int volumeWidth: 260
    readonly property int volumeHeight: 52
    readonly property int brightnessWidth: 260
    readonly property int brightnessHeight: 52
    readonly property int settingsWidth: 420
    readonly property int settingsHeight: 570

    readonly property int capsuleBaseWidth: islandLength
    readonly property int hoverExpand: 6

    readonly property int currentWidth: {
        if (root.currentMode === root.modeLauncher) return root.launcherWidth;
        if (root.currentMode === root.modeScreenshot) return root.screenshotWidth;
        if (root.currentMode === root.modeTheme) return root.themeWidth;
        if (root.currentMode === root.modeVolume) return root.volumeWidth;
        if (root.currentMode === root.modeBrightness) return root.brightnessWidth;
        if (root.currentMode === root.modeSettings) return root.settingsWidth;

        var base = root.capsuleBaseWidth;
        if (root.currentMode === root.modeNone && root.isHovered) {
            base += root.hoverExpand;
        }
        return base;
    }

    readonly property int currentHeight: {
        if (root.currentMode === root.modeLauncher) return root.launcherHeight;
        if (root.currentMode === root.modeScreenshot) return root.screenshotHeight;
        if (root.currentMode === root.modeTheme) return root.themeHeight;
        if (root.currentMode === root.modeVolume) return root.volumeHeight;
        if (root.currentMode === root.modeBrightness) return root.brightnessHeight;
        if (root.currentMode === root.modeSettings) return root.settingsHeight;

        var base = root.capsuleHeight;
        if (root.currentMode === root.modeNone && root.isHovered) {
            base += root.hoverExpand;
        }
        return base;
    }

    readonly property int currentRadius: {
        if (root.currentMode === root.modeSettings) return 26;
        if (root.currentMode === root.modeVolume || root.currentMode === root.modeBrightness) return 18;
        if (root.anyModeActive) return 24;
        return root.isNotch ? Math.min(14, root.currentHeight / 2) : root.currentHeight / 2;
    }

    property real notchRadius: root.currentRadius
    Behavior on notchRadius { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }

    property real animatedWidth: root.currentWidth
    property real animatedHeight: root.currentHeight

    Behavior on animatedWidth {
        NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
    }
    Behavior on animatedHeight {
        NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
    }

    property real hoverLift: root.isHovered && !root.anyModeActive ? 3 : 0
    Behavior on hoverLift { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }

    readonly property color borderColor:
        root.theme && root.theme.colors ? (root.theme.colors.border || "#2A2A2A") : "#2A2A2A"

    function setMode(mode) {
        currentMode = (currentMode === mode) ? modeNone : mode
    }

    function closeMode(mode) {
        if (currentMode === mode) currentMode = modeNone
    }

    VolumeManager {
        id: volumeManager
        onAdjusted: {
            root.currentMode = root.modeVolume
            if (root.isHovered) volumeHideTimer.stop()
            else volumeHideTimer.restart()
        }
    }

    Timer {
        id: volumeHideTimer
        interval: 1800
        onTriggered: {
            if (root.currentMode === root.modeVolume) {
                root.currentMode = root.modeNone
            }
        }
    }

    BrightnessManager {
        id: brightnessManager
        onAdjusted: {
            root.currentMode = root.modeBrightness
            if (root.isHovered) brightnessHideTimer.stop()
            else brightnessHideTimer.restart()
        }
    }

    Timer {
        id: brightnessHideTimer
        interval: 1800
        onTriggered: {
            if (root.currentMode === root.modeBrightness) {
                root.currentMode = root.modeNone
            }
        }
    }

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: root.topMargin + Math.max(
        root.themeHeight,
        root.launcherHeight,
        root.screenshotHeight,
        root.settingsHeight,
        root.capsuleHeight
    ) + 20

    exclusiveZone: root.topMargin + root.capsuleHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.anyModeActive && root.currentMode !== root.modeVolume && root.currentMode !== root.modeBrightness
                                 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        focus: root.anyModeActive && root.currentMode !== root.modeVolume && root.currentMode !== root.modeBrightness

        Keys.onEscapePressed: function(event) {
            if (root.anyModeActive && root.currentMode !== root.modeVolume && root.currentMode !== root.modeBrightness) {
                root.currentMode = root.modeNone
            }
            event.accepted = true
        }
    }

    // ===== КОНТЕЙНЕР =====
    Item {
        id: notchContainer
        anchors.top: parent.top
        anchors.topMargin: root.topMargin
        anchors.horizontalCenter: parent.horizontalCenter

        width: root.animatedWidth + (root.isNotch ? root.earRadius * 2 : 0)
        height: root.animatedHeight + root.hoverLift

        opacity: root.islandShown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
        Behavior on anchors.topMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        // HoverHandler не конкурирует с дочерними MouseArea (mute, slider и т.д.),
        // поэтому isHovered не сбрасывается, когда курсор заходит на элементы попапа
        HoverHandler {
            onHoveredChanged: root.isHovered = hovered
        }

        // ===== ФОРМА ВЫРЕЗА =====
        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            visible: root.isNotch

            ShapePath {
                id: notchPath

                readonly property real w: notchContainer.width
                readonly property real h: notchContainer.height
                readonly property real e: root.earRadius
                readonly property real r: Math.max(0, Math.min(root.notchRadius, h - e, (w - 2 * e) / 2))

                fillColor: "#000000"
                strokeColor: root.borderColor
                strokeWidth: 1

                startX: 0
                startY: 0

                PathArc {
                    x: notchPath.e; y: notchPath.e
                    radiusX: notchPath.e; radiusY: notchPath.e
                    direction: PathArc.Clockwise
                }
                PathLine { x: notchPath.e; y: notchPath.h - notchPath.r }
                PathArc {
                    x: notchPath.e + notchPath.r; y: notchPath.h
                    radiusX: notchPath.r; radiusY: notchPath.r
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: notchPath.w - notchPath.e - notchPath.r; y: notchPath.h }
                PathArc {
                    x: notchPath.w - notchPath.e; y: notchPath.h - notchPath.r
                    radiusX: notchPath.r; radiusY: notchPath.r
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: notchPath.w - notchPath.e; y: notchPath.e }
                PathArc {
                    x: notchPath.w; y: 0
                    radiusX: notchPath.e; radiusY: notchPath.e
                    direction: PathArc.Clockwise
                }
                PathLine { x: notchPath.w; y: -4 }
                PathLine { x: 0; y: -4 }
                PathLine { x: 0; y: 0 }
            }
        }

        // ===== КАПСУЛА =====
        Rectangle {
            id: capsuleBg
            x: root.isNotch ? root.earRadius : 0
            y: 0
            width: root.animatedWidth
            height: root.animatedHeight + root.hoverLift
            radius: root.currentRadius

            color: "#000000"
            border.width: 1
            border.color: root.borderColor
            clip: true

            visible: !root.isNotch

            Behavior on radius { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
        }

        // ===== КОНТЕНТ =====
        Item {
            id: contentItem
            x: root.isNotch ? root.earRadius : 0
            y: 0
            width: root.animatedWidth
            height: root.animatedHeight + root.hoverLift
            clip: true

            Item {
                id: baseContent
                anchors.fill: parent
                anchors.margins: root.capsulePadding

                visible: root.currentMode === root.modeNone
                opacity: root.currentMode === root.modeNone ? 1 : 0
                scale: root.currentMode === root.modeNone ? 1 : 0.95

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                Row {
                    anchors.centerIn: parent
                    spacing: 20

                    Workspaces {
                        visible: indWorkspaces
                        anchors.verticalCenter: parent.verticalCenter
                        theme: root.theme
                        soundManager: root.soundManager
                    }

                    Clock {
                        visible: indClock
                        anchors.verticalCenter: parent.verticalCenter
                        theme: root.theme
                        soundManager: root.soundManager
                    }

                    WifiIndicator {
                        visible: indNetwork
                        anchors.verticalCenter: parent.verticalCenter
                        theme: root.theme
                    }

                    BatteryIndicator {
                        visible: indBattery
                        anchors.verticalCenter: parent.verticalCenter
                        theme: root.theme
                    }
                }
            }

            ThemePicker {
                id: themePicker
                anchors.fill: parent
                anchors.margins: 12
                theme: root.theme
                themeManager: root.themeManager
                soundManager: root.soundManager
                active: root.currentMode === root.modeTheme
                enabled: root.currentMode === root.modeTheme
                onClose: { root.currentMode = root.modeNone }
                visible: root.currentMode === root.modeTheme
                opacity: root.currentMode === root.modeTheme ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            }

            Launcher {
                id: launcherWidget
                anchors.fill: parent
                anchors.margins: 12
                theme: root.theme
                soundManager: root.soundManager
                settingsManager: root.settingsManager
                active: root.currentMode === root.modeLauncher
                enabled: root.currentMode === root.modeLauncher
                onClose: { root.currentMode = root.modeNone }
                visible: root.currentMode === root.modeLauncher
                opacity: root.currentMode === root.modeLauncher ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            }

            ScreenshotMenu {
                id: screenshotMenu
                anchors.fill: parent
                theme: root.theme
                soundManager: root.soundManager
                active: root.currentMode === root.modeScreenshot
                enabled: root.currentMode === root.modeScreenshot
                onClose: { root.currentMode = root.modeNone }
                visible: root.currentMode === root.modeScreenshot
                opacity: root.currentMode === root.modeScreenshot ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            }

            VolumePopup {
                id: volumePopup
                anchors.fill: parent
                theme: root.theme
                manager: volumeManager
                active: root.currentMode === root.modeVolume
                visible: root.currentMode === root.modeVolume
                opacity: root.currentMode === root.modeVolume ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            }

            BrightnessPopup {
                id: brightnessPopup
                anchors.fill: parent
                theme: root.theme
                manager: brightnessManager
                active: root.currentMode === root.modeBrightness
                visible: root.currentMode === root.modeBrightness
                opacity: root.currentMode === root.modeBrightness ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            }

            SettingsPopup {
                id: settingsPopup
                anchors.fill: parent
                theme: root.theme
                soundManager: root.soundManager
                settingsManager: root.settingsManager
                active: root.currentMode === root.modeSettings
                enabled: root.currentMode === root.modeSettings
                onClose: { root.currentMode = root.modeNone }
                visible: root.currentMode === root.modeSettings
                opacity: root.currentMode === root.modeSettings ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            }
        }
    }

    mask: Region {
        item: root.islandShown ? notchContainer : null
    }
}
