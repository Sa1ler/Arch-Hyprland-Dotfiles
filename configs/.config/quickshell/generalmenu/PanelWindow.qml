import QtQuick
import Quickshell as Qs

import "modules"

Qs.PanelWindow {
    id: root

    property var theme: null
    property var themeManager: null
    property var soundPlayer: null
    property var settingsManager: null

    property bool opened: false
    property bool panelVisible: false

    readonly property int panelWidth: 380
    readonly property int panelMargin: 12
    readonly property int contentMargin: 16
    readonly property int sectionSpacing: 10
    readonly property int animationDuration: 380

    readonly property var _c: theme && theme.colors ? theme.colors : null
    readonly property color panelBackground: _c && _c.background ? _c.background : "#101010"
    readonly property color panelBorder: _c && _c.border ? _c.border : "#2A2A2A"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: root.panelVisible
    focusable: root.panelVisible

    Connections {
        target: root.themeManager

        function onThemeChanging() {
            // Оверлей запускается, только пока панель видна: иначе анимация идёт зря
            if (!root.panelVisible)
                return
            themeCircle.color = root.panelBackground
            themeTransition.restart()
        }
    }

    Item {
        id: inputLayer
        anchors.fill: parent
        focus: root.panelVisible

        Keys.onEscapePressed: function(event) {
            root.close()
            event.accepted = true
        }

        // Клик вне панели закрывает её. MouseArea самой панели
        // принимает клики, поэтому до этого обработчика они не доходят.
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: panel

            width: root.panelWidth
            height: Math.max(0, root.height - root.panelMargin * 2)
            x: root.width - width
            y: root.panelMargin
            clip: true

            topLeftRadius: 24
            bottomLeftRadius: 24
            topRightRadius: 0
            bottomRightRadius: 0

            color: root.panelBackground
            border.width: 1
            border.color: root.panelBorder

            transform: Translate {
                x: root.opened ? 0 : panel.width
                Behavior on x {
                    NumberAnimation {
                        duration: root.animationDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) {
                    mouse.accepted = true
                }
            }

            Item {
                anchors.fill: parent

                UserCard {
                    id: userCard
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: root.contentMargin
                        leftMargin: root.contentMargin
                        rightMargin: root.contentMargin
                    }
                    theme: root.theme
                    soundPlayer: root.soundPlayer
                }

                VolumeBrightness {
                    id: volumeBrightness
                    anchors {
                        top: userCard.bottom
                        left: parent.left
                        right: parent.right
                        topMargin: root.sectionSpacing
                        leftMargin: root.contentMargin
                        rightMargin: root.contentMargin
                    }
                    theme: root.theme
                    soundPlayer: root.soundPlayer
                }

                Connectivity {
                    id: connectivity
                    anchors {
                        top: volumeBrightness.bottom
                        left: parent.left
                        right: parent.right
                        topMargin: root.sectionSpacing
                        leftMargin: root.contentMargin
                        rightMargin: root.contentMargin
                    }
                    theme: root.theme
                    soundPlayer: root.soundPlayer
                    settingsManager: root.settingsManager
                }

                PowerMenu {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: root.contentMargin
                        rightMargin: root.contentMargin
                        bottomMargin: root.contentMargin
                    }
                    theme: root.theme
                    soundPlayer: root.soundPlayer
                    onActionExecuted: root.close()
                }
            }

            // Круговой оверлей при смене темы
            Item {
                anchors.fill: parent
                z: 9999
                clip: true

                Rectangle {
                    id: themeCircle
                    anchors.centerIn: parent
                    width: Math.max(parent.width, parent.height) * 2.5
                    height: width
                    radius: width / 2
                    color: root.panelBackground
                    scale: 0
                    visible: scale > 0

                    NumberAnimation {
                        id: themeTransition
                        target: themeCircle
                        property: "scale"
                        from: 0
                        to: 1
                        duration: 600
                        easing.type: Easing.OutCubic
                        onStopped: themeCircle.scale = 0
                    }
                }
            }
        }
    }

    Timer {
        id: closeTimer
        interval: root.animationDuration
        onTriggered: {
            if (!root.opened)
                root.panelVisible = false
        }
    }

    function open() {
        closeTimer.stop()
        root.panelVisible = true
        Qt.callLater(function() {
            root.opened = true
            inputLayer.forceActiveFocus()
        })
    }

    function close() {
        if (!root.opened)
            return
        root.opened = false
        closeTimer.restart()
    }
}