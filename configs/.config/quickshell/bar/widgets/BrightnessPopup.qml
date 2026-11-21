import QtQuick

Item {
    id: root

    property var theme: null
    property var manager: null
    property bool active: false

    readonly property color accentColor: root.theme && root.theme.colors ? root.theme.colors.accent : "#5B9BFF"
    readonly property color textColor: root.theme && root.theme.colors ? root.theme.colors.text : "#FFFFFF"
    readonly property color textSecondaryColor: root.theme && root.theme.colors ? root.theme.colors.textSecondary : "#AAAAAA"
    readonly property color trackColor: "#2A2A2A"

    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }

    Row {
        anchors.centerIn: parent
        spacing: 12

        // === ИКОНКА ===
        Rectangle {
            id: iconContainer
            width: 42
            height: 42
            radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"

            Text {
                anchors.centerIn: parent
                // fa-sun (низкая) / fa-sun (средняя) / fa-sun (высокая)
                text: root.manager && root.manager.brightness < 30 ? "\uf185" :
                      (root.manager && root.manager.brightness < 70 ? "\uf185" : "\uf185")
                font.family: "Font Awesome 6 Free Solid"
                font.pixelSize: 34
                font.weight: Font.Black
                color: root.manager && root.manager.brightness === 0 ? root.textSecondaryColor : root.accentColor
                opacity: root.manager && root.manager.brightness === 0 ? 0.6 : 1.0
                Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutQuint } }
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }
        }

        // === ПОЛЗУНОК ===
        Item {
            width: 120
            height: 42
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 5
                radius: 2.5
                color: root.trackColor

                Rectangle {
                    id: fill
                    width: root.manager ? (track.width * root.manager.brightness / 100) : 0
                    height: parent.height
                    radius: parent.radius

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Qt.darker(root.accentColor, 1.25)
                        }
                        GradientStop {
                            position: 1.0
                            color: root.accentColor
                        }
                    }

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                }

                Rectangle {
                    id: handle
                    x: Math.max(0, Math.min(track.width - 12,
                       (root.manager ? track.width * root.manager.brightness / 100 : 0) - 6))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: root.manager && root.manager.brightness === 0 ? root.textSecondaryColor : root.accentColor

                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton

                function seek(mouseX) {
                    if (!root.manager) return
                    var percent = Math.max(0, Math.min(100, (mouseX / width) * 100))
                    root.manager.setBrightness(percent)
                }

                onPressed: function(mouse) { seek(mouse.x) }
                onPositionChanged: function(mouse) {
                    if (pressed) seek(mouse.x)
                }
                onWheel: function(wheel) {
                    if (!root.manager) return
                    root.manager.changeBrightness(wheel.angleDelta.y > 0 ? 5 : -5)
                }
            }
        }

        // === ПРОЦЕНТ ===
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            horizontalAlignment: Text.AlignRight
            text: root.manager ? root.manager.brightness + "%" : "0%"
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: Font.Bold
            color: root.manager && root.manager.brightness === 0 ? root.textSecondaryColor : root.textColor
            opacity: root.manager && root.manager.brightness === 0 ? 0.7 : 1.0

            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }
    }
}
