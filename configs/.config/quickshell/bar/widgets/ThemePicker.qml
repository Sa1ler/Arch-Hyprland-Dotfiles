import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var theme: null
    property var themeManager: null
    property var soundManager: null
    property bool active: false
    property var themesList: []
    property int currentIndex: 0
    property bool isFirstChange: true
    
    readonly property color surfaceColor: root.theme && root.theme.colors ? root.theme.colors.surface : "#1A1F26"
    readonly property color textColor: root.theme && root.theme.colors ? root.theme.colors.text : "#FFFFFF"
    readonly property color accentColor: root.theme && root.theme.colors ? root.theme.colors.accent : "#5B9BFF"
    readonly property color textSecondaryColor: root.theme && root.theme.colors ? root.theme.colors.textSecondary : "#AAAAAA"
    
    readonly property real glassOpacity: 0.92
    
    signal close()

    // === Плавные анимации появления/исчезновения ===
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.92
    y: active ? 0 : -25
    
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }
    Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }

    Process {
        id: loadThemes
        command: ["sh", "-c", "ls -1 ~/.config/quickshell/themes/ 2>/dev/null | grep -iE '\\.json$' | sed 's/\\.json$//' | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                var files = text.trim().split('\n').filter(function(f) { return f.length > 0 })
                root.themesList = files
                
                if (root.active && root.themeManager && root.themeManager.currentTheme && files.length > 0) {
                    for (var i = 0; i < files.length; i++) {
                        if (files[i] === root.themeManager.currentTheme) {
                            root.currentIndex = i
                            pathView.currentIndex = i
                            break
                        }
                    }
                }
            }
        }
    }

    onActiveChanged: {
        if (active) {
            focusScope.forceActiveFocus()
            isFirstChange = true
            if (themesList.length === 0) {
                loadThemes.running = true
            } else if (themeManager && themeManager.currentTheme && themesList.length > 0) {
                for (var i = 0; i < themesList.length; i++) {
                    if (themesList[i] === themeManager.currentTheme) {
                        root.currentIndex = i
                        pathView.currentIndex = i
                        break
                    }
                }
            }
        } else {
            isFirstChange = true
        }
    }

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

    FocusScope {
        id: focusScope
        anchors.fill: parent

        Keys.onEscapePressed: event => {
            root.close()
            event.accepted = true
        }
        Keys.onLeftPressed: event => {
            pathView.decrementCurrentIndex()
            event.accepted = true
        }
        Keys.onRightPressed: event => {
            pathView.incrementCurrentIndex()
            event.accepted = true
        }
        Keys.onReturnPressed: event => {
            root.applyCurrent()
            event.accepted = true
        }

        Text {
            id: title
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 26
            text: "Themes"
            color: root.textColor
            font.pixelSize: 16
            font.weight: Font.DemiBold
            font.family: "CaskaydiaCove Nerd Font"
            
            opacity: active ? 1 : 0
            y: active ? 0 : -10
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
            Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }
        }

        PathView {
            id: pathView
            anchors.top: title.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 22
            anchors.bottomMargin: 58
            anchors.leftMargin: 80
            anchors.rightMargin: 80
            
            clip: true
            model: root.themesList
            pathItemCount: 5
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightMoveDuration: 500
            snapMode: PathView.SnapToItem
            
            path: Path {
                startX: -pathView.width * 0.35
                startY: pathView.height / 2
                
                PathAttribute { name: "itemScale"; value: 0.6 }
                PathAttribute { name: "itemOpacity"; value: 0.35 }
                PathAttribute { name: "itemZ"; value: 0 }
                
                PathLine { x: pathView.width / 2; y: pathView.height / 2 }
                
                PathAttribute { name: "itemScale"; value: 1.0 }
                PathAttribute { name: "itemOpacity"; value: 1.0 }
                PathAttribute { name: "itemZ"; value: 10 }
                
                PathLine { x: pathView.width * 1.35; y: pathView.height / 2 }
                
                PathAttribute { name: "itemScale"; value: 0.6 }
                PathAttribute { name: "itemOpacity"; value: 0.35 }
                PathAttribute { name: "itemZ"; value: 0 }
            }
            
            delegate: Item {
                id: delegateItem
                width: pathView.width * 0.38
                height: pathView.height * 0.82
                
                property bool isCurrent: PathView.isCurrentItem
                property bool isHovered: cardMouse.containsMouse
                
                property var themeData: {
                    if (!root.themeManager || !root.themeManager.themes) return null
                    for (var i = 0; i < root.themeManager.themes.length; i++) {
                        if (root.themeManager.themes[i].file === modelData) {
                            return root.themeManager.themes[i]
                        }
                    }
                    return null
                }
                
                property color bgColor: themeData && themeData.colors ? themeData.colors.background : "#181818"
                property color surfColor: themeData && themeData.colors ? themeData.colors.surface : "#1A1F26"
                property color tAccentColor: themeData && themeData.colors ? themeData.colors.accent : "#5B9BFF"
                property color tTextColor: themeData && themeData.colors ? themeData.colors.text : "#FFFFFF"
                property color tTextSecColor: themeData && themeData.colors ? themeData.colors.textSecondary : "#AAAAAA"
                property string themeName: themeData && themeData.name ? themeData.name : modelData
                
                scale: PathView.itemScale !== undefined ? PathView.itemScale : 0.6
                opacity: PathView.itemOpacity !== undefined ? PathView.itemOpacity : 0.35
                z: PathView.itemZ !== undefined ? PathView.itemZ : 0
                
                rotation: isHovered && !isCurrent ? (cardMouse.mouseX - width/2) * 0.02 : 0
                Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                
                Rectangle {
                    id: card
                    anchors.fill: parent
                    radius: 18
                    color: surfColor
                    border.width: isCurrent ? 2 : 0
                    border.color: tAccentColor
                    clip: true
                    
                    Behavior on border.width { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                    Behavior on border.color { ColorAnimation { duration: 280; easing.type: Easing.OutQuint } }
                    
                    scale: isCurrent ? 1.0 : 1.0
                    Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.InOutSine } }
                    
                    SequentialAnimation on scale {
                        running: isCurrent && root.active
                        loops: Animation.Infinite
                        
                        NumberAnimation { from: 1.0; to: 1.015; duration: 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.015; to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                    }
                    
                    Rectangle {
                        id: previewArea
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        height: parent.height * 0.48
                        radius: 12
                        color: bgColor
                        clip: true

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 26
                            color: surfColor

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5

                                Repeater {
                                    model: 3
                                    delegate: Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: index === 0 ? tAccentColor : Qt.rgba(1, 1, 1, 0.15)
                                        
                                        opacity: 0
                                        scale: 0.5
                                        
                                        Component.onCompleted: {
                                            appearAnimation.start()
                                        }
                                        
                                        ParallelAnimation {
                                            id: appearAnimation
                                            
                                            NumberAnimation { 
                                                target: parent
                                                property: "opacity"
                                                to: 1
                                                duration: 350
                                                easing.type: Easing.OutQuint
                                            }
                                            
                                            NumberAnimation { 
                                                target: parent
                                                property: "scale"
                                                to: 1
                                                duration: 400
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 1.5
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.top: parent.top
                            anchors.topMargin: 38
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 12
                            spacing: 8

                            Rectangle {
                                width: parent.width * 0.7
                                height: 10
                                radius: 5
                                color: tTextColor
                                opacity: 0.9
                            }

                            Rectangle {
                                width: parent.width * 0.5
                                height: 8
                                radius: 4
                                color: tTextSecColor
                                opacity: 0.5
                            }

                            Rectangle {
                                id: buttonPreview
                                width: 60
                                height: 22
                                radius: 11
                                color: tAccentColor
                                
                                scale: 1.0
                                SequentialAnimation on scale {
                                    running: isCurrent && root.active
                                    loops: Animation.Infinite
                                    
                                    NumberAnimation { from: 1.0; to: 1.05; duration: 1400; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1.05; to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "Button"
                                    color: "#000000"
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                        
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 3
                            color: tAccentColor
                            opacity: 0.8
                        }
                    }

                    Text {
                        id: themeNameText
                        anchors.top: previewArea.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 5
                        text: themeName
                        color: tTextColor
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.family: "JetBrains Mono"
                        
                        opacity: isCurrent ? 1 : 0.7
                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                    }

                    Row {
                        anchors.top: themeNameText.bottom
                        anchors.topMargin: 5
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Repeater {
                            model: themeData && themeData.colors ? 
                                [bgColor, surfColor, tAccentColor, tTextColor] : []
                            delegate: Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: modelData
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                
                                scale: isHovered ? 1.1 : 1.0
                                Behavior on scale { 
                                    NumberAnimation { 
                                        duration: 250
                                        easing.type: Easing.OutQuint
                                        easing.overshoot: 1.3
                                    } 
                                }
                            }
                        }
                    }
                    
                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            if (isCurrent) {
                                // ИСПРАВЛЕНО: Прямое применение темы через themeManager
                                if (root.themeManager) {
                                    root.themeManager.loadTheme(modelData)
                                }
                                if (root.soundManager) root.soundManager.play("out.wav")
                                root.close()
                            } else {
                                pathView.currentIndex = index
                            }
                        }
                        
                        onPressedChanged: {
                            if (isCurrent) {
                                card.scale = pressed ? 0.98 : 1.0
                            }
                        }
                    }
                }
            }
            
            onCurrentIndexChanged: {
                root.currentIndex = currentIndex
                if (root.isFirstChange) {
                    root.isFirstChange = false
                    return
                }
                if (root.soundManager) root.soundManager.play("click.wav")
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: pathView.top
            anchors.bottom: pathView.bottom
            width: 80
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#000000" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        
        Rectangle {
            anchors.right: parent.right
            anchors.top: pathView.top
            anchors.bottom: pathView.bottom
            width: 80
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: "#000000" }
            }
        }

        Text {
            id: leftArrow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 28
            text: "\uf060"
            color: root.textColor
            font.pixelSize: 22
            font.family: "CaskaydiaCove Nerd Font"
            opacity: leftMouse.containsMouse ? 1 : 0.4
            x: leftMouse.containsMouse ? -3 : 0
            scale: leftMouse.pressed ? 0.9 : 1.0
            
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }
            
            MouseArea {
                id: leftMouse
                anchors.fill: parent
                anchors.margins: -12
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pathView.decrementCurrentIndex()
            }
        }

        Text {
            id: rightArrow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 28
            text: "\uf061"
            color: root.textColor
            font.pixelSize: 22
            font.family: "CaskaydiaCove Nerd Font"
            opacity: rightMouse.containsMouse ? 1 : 0.4
            x: rightMouse.containsMouse ? 3 : 0
            scale: rightMouse.pressed ? 0.9 : 1.0
            
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }
            
            MouseArea {
                id: rightMouse
                anchors.fill: parent
                anchors.margins: -12
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pathView.incrementCurrentIndex()
            }
        }

        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 26
            spacing: 8
            
            opacity: active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
            
            Repeater {
                model: Math.min(root.themesList.length, 10)
                delegate: Rectangle {
                    property bool isActive: index === root.currentIndex
                    width: isActive ? 18 : 6
                    height: 6
                    radius: 3
                    color: isActive ? root.accentColor : Qt.rgba(1, 1, 1, 0.25)
                    
                    Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.OutQuint } }
                    
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pathView.currentIndex = index
                    }
                }
            }
        }
    }

    function navigateLeft() { pathView.decrementCurrentIndex() }
    function navigateRight() { pathView.incrementCurrentIndex() }
    
    function applyCurrent() {
        // ИСПРАВЛЕНО: Прямое применение темы через themeManager
        if (themesList.length > 0 && root.themeManager) {
            var fileName = themesList[currentIndex]
            root.themeManager.loadTheme(fileName)
            if (soundManager) soundManager.play("out.wav")
            close()
        }
    }
}