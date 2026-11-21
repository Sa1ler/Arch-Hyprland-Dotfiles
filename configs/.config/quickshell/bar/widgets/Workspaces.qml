import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var theme: null
    property var soundManager: null
    property int maxWorkspaces: 5
    property int currentWorkspace: 1
    property int activeIndex: 0

    readonly property color accentColor: root.theme && root.theme.colors ? root.theme.colors.accent : "#5B9BFF"
    readonly property color inactiveColor: root.theme && root.theme.colors ? root.theme.colors.textSecondary : "#888888"

    implicitWidth: contentRow.implicitWidth
    implicitHeight: 24

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.maxWorkspaces

            // Контейнер фиксированной высоты для правильного выравнивания
            Item {
                width: 4
                height: 24

                Rectangle {
                    id: bar
                    anchors.centerIn: parent  // Центрируем полоску внутри контейнера

                    property int wsIndex: index + 1
                    property bool isActive: index === root.activeIndex
                    property bool isHovered: barMouse.containsMouse

                    width: 6
                    height: isActive ? 16 : (isHovered ? 12 : 8)
                    radius: 2

                    color: isActive ? root.accentColor : root.inactiveColor
                    opacity: isActive ? 1.0 : (isHovered ? 0.9 : 0.4)

                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }

                    MouseArea {
                        id: barMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: function(mouse) {
                            if (root.soundManager) root.soundManager.play("click.wav")
                            if (mouse.button === Qt.LeftButton) {
                                switchToWorkspace(bar.wsIndex)
                            } else if (mouse.button === Qt.RightButton) {
                                moveWindowToWorkspace(bar.wsIndex)
                            }
                        }

                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y > 0) {
                                switchToWorkspace(Math.max(1, root.currentWorkspace - 1))
                            } else {
                                switchToWorkspace(Math.min(root.maxWorkspaces, root.currentWorkspace + 1))
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: getWorkspace
        command: ["bash", "-c", "hyprctl activeworkspace -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    root.currentWorkspace = data.id
                    if (data.id > 0 && data.id <= root.maxWorkspaces) {
                        root.activeIndex = data.id - 1
                    }
                } catch(e) {
                    // ignore
                }
            }
        }
    }

    Process {
        id: hyprListener
        command: ["bash", "-c",
            "socat - UNIX-CONNECT:$(ls -t /run/user/$(id -u)/hypr/*/.socket2.sock 2>/dev/null | head -n1)"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (line.startsWith("workspace>>")) {
                    var id = parseInt(line.split(">>")[1])
                    if (!isNaN(id) && id >= 1 && id <= root.maxWorkspaces) {
                        root.currentWorkspace = id
                        root.activeIndex = id - 1
                    }
                } else if (line.startsWith("focusedmon>>") ||
                           line.startsWith("createworkspace>>") ||
                           line.startsWith("destroyworkspace>>")) {
                    getWorkspace.running = true
                }
            }
        }
    }

    Process {
        id: dispatchProcess
        
        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.trim()
                if (out.length > 0) {
                    console.log("[hyprctl]:", out)
                }
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                var err = text.trim()
                if (err.length > 0) {
                    console.warn("[hyprctl error]:", err)
                }
            }
        }
    }

    Component.onCompleted: {
        getWorkspace.running = true
    }

    function switchToWorkspace(number) {
        console.log("[Workspaces] Switching to workspace:", number)
        dispatchProcess.command = ["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${number} })`]
        dispatchProcess.running = true
        root.activeIndex = number - 1
    }

    function moveWindowToWorkspace(number) {
        console.log("[Workspaces] Moving window to workspace:", number)
        dispatchProcess.command = ["hyprctl", "dispatch", `hl.dsp.window.move({ workspace = ${number} })`]
        dispatchProcess.running = true
    }
}