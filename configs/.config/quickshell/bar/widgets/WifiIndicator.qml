import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var theme: null
    property var wifiPopup: null
    property string wifiState: "off"
    property int signalStrength: 0

    readonly property color accentColor: root.theme && root.theme.colors ? root.theme.colors.accent : "#5B9BFF"
    readonly property color inactiveColor: root.theme && root.theme.colors ? root.theme.colors.textSecondary : "#666666"

    implicitWidth: wifiBars.implicitWidth
    implicitHeight: 18

    Row {
        id: wifiBars
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: 4

            // Контейнер фиксированной высоты для выравнивания по низу
            Item {
                width: 3
                height: 18

                Rectangle {
                    property int barIndex: index + 1
                    property bool isActive: root.wifiState !== "off" && root.signalStrength >= barIndex

                    anchors.bottom: parent.bottom  // Выравнивание по низу!
                    width: 3
                    height: 6 + (index * 4)  // 6, 10, 14, 18
                    radius: 1

                    color: isActive ? root.accentColor : root.inactiveColor
                    opacity: isActive ? 1.0 : 0.3

                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
        }
    }

    MouseArea {
        id: wifiMouse
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (root.wifiPopup) {
                root.wifiPopup.toggle()
            }
        }
    }

    // Оптимизированный процесс с кэшированием
    Process {
        id: getWifiStatus
        command: ["sh", "-c", "LC_ALL=C nmcli -t -f active,signal dev wifi 2>/dev/null | grep '^yes\\|^\\*' | head -1 | cut -d: -f2"]

        stdout: StdioCollector {
            onStreamFinished: {
                var signal = parseInt(text.trim())

                if (isNaN(signal) || signal === 0) {
                    root.wifiState = "off"
                    root.signalStrength = 0
                    return
                }

                root.wifiState = "connected"

                if (signal >= 80) root.signalStrength = 4
                else if (signal >= 60) root.signalStrength = 3
                else if (signal >= 40) root.signalStrength = 2
                else if (signal >= 20) root.signalStrength = 1
                else root.signalStrength = 0
            }
        }
    }

    Timer {
        id: wifiTimer
        interval: 5000  // Увеличил до 5 секунд для оптимизации
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!getWifiStatus.running) {
                getWifiStatus.running = true
            }
        }
    }
}