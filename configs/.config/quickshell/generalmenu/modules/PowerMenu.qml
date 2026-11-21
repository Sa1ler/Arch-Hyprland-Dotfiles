import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell

Item {
    id: root

    property var theme: null
    property var soundPlayer: null
    signal actionExecuted()

    implicitHeight: 60

    // ============================================================
    //  КОНСТАНТЫ
    // ============================================================

    readonly property int radius: 16
    readonly property int chargeMs: 1500
    readonly property int drainMs: 250

    // Цвета считаются один раз здесь, а не в каждой из кнопок
    readonly property var _c: theme && theme.colors ? theme.colors : null
    readonly property color cAccent:       _c && _c.accent          ? _c.accent          : "#5B9BFF"
    readonly property color cSurface:      _c && _c.surface         ? _c.surface         : "#1A1F26"
    readonly property color cSurfaceHover: _c && _c.surfaceHover    ? _c.surfaceHover    : "#252C36"
    readonly property color cBorder:       _c && _c.border          ? _c.border          : "#2A323D"
    readonly property color cText:         _c && _c.text            ? _c.text            : "#F0F4F8"
    readonly property color cTextSelected: _c && _c.textSelected    ? _c.textSelected    : "#FFFFFF"

    // Действия описаны данными: одна кнопка в коде вместо четырёх копий.
    // ВАЖНО: иконки здесь Nerd Font через \u-коды. Если у вас были другие глифы,
    // подставьте свои в поле icon (при копировании в текст они не сохраняются).
    readonly property var actions: [
        { "icon": "\uf011", "sound": "power_on.wav",     "cmd": ["systemctl", "poweroff"] },
        { "icon": "\uf021", "sound": "charge_loop2.wav", "cmd": ["systemctl", "reboot"] },
        { "icon": "\uf023", "sound": "sfx2.wav",         "cmd": ["hyprlock"] },
        { "icon": "\uf186", "sound": "swoosh.wav",       "cmd": ["systemctl", "suspend"] }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Repeater {
            model: root.actions

            PowerButton {
                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: modelData.icon
                executeSound: modelData.sound
                onExecute: {
                    Quickshell.execDetached(modelData.cmd)
                    root.actionExecuted()
                }
            }
        }
    }

    // ============================================================
    //  КНОПКА
    // ============================================================

    component PowerButton: Item {
        id: button

        property string icon: ""
        property string executeSound: "click.wav"
        property real liquidHeight: 0
        signal execute()

        readonly property bool filled: liquidHeight >= height
        readonly property bool overHalf: liquidHeight > height / 2

        implicitHeight: 60
        scale: mouseArea.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: mouseArea.containsMouse ? root.cSurfaceHover : root.cSurface
            border.width: 1
            border.color: root.cBorder
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Жидкость: скруглённый прямоугольник, обрезанный по уровню liquidHeight.
        // Геометрия считается аналитически: маска и offscreen-слой не нужны.
        // Пока жидкости нет, Shape скрыт, и его привязки не вычисляются.
        Shape {
            anchors.fill: parent
            visible: button.liquidHeight > 0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: lp

                readonly property real w: button.width
                readonly property real h: button.height
                readonly property real r: Math.min(root.radius, w / 2, h / 2)
                readonly property real t: h - Math.min(button.liquidHeight, h)  // верх жидкости
                readonly property bool top: t < r                               // срез в верхних углах
                readonly property bool bot: t > h - r                           // срез в нижних углах
                readonly property real dy: top ? r - t : (bot ? t - (h - r) : 0)
                readonly property real xc: r - Math.sqrt(Math.max(0, r * r - dy * dy))

                fillColor: root.cAccent
                strokeWidth: -1

                startX: xc
                startY: t

                PathLine { x: lp.w - lp.xc; y: lp.t }
                PathArc {   // верхний правый угол
                    x: lp.top ? lp.w : lp.w - lp.xc
                    y: lp.top ? lp.r : lp.t
                    radiusX: lp.r; radiusY: lp.r
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: lp.bot ? lp.w - lp.xc : lp.w
                    y: lp.bot ? lp.t : lp.h - lp.r
                }
                PathArc {   // нижний правый угол
                    x: lp.w - lp.r; y: lp.h
                    radiusX: lp.r; radiusY: lp.r
                    direction: PathArc.Clockwise
                }
                PathLine { x: lp.r; y: lp.h }
                PathArc {   // нижний левый угол
                    x: lp.bot ? lp.xc : 0
                    y: lp.bot ? lp.t : lp.h - lp.r
                    radiusX: lp.r; radiusY: lp.r
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: lp.top ? 0 : lp.xc
                    y: lp.top ? lp.r : lp.t
                }
                PathArc {   // верхний левый угол
                    x: lp.xc; y: lp.t
                    radiusX: lp.r; radiusY: lp.r
                    direction: PathArc.Clockwise
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 24
            renderType: Text.NativeRendering
            color: button.overHalf ? root.cTextSelected : root.cText
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: {
                if (root.soundPlayer) root.soundPlayer.play("charge_loop2.wav")
                liquidAnim.stop()
                button.liquidHeight = 0
                liquidAnim.to = button.height
                liquidAnim.duration = root.chargeMs
                liquidAnim.start()
            }
            onReleased: drain()
            onCanceled: drain()

            function drain() {
                liquidAnim.stop()
                if (button.liquidHeight > 0) {
                    // Длительность пропорциональна оставшемуся уровню: без рывка при раннем отпускании
                    liquidAnim.to = 0
                    liquidAnim.duration = Math.max(60, root.drainMs * button.liquidHeight / button.height)
                    liquidAnim.start()
                }
            }
        }

        NumberAnimation {
            id: liquidAnim
            target: button
            property: "liquidHeight"
            easing.type: Easing.Linear
            onStopped: {
                if (button.filled && mouseArea.pressed) {
                    if (root.soundPlayer) root.soundPlayer.play(button.executeSound)
                    executeTimer.start()
                }
            }
        }

        // Короткая пауза, чтобы звук успел стартовать до выполнения команды
        Timer {
            id: executeTimer
            interval: 50
            onTriggered: button.execute()
        }
    }
}