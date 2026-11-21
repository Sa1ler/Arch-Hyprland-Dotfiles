import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var theme: null
    property var soundManager: null
    property bool active: false
    
    readonly property color textColor: root.theme && root.theme.colors ? root.theme.colors.text : "#FFFFFF"
    readonly property color accentColor: root.theme && root.theme.colors ? root.theme.colors.accent : "#5B9BFF"
    readonly property color borderColor: root.theme && root.theme.colors ? root.theme.colors.border : "#2A2A2A"
    
    signal close()

    // === Плавные анимации ===
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.92
    y: active ? 0 : -15
    
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
    Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
    Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

    // === Таймер задержки для полного скриншота ===
    Timer {
        id: fullScreenshotDelay
        interval: 600  // 600ms задержки, чтобы меню успело свернуться
        onTriggered: {
            console.log("[ScreenshotMenu] Taking full screenshot after delay")
            Quickshell.execDetached([
                "sh", "-c",
                "grim - | wl-copy && notify-send -h string:category:screenshot 'Скриншот' 'Сохранён в буфер обмена'"
            ])
        }
    }

    // === Таймер задержки для скриншота области ===
    Timer {
        id: regionScreenshotDelay
        interval: 400  // Меньше задержки для области, так как нужно время на выбор
        onTriggered: {
            console.log("[ScreenshotMenu] Taking region screenshot after delay")
            Quickshell.execDetached([
                "sh", "-c",
                "grim -g \"$(slurp)\" - | wl-copy && notify-send -h string:category:screenshot 'Скриншот области' 'Скриншот области скопирован в буфер обмена'"
            ])
        }
    }

    function takeFullScreenshot() {
        if (root.soundManager) root.soundManager.play("quick_click.wav")
        root.close()  // Сначала закрываем меню
        fullScreenshotDelay.start()  // Потом запускаем таймер
    }
    
    function takeRegionScreenshot() {
        if (root.soundManager) root.soundManager.play("quick_click.wav")
        root.close()  // Сначала закрываем меню
        regionScreenshotDelay.start()  // Потом запускаем таймер
    }

    // === ЧЁРНЫЙ ФОН с закрытием по клику ===
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "#000000"
        
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
        
        Rectangle {
            anchors.fill: parent
            radius: 20
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            color: "transparent"
        }
    }

    // === КОМПАКТНЫЕ КНОПКИ С ИКОНКАМИ ===
    Row {
        id: buttonRow
        anchors.centerIn: parent
        spacing: 16

        // === Кнопка полного снимка ===
        Rectangle {
            id: fullBtn
            width: 56
            height: 56
            radius: 14
            color: fullMouse.containsMouse ? "#1A1A1A" : "#111111"
            border.width: fullMouse.containsMouse ? 2 : 1
            border.color: fullMouse.containsHover ? root.accentColor : root.borderColor
            
            scale: fullMouse.pressed ? 0.95 : (fullMouse.containsMouse ? 1.08 : 1.0)
            
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on border.width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

            // Свечение при hover
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 17
                color: "transparent"
                border.width: 2
                border.color: root.accentColor
                opacity: fullMouse.containsMouse ? 0.35 : 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            }

            Text {
                anchors.centerIn: parent
                text: "\uf030"  // fa-camera
                font.family: "Font Awesome 6 Free Solid"
                font.pixelSize: 24
                font.weight: Font.Black
                color: fullMouse.containsMouse ? root.accentColor : root.textColor
                scale: fullMouse.containsMouse ? 1.15 : 1.0
                
                Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            }

            MouseArea {
                id: fullMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.takeFullScreenshot()
            }
        }

        // === Кнопка снимка области ===
        Rectangle {
            id: regionBtn
            width: 56
            height: 56
            radius: 14
            color: regionMouse.containsMouse ? "#1A1A1A" : "#111111"
            border.width: regionMouse.containsMouse ? 2 : 1
            border.color: regionMouse.containsMouse ? root.accentColor : root.borderColor
            
            scale: regionMouse.pressed ? 0.95 : (regionMouse.containsMouse ? 1.08 : 1.0)
            
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on border.width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

            // Свечение при hover
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 17
                color: "transparent"
                border.width: 2
                border.color: root.accentColor
                opacity: regionMouse.containsMouse ? 0.35 : 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            }

            Text {
                anchors.centerIn: parent
                text: "\uf125"  // fa-crop
                font.family: "Font Awesome 6 Free Solid"
                font.pixelSize: 24
                font.weight: Font.Black
                color: regionMouse.containsMouse ? root.accentColor : root.textColor
                scale: regionMouse.containsMouse ? 1.15 : 1.0
                
                Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            }

            MouseArea {
                id: regionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.takeRegionScreenshot()
            }
        }
    }
}