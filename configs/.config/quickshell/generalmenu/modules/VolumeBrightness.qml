import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var theme: null
    property var soundPlayer: null

    property real brightness: 0.5
    property real volume: 0.5
    property bool muted: false

    readonly property int blockHeight: 110
    readonly property int sliderHeight: 8
    readonly property int handleSize: 16

    readonly property color surfaceColor: theme && theme.colors && theme.colors.surface
                                          ? theme.colors.surface : "#1A1F26"
    readonly property color borderColor: theme && theme.colors && theme.colors.border
                                         ? theme.colors.border : "#2A323D"
    readonly property color trackColor: theme && theme.colors && theme.colors.surfaceSelected
                                        ? theme.colors.surfaceSelected : "#2C3A50"
    readonly property color hoverColor: theme && theme.colors && theme.colors.surfaceHover
                                        ? theme.colors.surfaceHover : "#252C36"
    readonly property color textColor: theme && theme.colors && theme.colors.textSecondary
                                       ? theme.colors.textSecondary : "#9AA9B9"
    readonly property color brightnessColor: theme && theme.colors && theme.colors.brightnessAccent
                                             ? theme.colors.brightnessAccent : "#F5C451"
    readonly property color volumeColor: theme && theme.colors && theme.colors.volumeAccent
                                        ? theme.colors.volumeAccent : "#5B8CFF"

    implicitHeight: blockHeight

    function clamp(value) {
        return Math.max(0, Math.min(1, Number(value) || 0))
    }

    function setBrightness(value) {
        root.brightness = clamp(value)
        brightnessDebounce.restart()
    }

    function setVolume(value) {
        root.volume = clamp(value)
        if (root.muted && root.volume > 0) {
            unmuteProcess.running = true
            root.muted = false
        }
        volumeDebounce.restart()
    }

    function toggleMute() {
        if (muteProcess.running)
            return

        muteProcess.command = [
            "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@",
            root.muted ? "0" : "1"
        ]
        muteProcess.running = true
        if (root.soundPlayer)
            root.soundPlayer.play("quick_click.wav")
    }

    function refreshBrightness() {
        if (!brightnessGet.running)
            brightnessGet.running = true
    }

    function refreshVolume() {
        if (!volumeGet.running)
            volumeGet.running = true
    }

    Process {
        id: brightnessGet
        command: ["brightnessctl", "-m"]

        stdout: StdioCollector {
            onStreamFinished: {
                var match = text.trim().match(/,(\d+)%/)
                if (match && !brightnessSlider.dragging)
                    root.brightness = root.clamp(parseInt(match[1], 10) / 100)
            }
        }
    }

    Process {
        id: brightnessSet
        property int pendingValue: 50
        property int inFlightValue: 50
        property int lastApplied: -1
        command: ["brightnessctl", "set", inFlightValue + "%"]

        onExited: function(exitCode) {
            if (exitCode === 0)
                lastApplied = inFlightValue
            if (lastApplied !== pendingValue)
                brightnessDebounce.restart()
        }
    }

    Process {
        id: volumeGet
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = text.trim()
                var match = output.match(/Volume:\s*([0-9.]+)/)
                if (match && !volumeSlider.dragging)
                    root.volume = root.clamp(parseFloat(match[1]))
                root.muted = /\[MUTED\]/.test(output)
            }
        }
    }

    Process {
        id: volumeSet
        property real pendingValue: 0.5
        property real inFlightValue: 0.5
        property real lastApplied: -1
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", inFlightValue.toFixed(3)]

        onExited: function(exitCode) {
            if (exitCode === 0)
                lastApplied = inFlightValue
            if (Math.abs(lastApplied - pendingValue) > 0.001)
                volumeDebounce.restart()
        }
    }

    Process {
        id: unmuteProcess
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]
        onExited: {
            root.refreshVolume()
        }
    }

    Process {
        id: muteProcess
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1"]
        onExited: {
            root.refreshVolume()
        }
    }

    Timer {
        id: brightnessDebounce
        interval: 45
        repeat: false
        onTriggered: {
            brightnessSet.pendingValue = Math.round(root.brightness * 100)
            if (!brightnessSet.running) {
                brightnessSet.inFlightValue = brightnessSet.pendingValue
                brightnessSet.running = true
            }
        }
    }

    Timer {
        id: volumeDebounce
        interval: 45
        repeat: false
        onTriggered: {
            volumeSet.pendingValue = root.volume
            if (!volumeSet.running) {
                volumeSet.inFlightValue = volumeSet.pendingValue
                volumeSet.running = true
            }
        }
    }

    Rectangle {
        id: mainBlock
        anchors.fill: parent
        radius: 16
        color: root.surfaceColor
        border.width: 1
        border.color: root.borderColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Slider {
                id: brightnessSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                icon: root.brightness > 0.5 ? "󰃠"
                      : root.brightness > 0.15 ? "󰃟" : "󰃞"
                value: root.brightness
                accentColor: root.brightnessColor
                trackColor: root.trackColor
                hoverColor: root.hoverColor
                backgroundColor: root.surfaceColor
                textColor: root.textColor
                iconClickable: false
                onChanged: function(newValue) { root.setBrightness(newValue) }
            }

            Slider {
                id: volumeSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                icon: root.muted || root.volume <= 0 ? "󰝟"
                      : root.volume < 0.5 ? "󰕿" : "󰕾"
                value: root.muted ? 0 : root.volume
                accentColor: root.muted ? "#FF453A" : root.volumeColor
                trackColor: root.trackColor
                hoverColor: root.hoverColor
                backgroundColor: root.surfaceColor
                textColor: root.textColor
                iconClickable: true
                onChanged: function(newValue) { root.setVolume(newValue) }
                onIconClicked: root.toggleMute()
            }
        }
    }

    component Slider: Item {
        id: slider

        property string icon: ""
        property real value: 0.5
        property color accentColor: "#FFB080"
        property color trackColor: "#303030"
        property color hoverColor: "#282828"
        property color backgroundColor: "#1A1F26"
        property color textColor: "#9AA9B9"
        property bool iconClickable: false
        property bool dragging: false

        signal changed(real newValue)
        signal iconClicked()

        RowLayout {
            anchors.fill: parent
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: width / 2
                color: iconMouse.containsMouse
                       ? Qt.rgba(slider.accentColor.r, slider.accentColor.g,
                                 slider.accentColor.b, 0.18)
                       : Qt.rgba(slider.accentColor.r, slider.accentColor.g,
                                 slider.accentColor.b, 0.10)
                scale: iconMouse.pressed ? 0.92
                       : (iconMouse.containsMouse && slider.iconClickable ? 1.05 : 1.0)

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }

                Text {
                    anchors.centerIn: parent
                    text: slider.icon
                    color: slider.accentColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                }

                MouseArea {
                    id: iconMouse
                    anchors.fill: parent
                    enabled: slider.iconClickable
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: slider.iconClicked()
                }
            }

            Item {
                id: trackArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    id: track
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: root.sliderHeight
                    radius: height / 2
                    color: slider.trackColor
                }

                Rectangle {
                    id: fill
                    x: track.x
                    y: track.y
                    width: Math.max(0, track.width * root.clamp(slider.value))
                    height: track.height
                    radius: height / 2
                    color: slider.accentColor
                    Behavior on width {
                        enabled: !slider.dragging
                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    id: handle
                    width: root.handleSize
                    height: root.handleSize
                    radius: width / 2
                    x: Math.max(0, Math.min(track.width - width,
                         track.width * root.clamp(slider.value) - width / 2))
                    anchors.verticalCenter: track.verticalCenter
                    color: slider.accentColor
                    border.width: 2
                    border.color: slider.backgroundColor
                    scale: sliderMouse.pressed ? 1.12
                           : sliderMouse.containsMouse ? 1.06 : 1.0
                    Behavior on x {
                        enabled: !slider.dragging
                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: parent.radius + 4
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(slider.accentColor.r, slider.accentColor.g,
                                              slider.accentColor.b, 0.28)
                        opacity: sliderMouse.containsMouse || sliderMouse.pressed ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }
                }

                MouseArea {
                    id: sliderMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(mouse) {
                        slider.dragging = true
                        slider.changed(root.clamp(mouse.x / Math.max(1, width)))
                    }
                    onPositionChanged: function(mouse) {
                        if (pressed)
                            slider.changed(root.clamp(mouse.x / Math.max(1, width)))
                    }
                    onReleased: slider.dragging = false
                    onCanceled: slider.dragging = false
                }
            }

            Text {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: Math.round((slider.value || 0) * 100) + "%"
                color: slider.textColor
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }

    Component.onCompleted: {
        refreshBrightness()
        refreshVolume()
    }

    Timer {
        interval: 8000
        repeat: true
        running: root.visible
        onTriggered: {
            root.refreshBrightness()
            root.refreshVolume()
        }
    }
}
