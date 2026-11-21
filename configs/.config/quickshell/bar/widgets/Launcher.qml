import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var theme: null
    property var soundManager: null
    property var settingsManager: null // <-- Принимаем менеджер настроек
    property bool active: false
    property string searchText: ""
    property string debouncedSearchText: ""
    property var allApps: []
    
    // === Чтение настроек из SettingsManager ===
    readonly property int maxResults: settingsManager && settingsManager.launcher ? settingsManager.launcher.maxResults : 20
    readonly property int searchDebounce: settingsManager && settingsManager.launcher ? settingsManager.launcher.searchDebounce : 100
    readonly property bool showIcons: settingsManager && settingsManager.launcher ? settingsManager.launcher.showIcons : true
    readonly property var usageRanks: settingsManager ? settingsManager.usageRanks : ({})
    
    // === Кэширование цветов темы ===
    readonly property color textColor: root.theme && root.theme.colors ? root.theme.colors.text : "#FFFFFF"
    readonly property color textSecondaryColor: root.theme && root.theme.colors ? root.theme.colors.textSecondary : "#AAAAAA"
    readonly property color textDisabledColor: root.theme && root.theme.colors ? root.theme.colors.textDisabled : "#666666"
    readonly property color accentColor: root.theme && root.theme.colors ? root.theme.colors.accent : "#5B9BFF"
    readonly property color borderColor: root.theme && root.theme.colors ? root.theme.colors.border : "#333333"
    readonly property color surfaceHoverColor: root.theme && root.theme.colors ? root.theme.colors.surfaceHover : "#1A1A1A"
    
    signal close()

    // === Плавные анимации ===
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.92
    y: active ? 0 : -25
    
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }
    Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }

    // === Debounce для поиска ===
    Timer {
        id: searchDebounceTimer
        interval: root.searchDebounce
        onTriggered: debouncedSearchText = searchText
    }
    
    onSearchTextChanged: searchDebounceTimer.restart()

    // === Оптимизированная фильтрация с учетом usage-ranks ===
    property var filteredApps: {
        var q = debouncedSearchText.toLowerCase().trim()
        var result = []
        var ranks = root.usageRanks || {}
        
        if (q.length === 0) {
            // Если нет поиска, показываем топ-N по usage
            var sortedByUsage = allApps.slice().sort(function(a, b) {
                var scoreA = (ranks[a.name] || 0)
                var scoreB = (ranks[b.name] || 0)
                if (scoreB !== scoreA) return scoreB - scoreA
                return a.name.localeCompare(b.name)
            })
            return sortedByUsage.slice(0, root.maxResults)
        }
        
        for (var i = 0; i < allApps.length; i++) {
            var app = allApps[i]
            var nameLower = app.name.toLowerCase()
            
            var matchScore = 0
            var matches = false
            
            if (nameLower === q) {
                matchScore = 100000
                matches = true
            } else if (nameLower.startsWith(q)) {
                matchScore = 50000
                matches = true
            } else if (nameLower.indexOf(q) !== -1) {
                matchScore = 10000
                matches = true
            } else if (isSubsequence(q, nameLower)) {
                matchScore = 1000
                matches = true
            }
            
            if (matches) {
                var appCopy = Object.assign({}, app)
                appCopy.matchScore = matchScore + (ranks[app.name] || 0) * 100
                result.push(appCopy)
                if (result.length >= root.maxResults) break
            }
        }
        
        result.sort(function(a, b) {
            if (a.matchScore !== b.matchScore) return b.matchScore - a.matchScore
            return a.name.localeCompare(b.name)
        })
        
        return result.slice(0, root.maxResults)
    }

    function isSubsequence(sub, str) {
        var i = 0, j = 0
        while (i < sub.length && j < str.length) {
            if (sub[i] === str[j]) i++
            j++
        }
        return i === sub.length
    }

    Process {
        id: loadApps
        command: ["sh", "-c", "for f in /usr/share/applications/*.desktop ~/.local/share/applications/*.desktop; do [ -f \"$f\" ] && name=$(grep -m1 '^Name=' \"$f\" 2>/dev/null | cut -d= -f2-) && [ -n \"$name\" ] && nodisplay=$(grep -m1 '^NoDisplay=' \"$f\" 2>/dev/null | cut -d= -f2-) && [ \"$nodisplay\" != \"true\" ] && exec_cmd=$(grep -m1 '^Exec=' \"$f\" 2>/dev/null | cut -d= -f2- | sed 's/%[uUfFdD]//g') && icon=$(grep -m1 '^Icon=' \"$f\" 2>/dev/null | cut -d= -f2-) && echo \"$name|$icon|$exec_cmd\"; done 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split('\n').filter(function(l) { return l.length > 0 })
                var apps = []
                var unique = {}
                
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split('|')
                    if (parts.length >= 3 && parts[0] !== "") {
                        var appName = parts[0]
                        if (unique[appName]) continue
                        unique[appName] = true
                        
                        apps.push({
                            name: appName,
                            icon: parts[1] || "",
                            exec: parts[2],
                            usageScore: 0
                        })
                    }
                }
                
                apps.sort(function(a, b) { return a.name.localeCompare(b.name) })
                root.allApps = apps
            }
        }
    }

    onActiveChanged: {
        if (active) {
            searchText = ""
            debouncedSearchText = ""
            if (searchInput) searchInput.text = ""
            
            if (allApps.length === 0) {
                loadApps.running = true
            }
            focusTimer.restart()
        }
    }

    Timer {
        id: focusTimer
        interval: 150
        onTriggered: {
            if (searchInput) searchInput.forceActiveFocus()
        }
    }

    // === ЧЁРНЫЙ ФОН ===
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

        Keys.onEscapePressed: function(event) {
            if (searchInput && searchInput.text !== "") {
                searchInput.text = ""
            } else {
                root.close()
            }
            event.accepted = true
        }
        
        Keys.onReturnPressed: function(event) {
            activateIndex(appsListView.currentIndex)
            event.accepted = true
        }
        
        Keys.onDownPressed: function(event) {
            appsListView.keyboardNavigation = true
            if (appsListView.currentIndex < appsListView.count - 1) {
                appsListView.currentIndex++
                if (root.soundManager) root.soundManager.play("click.wav")
            }
            event.accepted = true
        }
        
        Keys.onUpPressed: function(event) {
            appsListView.keyboardNavigation = true
            if (appsListView.currentIndex > 0) {
                appsListView.currentIndex--
                if (root.soundManager) root.soundManager.play("click.wav")
            }
            event.accepted = true
        }

        // === Поиск ===
        Rectangle {
            id: searchBox
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            height: 48
            radius: 14
            color: "#111111"
            border.width: searchInput && searchInput.activeFocus ? 2 : 1
            border.color: searchInput && searchInput.activeFocus ? root.accentColor : root.borderColor
            
            Behavior on border.color { ColorAnimation { duration: 250; easing.type: Easing.OutQuint } }
            Behavior on border.width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: "transparent"
                border.width: 4
                border.color: root.accentColor
                opacity: searchInput && searchInput.activeFocus ? 0.2 : 0
                
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
            }
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10
                
                TextInput {
                    id: searchInput
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                    color: root.textColor
                    font.pixelSize: 15
                    clip: true
                    selectByMouse: true
                    
                    onTextChanged: {
                        root.searchText = text
                        if (appsListView.count > 0) {
                            appsListView.currentIndex = 0
                            appsListView.keyboardNavigation = false
                        }
                    }
                    
                    Text {
                        anchors.fill: parent
                        text: "Search apps..."
                        color: root.textDisabledColor
                        font.pixelSize: 14
                        visible: searchInput.text === ""
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: clearMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text !== ""
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    scale: clearMouse.pressed ? 0.9 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: root.textSecondaryColor
                        font.pixelSize: 12
                    }
                    
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            searchInput.forceActiveFocus()
                        }
                    }
                }
            }
        }
        
        // === Список приложений ===
        Item {
            id: listContainer
            anchors.top: searchBox.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            anchors.topMargin: 6
            clip: true
            
            ListView {
                id: appsListView
                anchors.fill: parent
                clip: true
                model: root.filteredApps
                currentIndex: 0
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                
                property bool keyboardNavigation: false
                
                highlightFollowsCurrentItem: true
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: height * 0.35
                preferredHighlightEnd: height * 0.65
                highlightMoveDuration: 300
                highlightMoveVelocity: -1
                
                // === Морфинг-хайлайт ===
                Rectangle {
                    id: morphHighlight
                    parent: appsListView.contentItem
                    z: 0
                    visible: appsListView.count > 0 && appsListView.currentIndex >= 0 && opacity > 0.001
                    opacity: (appsListView.count > 0 && appsListView.currentIndex >= 0 && appsListView.currentItem !== null) ? 1.0 : 0.0
                    
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                    
                    x: 2
                    width: appsListView.width - 4
                    height: 42
                    radius: 12
                    
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.accentColor }
                        GradientStop { position: 1.0; color: Qt.lighter(root.accentColor, 1.15) }
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        radius: 14
                        color: "transparent"
                        border.width: 2
                        border.color: root.accentColor
                        opacity: 0.25
                    }
                    
                    property real targetY: (appsListView.currentIndex >= 0 && appsListView.currentItem) ? appsListView.currentItem.y : 0
                    y: targetY
                    
                    Behavior on y {
                        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
                    }
                    
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * 0.6
                        radius: 12
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                }
                
                // === Плавные переходы ===
                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutQuint }
                    NumberAnimation { property: "y"; from: 15; duration: 350; easing.type: Easing.OutQuint }
                    NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 350; easing.type: Easing.OutQuint }
                }
                
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 200; easing.type: Easing.InQuint }
                    NumberAnimation { property: "scale"; to: 0.95; duration: 200; easing.type: Easing.InQuint }
                }
                
                displaced: Transition {
                    NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.OutQuint }
                }
                
                move: Transition {
                    NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.OutQuint }
                }
                
                delegate: Item {
                    id: delegateRoot
                    width: ListView.view ? ListView.view.width : 0
                    height: 42
                    clip: true
                    z: 1
                    
                    property bool isSelected: index === appsListView.currentIndex
                    property bool isHovered: ma.containsMouse && !isSelected
                    
                    Item {
                        id: delegateContent
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        
                        scale: ma.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }
                        
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -10
                            radius: 8
                            color: root.surfaceHoverColor
                            opacity: isHovered ? 0.5 : 0
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                        }
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: delegateRoot.isSelected ? 4 : 0
                            spacing: 12
                            Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            
                            // Точка-индикатор
                            Rectangle {
                                width: 4
                                height: 18
                                radius: 2
                                color: "#FFF"
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: delegateRoot.isSelected ? 1 : 0
                                scale: delegateRoot.isSelected ? 1 : 0
                                
                                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: "#FFF"
                                    opacity: 0.3
                                    visible: delegateRoot.isSelected
                                }
                            }
                            
                            // Иконка
                            Rectangle {
                                width: 30
                                height: 30
                                radius: 10
                                color: delegateRoot.isSelected ? Qt.rgba(1, 1, 1, 0.15) : "#1A1A1A"
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                
                                Image {
                                    id: delegateIcon
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    sourceSize: Qt.size(30, 30)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    cache: true
                                    
                                    property bool loadFailed: false
                                    
                                    source: {
                                        var ic = modelData.icon || ""
                                        if (!ic) { loadFailed = true; return "" }
                                        if (ic.indexOf("/") === 0) return "file://" + ic
                                        if (ic.indexOf("file://") === 0 || ic.indexOf("image://") === 0) return ic
                                        return "image://icon/" + ic
                                    }
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error || status === Image.Null) loadFailed = true
                                        else if (status === Image.Ready) loadFailed = false
                                    }
                                    
                                    visible: root.showIcons && !loadFailed && source !== "" && status === Image.Ready
                                    scale: delegateRoot.isSelected ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
                                }
                                
                                // Fallback текст
                                Text {
                                    anchors.centerIn: parent
                                    visible: !root.showIcons || delegateIcon.loadFailed || delegateIcon.source === ""
                                    text: modelData.name ? modelData.name.charAt(0).toUpperCase() : ""
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: delegateRoot.isSelected ? "#000000" : root.textSecondaryColor
                                    Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                }
                            }
                            
                            // Название приложения
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 44
                                text: modelData.name
                                font.pixelSize: 14
                                font.bold: delegateRoot.isSelected
                                color: delegateRoot.isSelected ? "#000000" : root.textColor
                                elide: Text.ElideRight
                                opacity: isHovered && !isSelected ? 0.8 : 1.0
                                
                                Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                            }
                        }
                        
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                appsListView.keyboardNavigation = false
                                appsListView.currentIndex = index
                                activateIndex(index)
                            }
                            
                            onContainsMouseChanged: {
                                if (containsMouse && !appsListView.keyboardNavigation) {
                                    appsListView.currentIndex = index
                                }
                            }
                            
                            onPositionChanged: {
                                appsListView.keyboardNavigation = false
                            }
                        }
                    }
                }
                
                // === Пустое состояние ===
                Column {
                    anchors.centerIn: parent
                    visible: appsListView.count === 0
                    spacing: 12
                    
                    scale: visible ? 1 : 0.9
                    opacity: visible ? 1 : 0
                    
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                    
                    Rectangle {
                        width: 80
                        height: 80
                        radius: 40
                        color: "#1A1A1A"
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: "\uf002"
                            color: root.textDisabledColor
                            font.pixelSize: 36
                            font.family: "Font Awesome 6 Free Solid"
                            opacity: 0.5
                        }
                    }
                    
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Nothing found"
                            color: root.textColor
                            font.pixelSize: 15
                            font.bold: true
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Try different keywords"
                            color: root.textSecondaryColor
                            font.pixelSize: 12
                        }
                    }
                }
                
                // === Скроллбар ===
                ScrollBar.vertical: ScrollBar {
                    id: vbar
                    width: 6
                    policy: ScrollBar.AsNeeded
                    hoverEnabled: true

                    contentItem: Rectangle {
                        radius: 3
                        color: vbar.pressed || vbar.hovered ? root.accentColor : root.surfaceHoverColor
                        opacity: vbar.pressed || vbar.hovered ? 0.9 : 0.6

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        scale: vbar.pressed || vbar.hovered ? 1.2 : 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                    }
                }
            }
        }
    }

    // === Запуск приложения ===
    function activateIndex(index) {
        if (index < 0 || index >= filteredApps.length) return
        var item = filteredApps[index]
        if (!item) return
        
        // Логируем запуск и сохраняем через SettingsManager
        root.logLaunch(item.name)
        
        Quickshell.execDetached(["sh", "-c", item.exec + " &"])
        if (soundManager) soundManager.play("out.wav")
        close()
    }

    // Увеличиваем счётчик запусков и делегируем сохранение менеджеру
    function logLaunch(appName) {
        if (root.settingsManager) {
            root.settingsManager.bumpAppUsage(appName)
        }
        console.log("[Launcher] Launch logged:", appName)
    }

    function navigateUp() {
        if (appsListView.currentIndex > 0) {
            appsListView.keyboardNavigation = true
            appsListView.currentIndex--
        }
    }
    
    function navigateDown() {
        if (appsListView.currentIndex < appsListView.count - 1) {
            appsListView.keyboardNavigation = true
            appsListView.currentIndex++
        }
    }
    
    function applyCurrent() {
        activateIndex(appsListView.currentIndex)
    }
}