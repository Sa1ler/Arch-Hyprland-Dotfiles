import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var theme: null
    property var soundPlayer: null
    property var settingsManager: null

    signal dndStateChanged(bool enabled)

    property bool wifiEnabled: false
    property bool bluetoothEnabled: false
    property string wifiSsid: ""

    // Режим тишины и ночной режим хранятся в settings.json
    readonly property bool dndEnabled:
        root.settingsManager ? root.settingsManager.notifications.dnd === true : false
    readonly property bool nightModeEnabled:
        root.settingsManager ? root.settingsManager.display.nightMode === true : false
    readonly property bool settingsReady:
        root.settingsManager ? root.settingsManager.isReady === true : false

    property bool _nightRestored: false

    readonly property int blockHeight: 72
    readonly property int nightTemp: 4700
    readonly property int normalTemp: 6500

    readonly property color surfaceColor:
        theme && theme.colors && theme.colors.surface
            ? theme.colors.surface : "#1A1F26"
    readonly property color borderColor:
        theme && theme.colors && theme.colors.border
            ? theme.colors.border : "#2A323D"
    readonly property color accentColor:
        theme && theme.colors && theme.colors.accent
            ? theme.colors.accent : "#5B9BFF"
    readonly property color tileColor:
        theme && theme.colors && theme.colors.surfaceSelected
            ? theme.colors.surfaceSelected : "#2C3A50"
    readonly property color textColor:
        theme && theme.colors && theme.colors.text
            ? theme.colors.text : "#F0F4F8"
    readonly property color secondaryTextColor:
        theme && theme.colors && theme.colors.textSecondary
            ? theme.colors.textSecondary : "#9AA9B9"

    implicitHeight: blockHeight
    implicitWidth: 280

    onSettingsReadyChanged: root.restoreNightMode()

    function playClick() {
        if (root.soundPlayer)
            root.soundPlayer.play("click.wav")
    }

    // ---------- Wi-Fi ----------

    // Состояние радио и подключённая сеть запрашиваются отдельно:
    // пустой результат сканирования не означает, что радио выключено.
    Process {
        id: wifiRadioStatus
        command: ["nmcli", "-t", "-f", "WIFI", "general"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim().toLowerCase() === "enabled"
            }
        }
    }

    Process {
        id: wifiSsidStatus
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"]

        stdout: StdioCollector {
            onStreamFinished: {
                let activeSsid = ""
                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; ++i) {
                    const separator = lines[i].indexOf(":")
                    if (separator < 0)
                        continue

                    const active = lines[i].slice(0, separator)
                    const ssid = lines[i].slice(separator + 1)

                    if (active === "yes" || active === "*") {
                        activeSsid = ssid
                        break
                    }
                }

                root.wifiSsid = activeSsid
            }
        }
    }

    Process {
        id: wifiToggle
        property string targetState: "on"
        command: ["nmcli", "radio", "wifi", targetState]
        onExited: {
            wifiRadioStatus.running = true
            wifiSsidStatus.running = true
        }
    }

    function toggleWifi() {
        if (wifiToggle.running)
            return

        const nextState = !root.wifiEnabled
        wifiToggle.targetState = nextState ? "on" : "off"
        root.wifiEnabled = nextState
        wifiToggle.running = true
        root.playClick()
    }

    // ---------- Bluetooth ----------

    Process {
        id: bluetoothStatus
        command: ["bluetoothctl", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothEnabled = text.indexOf("Powered: yes") !== -1
            }
        }
    }

    Process {
        id: bluetoothToggle
        property string targetState: "on"
        command: ["bluetoothctl", "power", targetState]
        onExited: bluetoothStatus.running = true
    }

    function toggleBluetooth() {
        if (bluetoothToggle.running)
            return

        const nextState = !root.bluetoothEnabled
        bluetoothToggle.targetState = nextState ? "on" : "off"
        root.bluetoothEnabled = nextState
        bluetoothToggle.running = true
        root.playClick()
    }

    // ---------- Режим тишины (settings.notifications.dnd) ----------

    function toggleDnd() {
        if (!root.settingsManager)
            return

        const nextState = !root.dndEnabled
        root.settingsManager.set("notifications.dnd", nextState)
        root.playClick()

        Qt.callLater(function() {
            const message = nextState
                ? "Уведомления не будут всплывать"
                : "Уведомления снова будут всплывать"
            Quickshell.execDetached([
                "notify-send", "-u", "normal", "Режим тишины", message
            ])
        })

        root.dndStateChanged(nextState)
    }

    // ---------- Ночной режим (settings.display.nightMode) ----------

    Process {
        id: gammaRelayStart
        command: [
            "sh", "-c",
            "pgrep -x wl-gammarelay-rs >/dev/null || (wl-gammarelay-rs >/dev/null 2>&1 &)"
        ]
        onExited: nightModeSetTimer.restart()
    }

    Process {
        id: setNightTemperature
        property int targetTemperature: root.nightTemp
        command: [
            "busctl", "--user", "set-property",
            "rs.wl-gammarelay", "/", "rs.wl.gammarelay",
            "Temperature", "q", String(targetTemperature)
        ]
    }

    Timer {
        id: nightModeSetTimer
        interval: 300
        repeat: false
        onTriggered: setNightTemperature.running = true
    }

    function enableNightMode() {
        setNightTemperature.targetTemperature = root.nightTemp
        gammaRelayStart.running = true
    }

    function disableNightMode() {
        setNightTemperature.targetTemperature = root.normalTemp
        setNightTemperature.running = true
    }

    // Один раз после загрузки настроек: если ночной режим был включён, применяем его
    function restoreNightMode() {
        if (root._nightRestored || !root.settingsReady)
            return
        root._nightRestored = true
        if (root.nightModeEnabled)
            root.enableNightMode()
    }

    function toggleNightMode() {
        if (!root.settingsManager)
            return

        const nextState = !root.nightModeEnabled
        root.settingsManager.set("display.nightMode", nextState)

        if (nextState)
            root.enableNightMode()
        else
            root.disableNightMode()

        root.playClick()

        Qt.callLater(function() {
            const message = nextState
                ? "Цветовая температура: " + root.nightTemp + "K"
                : "Цветовая температура: обычная"
            Quickshell.execDetached([
                "notify-send", "-u", "normal", "Ночной режим", message
            ])
        })
    }

    // ---------- UI ----------

    Rectangle {
        id: mainBlock

        anchors.fill: parent
        radius: 18
        color: root.surfaceColor
        border.width: 1
        border.color: root.borderColor
        antialiasing: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 7

            ToggleButton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: root.nightModeEnabled ? "󰖔" : "󰖨"
                label: "Ночь"
                active: root.nightModeEnabled
                activeColor: root.accentColor
                inactiveColor: root.tileColor
                textColor: root.textColor
                secondaryTextColor: root.secondaryTextColor
                onClicked: root.toggleNightMode()
            }

            ToggleButton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: root.wifiEnabled ? "󰤨" : "󰤮"
                label: "Wi-Fi"
                active: root.wifiEnabled
                subtitle: root.wifiEnabled && root.wifiSsid ? root.wifiSsid : ""
                activeColor: root.accentColor
                inactiveColor: root.tileColor
                textColor: root.textColor
                secondaryTextColor: root.secondaryTextColor
                onClicked: root.toggleWifi()
            }

            ToggleButton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: root.bluetoothEnabled ? "󰂯" : "󰂲"
                label: "Bluetooth"
                active: root.bluetoothEnabled
                activeColor: root.accentColor
                inactiveColor: root.tileColor
                textColor: root.textColor
                secondaryTextColor: root.secondaryTextColor
                onClicked: root.toggleBluetooth()
            }

            ToggleButton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: root.dndEnabled ? "󰹠" : "󰂛"
                label: "Тишина"
                active: root.dndEnabled
                activeColor: root.accentColor
                inactiveColor: root.tileColor
                textColor: root.textColor
                secondaryTextColor: root.secondaryTextColor
                onClicked: root.toggleDnd()
            }
        }
    }

    component ToggleButton: Rectangle {
        id: button

        property string icon: ""
        property string label: ""
        property string subtitle: ""
        property bool active: false
        property color activeColor: "#5B9BFF"
        property color inactiveColor: "#2C3A50"
        property color textColor: "#F0F4F8"
        property color secondaryTextColor: "#9AA9B9"

        signal clicked()

        radius: 13
        color: active ? activeColor : inactiveColor
        border.width: 1
        border.color: active
            ? Qt.alpha(activeColor, 0.75)
            : Qt.alpha(textColor, hoverArea.containsMouse ? 0.14 : 0.04)
        scale: hoverArea.pressed ? 0.96 : (hoverArea.containsMouse ? 1.025 : 1.0)

        Behavior on color {
            ColorAnimation { duration: 170 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 4
            spacing: 3

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.icon
                color: button.active ? button.textColor : button.secondaryTextColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                text: button.label
                color: button.active ? button.textColor : button.secondaryTextColor
                font.pixelSize: 9
                font.weight: button.active ? Font.DemiBold : Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }

        Accessible.name: button.label
        Accessible.role: Accessible.Button
        Accessible.checked: button.active
    }

    Component.onCompleted: {
        wifiRadioStatus.running = true
        wifiSsidStatus.running = true
        bluetoothStatus.running = true
        root.restoreNightMode()
    }

    // Опрашиваем только то, что может измениться извне: Wi-Fi и Bluetooth
    Timer {
        interval: 10000
        repeat: true
        running: true

        onTriggered: {
            if (!wifiRadioStatus.running)
                wifiRadioStatus.running = true
            if (!wifiSsidStatus.running)
                wifiSsidStatus.running = true
            if (!bluetoothStatus.running)
                bluetoothStatus.running = true
        }
    }
}