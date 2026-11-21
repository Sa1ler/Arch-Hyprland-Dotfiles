import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var theme: null
    property int batteryLevel: 100
    property bool charging: false
    readonly property bool isLowBattery: batteryLevel < 15 && !charging

    readonly property color accentColor: root.theme && root.theme.colors ? root.theme.colors.accent : "#5B9BFF"
    readonly property color lowBatteryColor: "#FF3B3B"

    implicitWidth: 22
    implicitHeight: 14

    Item {
        id: batteryContainer
        anchors.centerIn: parent
        width: 22
        height: 14

        // Корпус батареи
        Rectangle {
            id: batteryBody
            width: 18
            height: 14
            radius: 2
            color: "transparent"
            border.width: 2
            border.color: root.isLowBattery ? root.lowBatteryColor : root.accentColor

            Behavior on border.color { ColorAnimation { duration: 300 } }
        }

        // Выступ батареи
        Rectangle {
            anchors.left: batteryBody.right
            anchors.leftMargin: 1
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 6
            radius: 1
            color: root.isLowBattery ? root.lowBatteryColor : root.accentColor
        }

        // Уровень заполнения
        Rectangle {
            id: batteryFill
            anchors.left: batteryBody.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, 14 * (root.batteryLevel / 100))
            height: 10
            radius: 1
            color: root.isLowBattery ? root.lowBatteryColor : root.accentColor

            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Индикатор зарядки
        Text {
            anchors.centerIn: parent
            text: "⚡"
            font.pixelSize: 12
            font.weight: Font.Black
            color: root.accentColor
            visible: root.charging
        }
    }

    // Мигание только border для оптимизации
    SequentialAnimation {
        id: blinkAnimation
        loops: Animation.Infinite

        PropertyAction {
            target: batteryBody
            property: "opacity"
            value: 1.0
        }
        PauseAnimation { duration: 500 }
        PropertyAction {
            target: batteryBody
            property: "opacity"
            value: 0.4
        }
        PauseAnimation { duration: 500 }
    }

    onIsLowBatteryChanged: {
        if (isLowBattery) {
            blinkAnimation.start()
        } else {
            blinkAnimation.stop()
            batteryBody.opacity = 1.0
        }
    }

    // Оптимизированный процесс
    Process {
        id: getBattery
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1 && echo '' && cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")

                if (lines.length >= 1) {
                    var level = parseInt(lines[0])
                    if (!isNaN(level)) {
                        root.batteryLevel = level
                    }
                }

                if (lines.length >= 3) {
                    var status = lines[2].toLowerCase()
                    root.charging = (status === "charging" || status === "full")
                }
            }
        }
    }

    Timer {
        id: batteryTimer
        interval: 10000  // Увеличил до 10 секунд
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!getBattery.running) {
                getBattery.running = true
            }
        }
    }
}