import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var theme: null
    property var soundPlayer: null

    property string username: Quickshell.env("USER") || "user"
    property string displayName: ""
    property string avatarPath: ""

    readonly property int cardHeight: 72
    readonly property int horizontalPadding: 14
    readonly property int avatarSize: 44
    readonly property int logoutSize: 40
    readonly property int contentSpacing: 12

    readonly property color backgroundColor:
        theme && theme.colors && theme.colors.surface
            ? theme.colors.surface : "#1A1F26"
    readonly property color borderColor:
        theme && theme.colors && theme.colors.border
            ? theme.colors.border : "#2A323D"
    readonly property color avatarColor:
        theme && theme.colors && theme.colors.surfaceSelected
            ? theme.colors.surfaceSelected : "#2C3A50"
    readonly property color primaryTextColor:
        theme && theme.colors && theme.colors.text
            ? theme.colors.text : "#F0F4F8"
    readonly property color secondaryTextColor:
        theme && theme.colors && theme.colors.textSecondary
            ? theme.colors.textSecondary : "#9AA9B9"

    implicitHeight: cardHeight
    implicitWidth: 280

    Process {
        id: getUserInfo

        command: [
            "sh", "-c",
            "getent passwd \"$USER\" 2>/dev/null | cut -d: -f5 | cut -d, -f1; " +
            "if [ -f \"$HOME/.face\" ]; then printf '%s\\n' \"$HOME/.face\"; " +
            "elif [ -f \"$HOME/.face.icon\" ]; then printf '%s\\n' \"$HOME/.face.icon\"; fi"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.displayName = lines.length > 0 ? lines[0].trim() : ""
                root.avatarPath = lines.length > 1 ? lines[1].trim() : ""
            }
        }
    }

    Process {
        id: logoutProcess
        command: ["hyprctl", "dispatch", "exit"]
    }

    function logout() {
        if (logoutProcess.running)
            return

        if (root.soundPlayer)
            root.soundPlayer.play("disconnect.wav")

        Qt.callLater(function() {
            logoutProcess.running = true
        })
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: 18
        color: root.backgroundColor
        border.width: 1
        border.color: root.borderColor
        antialiasing: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.horizontalPadding
            anchors.rightMargin: root.horizontalPadding
            spacing: root.contentSpacing

            Item {
                id: avatarFrame

                Layout.preferredWidth: root.avatarSize
                Layout.preferredHeight: root.avatarSize
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.avatarColor
                    border.width: 1
                    border.color: Qt.alpha(root.primaryTextColor, 0.08)
                }

                Image {
                    id: avatar

                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.avatarPath.length > 0
                            ? "file://" + root.avatarPath : ""
                    sourceSize.width: root.avatarSize * 2
                    sourceSize.height: root.avatarSize * 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    visible: status === Image.Ready
                    layer.enabled: visible
                    layer.smooth: true

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(root.primaryTextColor, 0.08)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: {
                        const name = root.displayName || root.username
                        return name.length > 0 ? name.charAt(0).toUpperCase() : "?"
                    }
                    color: root.primaryTextColor
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    visible: avatar.status !== Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: root.displayName || root.username
                    color: root.primaryTextColor
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: root.username ? "@" + root.username : "Локальный пользователь"
                    color: root.secondaryTextColor
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Rectangle {
                id: logoutButton

                Layout.preferredWidth: root.logoutSize
                Layout.preferredHeight: root.logoutSize
                Layout.alignment: Qt.AlignVCenter
                radius: 13

                readonly property bool hovered: logoutMouseArea.containsMouse
                readonly property bool pressed: logoutMouseArea.pressed

                color: pressed
                       ? Qt.alpha("#FF453A", 0.22)
                       : hovered ? Qt.alpha("#FF453A", 0.12) : "transparent"
                border.width: hovered ? 1 : 0
                border.color: Qt.alpha("#FF453A", hovered ? 0.45 : 0.0)
                scale: pressed ? 0.94 : (hovered ? 1.03 : 1.0)

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
                Behavior on border.color {
                    ColorAnimation { duration: 140 }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰍃"
                    color: logoutButton.hovered || logoutButton.pressed
                           ? "#FF6259" : root.secondaryTextColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 19

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }
                }

                MouseArea {
                    id: logoutMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.logout()
                }

                Accessible.name: "Выйти из системы"
                Accessible.description: "Завершить текущую сессию Hyprland"
                Accessible.role: Accessible.Button
            }
        }
    }

    Component.onCompleted: getUserInfo.running = true
}
