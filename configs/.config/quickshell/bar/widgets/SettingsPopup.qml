import QtQuick
import Quickshell.Io

Item {
    id: root

    property var theme: null
    property var soundManager: null
    property var settingsManager: null
    property bool active: false

    signal close()

    readonly property color textColor:
        theme && theme.colors ? theme.colors.text : "#FFFFFF"

    readonly property color accentColor:
        theme && theme.colors ? theme.colors.accent : "#8EA8FF"

    readonly property color mutedColor: Qt.rgba(1, 1, 1, 0.48)
    readonly property color lineColor: Qt.rgba(1, 1, 1, 0.075)
    readonly property color surfaceColor: Qt.rgba(1, 1, 1, 0.045)

    // === Алиасы настроек из SettingsManager ===
    readonly property bool cfgEnabled: settingsManager ? settingsManager.island.enabled : true
    readonly property string cfgShape: settingsManager ? settingsManager.island.shape : "capsule"
    readonly property int cfgLength: settingsManager ? settingsManager.island.length : 220
    readonly property int cfgHeight: settingsManager ? settingsManager.island.height : 34
    readonly property int cfgMargin: settingsManager ? settingsManager.island.margin : 4
    readonly property bool cfgWorkspaces: settingsManager && settingsManager.island.indicators ? settingsManager.island.indicators.workspaces : true
    readonly property bool cfgNetwork: settingsManager && settingsManager.island.indicators ? settingsManager.island.indicators.network : true
    readonly property bool cfgBattery: settingsManager && settingsManager.island.indicators ? settingsManager.island.indicators.battery : true
    readonly property bool cfgClock: settingsManager && settingsManager.island.indicators ? settingsManager.island.indicators.clock : true

    function click() {
        if (soundManager)
            soundManager.play("click.wav")
    }

    function accent(alpha) {
        return Qt.rgba(
            accentColor.r,
            accentColor.g,
            accentColor.b,
            alpha
        )
    }

    // =========================================================
    // ICONS — DRAWN WITH QTQUICK
    // =========================================================

    component Icon: Item {
        id: iconRoot

        property string name: "clock"
        property color color: "#FFFFFF"
        property real size: 22

        implicitWidth: size
        implicitHeight: size

        // Workspace grid
        Grid {
            visible: iconRoot.name === "workspaces"

            anchors.centerIn: parent

            columns: 2
            spacing: 3

            Repeater {
                model: 4

                Rectangle {
                    width: iconRoot.size * 0.31
                    height: iconRoot.size * 0.31

                    radius: 2

                    color: iconRoot.color

                    opacity: index === 0 ? 1 : 0.55
                }
            }
        }

        // Network signal
        Item {
            visible: iconRoot.name === "network"

            anchors.centerIn: parent

            width: iconRoot.size
            height: iconRoot.size

            Repeater {
                model: 3

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom

                    width: 4
                    height: (index + 1) * iconRoot.size * 0.23

                    radius: 2

                    x: (index - 1) * iconRoot.size * 0.27

                    color: iconRoot.color
                    opacity: 0.45 + index * 0.25
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom

                width: 4
                height: 4

                radius: 2
                color: iconRoot.color
            }
        }

        // Battery
        Item {
            visible: iconRoot.name === "battery"

            anchors.centerIn: parent

            width: iconRoot.size * 0.83
            height: iconRoot.size * 0.46

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                width: parent.width - 3
                height: parent.height

                radius: 3

                color: "transparent"

                border.width: 1.8
                border.color: iconRoot.color

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 3

                    anchors.verticalCenter: parent.verticalCenter

                    width: parent.width * 0.56
                    height: parent.height * 0.48

                    radius: 1.5

                    color: iconRoot.color
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                width: 3
                height: parent.height * 0.38

                radius: 1

                color: iconRoot.color
            }
        }

        // Clock
        Item {
            visible: iconRoot.name === "clock"

            anchors.centerIn: parent

            width: iconRoot.size * 0.82
            height: iconRoot.size * 0.82

            Rectangle {
                anchors.fill: parent

                radius: width / 2

                color: "transparent"

                border.width: 1.8
                border.color: iconRoot.color
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter

                y: parent.height * 0.2

                width: 2
                height: parent.height * 0.32

                radius: 1

                color: iconRoot.color
            }

            Rectangle {
                x: parent.width * 0.49
                y: parent.height * 0.48

                width: parent.width * 0.28
                height: 2

                radius: 1

                color: iconRoot.color

                rotation: 30
                transformOrigin: Item.Left
            }
        }
    }

    // =========================================================
    // SWITCH
    // =========================================================

    component Toggle: Item {
        id: sw

        property bool checked: false
        property color accent: "#8EA8FF"

        signal toggled()

        implicitWidth: 42
        implicitHeight: 25

        Rectangle {
            anchors.fill: parent

            radius: height / 2

            color: sw.checked
                ? Qt.rgba(
                    sw.accent.r,
                    sw.accent.g,
                    sw.accent.b,
                    0.9
                )
                : Qt.rgba(1, 1, 1, 0.13)

            Behavior on color {
                ColorAnimation { duration: 130 }
            }

            Rectangle {
                width: 17
                height: 17

                radius: 9

                y: 4
                x: sw.checked ? parent.width - width - 4 : 4

                color: "#FFFFFF"

                Behavior on x {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent

            cursorShape: Qt.PointingHandCursor

            onClicked: sw.toggled()
        }
    }

    // =========================================================
    // SECTION HEADING
    // =========================================================

    component SectionTitle: Item {
        id: heading

        property string text: ""
        property string detail: ""

        property color foreground: "#FFFFFF"
        property color muted: "#888888"

        implicitHeight: 21

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            text: heading.text

            color: heading.foreground

            font.family: "Sans Serif"
            font.pixelSize: 12
            font.weight: Font.Bold

            font.letterSpacing: 0.45
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: heading.detail

            color: heading.muted

            font.family: "Sans Serif"
            font.pixelSize: 10
            font.weight: Font.Medium
        }
    }

    // =========================================================
    // SHAPE SELECTOR
    // =========================================================

    component ShapeCard: Rectangle {
        id: shapeCard

        property string label: ""
        property string shape: "capsule"
        property bool selected: false

        property color accent: "#8EA8FF"
        property color foreground: "#FFFFFF"
        property color muted: "#888888"

        signal chosen()

        implicitHeight: 59

        radius: 13

        color: selected
            ? Qt.rgba(
                accent.r,
                accent.g,
                accent.b,
                0.13
            )
            : Qt.rgba(1, 1, 1, 0.035)

        border.width: 1

        border.color: selected
            ? Qt.rgba(
                accent.r,
                accent.g,
                accent.b,
                0.6
            )
            : Qt.rgba(1, 1, 1, 0.07)

        Behavior on color {
            ColorAnimation { duration: 130 }
        }

        Item {
            id: graphic

            anchors.left: parent.left
            anchors.leftMargin: 11

            anchors.verticalCenter: parent.verticalCenter

            width: 43
            height: 35

            Rectangle {
                anchors.fill: parent

                radius: 9

                color: Qt.rgba(0, 0, 0, 0.2)
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter

                y: shapeCard.shape === "capsule" ? 11 : 0

                width: shapeCard.shape === "capsule" ? 30 : 29
                height: shapeCard.shape === "capsule" ? 10 : 15

                radius: shapeCard.shape === "capsule" ? 5 : 4

                color: "#050608"

                border.width: 1
                border.color: shapeCard.selected
                    ? shapeCard.accent
                    : Qt.rgba(1, 1, 1, 0.22)

                Rectangle {
                    visible: shapeCard.shape === "notch"

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 11
                    height: 4

                    radius: 2
                    color: "#050608"
                }
            }
        }

        Text {
            anchors.left: graphic.right
            anchors.leftMargin: 9

            anchors.verticalCenter: parent.verticalCenter

            text: shapeCard.label

            color: shapeCard.foreground

            font.family: "Sans Serif"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 10

            anchors.verticalCenter: parent.verticalCenter

            width: 17
            height: 17

            radius: 9

            color: shapeCard.selected
                ? shapeCard.accent
                : "transparent"

            border.width: shapeCard.selected ? 0 : 1
            border.color: Qt.rgba(1, 1, 1, 0.17)

            Text {
                anchors.centerIn: parent

                visible: shapeCard.selected

                text: "✓"

                color: "#11141B"

                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        MouseArea {
            anchors.fill: parent

            cursorShape: Qt.PointingHandCursor

            onClicked: shapeCard.chosen()
        }
    }

    // =========================================================
    // DIMENSION CONTROL
    // =========================================================

    component Dimension: Rectangle {
        id: dimension

        property string label: ""

        property int from: 0
        property int to: 100
        property int value: 50
        property int defaultValue: 50

        property color accent: "#8EA8FF"
        property color foreground: "#FFFFFF"
        property color muted: "#888888"

        signal valueEdited(int nextValue)
        signal resetRequested()

        implicitHeight: 47

        radius: 12

        color: Qt.rgba(1, 1, 1, 0.035)

        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.055)

        Row {
            anchors.fill: parent

            anchors.leftMargin: 12
            anchors.rightMargin: 8

            spacing: 5

            Text {
                width: 56

                anchors.verticalCenter: parent.verticalCenter

                text: dimension.label

                color: dimension.foreground

                font.family: "Sans Serif"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Item {
                width: 1
                height: 23

                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    color: root.lineColor
                }
            }

            Item {
                width: parent.width - 56 - 1 - 5
                height: parent.height

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 7

                    Rectangle {
                        width: 29
                        height: 29

                        radius: 9

                        color: minusArea.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.13)
                            : Qt.rgba(1, 1, 1, 0.055)

                        Text {
                            anchors.centerIn: parent

                            text: "−"

                            color: dimension.foreground

                            font.family: "Sans Serif"
                            font.pixelSize: 20
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: minusArea

                            anchors.fill: parent

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                dimension.valueEdited(
                                    Math.max(
                                        dimension.from,
                                        dimension.value - 1
                                    )
                                )
                            }
                        }
                    }

                    Item {
                        width: 48
                        height: 31

                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: valueText

                            anchors.centerIn: parent

                            visible: !valueInput.visible

                            text: dimension.value

                            color: dimension.foreground

                            font.family: "Sans Serif"
                            font.pixelSize: 20
                            font.weight: Font.DemiBold

                            MouseArea {
                                anchors.fill: parent

                                cursorShape: Qt.IBeamCursor

                                onClicked: {
                                    valueInput.text =
                                        String(dimension.value)

                                    valueInput.visible = true
                                    valueInput.forceActiveFocus()
                                    valueInput.selectAll()
                                }
                            }
                        }

                        TextInput {
                            id: valueInput

                            visible: false

                            anchors.fill: parent

                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            color: dimension.accent

                            font.family: "Sans Serif"
                            font.pixelSize: 19
                            font.weight: Font.DemiBold

                            selectByMouse: true
                            inputMethodHints: Qt.ImhDigitsOnly

                            validator: IntValidator {
                                bottom: dimension.from
                                top: dimension.to
                            }

                            onEditingFinished: {
                                var n = parseInt(text)

                                if (!isNaN(n)) {
                                    dimension.valueEdited(
                                        Math.max(
                                            dimension.from,
                                            Math.min(dimension.to, n)
                                        )
                                    )
                                }

                                visible = false
                            }

                            onActiveFocusChanged: {
                                if (!activeFocus)
                                    visible = false
                            }

                            Keys.onEscapePressed: event => {
                                visible = false
                                event.accepted = true
                            }
                        }
                    }

                    Rectangle {
                        width: 29
                        height: 29

                        radius: 9

                        color: plusArea.containsMouse
                            ? root.accent(0.24)
                            : root.accent(0.13)

                        Text {
                            anchors.centerIn: parent

                            text: "+"

                            color: dimension.accent

                            font.family: "Sans Serif"
                            font.pixelSize: 20
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: plusArea

                            anchors.fill: parent

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                dimension.valueEdited(
                                    Math.min(
                                        dimension.to,
                                        dimension.value + 1
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top

            width: 56
            height: parent.height

            acceptedButtons: Qt.RightButton

            onClicked: dimension.resetRequested()
        }
    }

    // =========================================================
    // INDICATOR TILE
    // =========================================================

    component IndicatorTile: Rectangle {
        id: tile

        property string iconName: "clock"
        property string label: ""
        property bool checked: true

        property color accent: "#8EA8FF"
        property color foreground: "#FFFFFF"
        property color muted: "#888888"

        signal toggled()

        implicitHeight: 53

        radius: 12

        color: checked
            ? Qt.rgba(
                accent.r,
                accent.g,
                accent.b,
                0.085
            )
            : Qt.rgba(1, 1, 1, 0.025)

        border.width: 1

        border.color: checked
            ? Qt.rgba(
                accent.r,
                accent.g,
                accent.b,
                0.26
            )
            : Qt.rgba(1, 1, 1, 0.06)

        Behavior on color {
            ColorAnimation { duration: 130 }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10

            anchors.verticalCenter: parent.verticalCenter

            spacing: 9

            Rectangle {
                width: 32
                height: 32

                radius: 10

                anchors.verticalCenter: parent.verticalCenter

                color: tile.checked
                    ? root.accent(0.17)
                    : Qt.rgba(1, 1, 1, 0.045)

                Icon {
                    anchors.centerIn: parent

                    name: tile.iconName
                    size: 19

                    color: tile.checked
                        ? tile.accent
                        : tile.muted
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: tile.label

                color: tile.checked
                    ? tile.foreground
                    : tile.muted

                font.family: "Sans Serif"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 10

            anchors.verticalCenter: parent.verticalCenter

            width: 7
            height: 7

            radius: 4

            color: tile.checked
                ? tile.accent
                : Qt.rgba(1, 1, 1, 0.15)

            Behavior on color {
                ColorAnimation { duration: 130 }
            }
        }

        MouseArea {
            anchors.fill: parent

            cursorShape: Qt.PointingHandCursor

            onClicked: tile.toggled()
        }
    }

    // =========================================================
    // MAIN LAYOUT
    // =========================================================

    Item {
        id: body

        anchors.fill: parent
        anchors.margins: 12

        opacity: root.active ? 1 : 0
        y: root.active ? 0 : 5

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.fill: parent

            spacing: 8

            // -------------------------------------------------
            // HEADER
            // -------------------------------------------------

            Item {
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 10

                    Rectangle {
                        width: 36
                        height: 36

                        radius: 12

                        anchors.verticalCenter: parent.verticalCenter

                        color: root.accent(0.16)

                        Rectangle {
                            anchors.centerIn: parent

                            width: 23
                            height: 11

                            radius: 6

                            color: root.accentColor

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 4

                                anchors.verticalCenter: parent.verticalCenter

                                width: 3
                                height: 3

                                radius: 2

                                color: "#FFFFFF"
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        spacing: 1

                        Text {
                            text: "Island"

                            color: root.textColor

                            font.family: "Sans Serif"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Внешний вид и модули"

                            color: root.mutedColor

                            font.family: "Sans Serif"
                            font.pixelSize: 11
                        }
                    }
                }

                Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    checked: cfgEnabled
                    accent: root.accentColor

                    onToggled: {
                        root.click()
                        if (root.settingsManager) root.settingsManager.set("island.enabled", !cfgEnabled)
                    }
                }
            }

            // -------------------------------------------------
            // PREVIEW
            // -------------------------------------------------

            Rectangle {
                id: preview

                width: parent.width
                height: 76

                radius: 15

                color: Qt.rgba(1, 1, 1, 0.025)

                border.width: 1
                border.color: root.lineColor

                clip: true

                Repeater {
                    model: 9

                    Rectangle {
                        x: (index + 1) * preview.width / 10

                        width: 1
                        height: preview.height

                        color: Qt.rgba(1, 1, 1, 0.025)
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 1
                    height: parent.height

                    color: Qt.rgba(1, 1, 1, 0.055)
                }

                Item {
                    id: previewArea

                    anchors.fill: parent

                    readonly property real scaleFactor: Math.min(
                        0.85,
                        Math.max(
                            0.2,
                            (width - 48) / Math.max(1, cfgLength)
                        )
                    )

                    Rectangle {
                        id: miniIsland

                        anchors.horizontalCenter: parent.horizontalCenter

                        width: Math.min(
                            previewArea.width - 32,
                            cfgLength * previewArea.scaleFactor
                        )

                        height: Math.max(
                            13,
                            cfgHeight * previewArea.scaleFactor
                        )

                        y: cfgShape === "capsule"
                            ? (parent.height - height) / 2
                            : -height * 0.16

                        radius: cfgShape === "capsule"
                            ? height / 2
                            : Math.min(10, height / 2, width / 2)

                        color: "#050608"

                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)

                        opacity: cfgEnabled ? 1 : 0.3

                        Behavior on width {
                            NumberAnimation {
                                duration: 170
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: 170
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on y {
                            NumberAnimation {
                                duration: 170
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on radius {
                            NumberAnimation { duration: 140 }
                        }

                        Rectangle {
                            visible: cfgShape === "notch"

                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter

                            width: Math.min(30, parent.width * 0.4)
                            height: 5

                            radius: 3

                            color: "#050608"

                            border.width: 1
                            border.color: miniIsland.border.color
                        }

                        Row {
                            anchors.centerIn: parent

                            spacing: 7

                            Row {
                                visible: cfgWorkspaces

                                anchors.verticalCenter: parent.verticalCenter

                                spacing: 2

                                Repeater {
                                    model: 3

                                    Rectangle {
                                        width: index === 0 ? 7 : 3
                                        height: 3

                                        radius: 2

                                        color: index === 0
                                            ? root.accentColor
                                            : Qt.rgba(1, 1, 1, 0.45)
                                    }
                                }
                            }

                            Text {
                                visible: cfgClock

                                anchors.verticalCenter: parent.verticalCenter

                                text: "18:45"

                                color: "#FFFFFF"

                                font.family: "Sans Serif"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                            }

                            Icon {
                                visible: cfgNetwork

                                anchors.verticalCenter: parent.verticalCenter

                                name: "network"
                                size: 10
                                color: "#FFFFFF"
                            }

                            Icon {
                                visible: cfgBattery

                                anchors.verticalCenter: parent.verticalCenter

                                name: "battery"
                                size: 10
                                color: "#FFFFFF"
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    anchors.rightMargin: 9
                    anchors.bottomMargin: 7

                    radius: 6

                    color: Qt.rgba(0, 0, 0, 0.35)

                    width: dimensionText.implicitWidth + 10
                    height: 18

                    Text {
                        id: dimensionText

                        anchors.centerIn: parent

                        text: cfgLength + " × " + cfgHeight

                        color: root.mutedColor

                        font.family: "Sans Serif"
                        font.pixelSize: 9
                        font.weight: Font.Medium
                    }
                }
            }

            // -------------------------------------------------
            // SHAPE
            // -------------------------------------------------

            Column {
                width: parent.width

                spacing: 5

                SectionTitle {
                    width: parent.width

                    text: "Форма"
                    detail: cfgShape === "capsule" ? "КАПСУЛА" : "ВЫРЕЗ"

                    foreground: root.textColor
                    muted: root.accentColor
                }

                Row {
                    width: parent.width

                    spacing: 7

                    ShapeCard {
                        width: (parent.width - parent.spacing) / 2

                        label: "Капсула"
                        shape: "capsule"

                        selected: cfgShape === "capsule"

                        accent: root.accentColor
                        foreground: root.textColor

                        onChosen: {
                            root.click()
                            if (root.settingsManager) root.settingsManager.set("island.shape", "capsule")
                        }
                    }

                    ShapeCard {
                        width: (parent.width - parent.spacing) / 2

                        label: "Вырез"
                        shape: "notch"

                        selected: cfgShape === "notch"

                        accent: root.accentColor
                        foreground: root.textColor

                        onChosen: {
                            root.click()
                            if (root.settingsManager) root.settingsManager.set("island.shape", "notch")
                        }
                    }
                }
            }

            // -------------------------------------------------
            // DIMENSIONS
            // -------------------------------------------------

            Column {
                width: parent.width

                spacing: 5

                SectionTitle {
                    width: parent.width

                    text: "Размеры"
                    detail: "PX"

                    foreground: root.textColor
                    muted: root.mutedColor
                }

                Column {
                    width: parent.width

                    spacing: 5

                    Dimension {
                        width: parent.width

                        label: "Длина"

                        from: 160
                        to: 600

                        value: cfgLength
                        defaultValue: 220

                        accent: root.accentColor
                        foreground: root.textColor

                        onValueEdited: v => { if (root.settingsManager) root.settingsManager.set("island.length", v) }

                        onResetRequested: {
                            root.click()
                            if (root.settingsManager) root.settingsManager.set("island.length", defaultValue)
                        }
                    }

                    Dimension {
                        width: parent.width

                        label: "Высота"

                        from: 24
                        to: 56

                        value: cfgHeight
                        defaultValue: 34

                        accent: root.accentColor
                        foreground: root.textColor

                        onValueEdited: v => { if (root.settingsManager) root.settingsManager.set("island.height", v) }

                        onResetRequested: {
                            root.click()
                            if (root.settingsManager) root.settingsManager.set("island.height", defaultValue)
                        }
                    }

                    Dimension {
                        width: parent.width

                        label: "Отступ"

                        from: 0
                        to: 24

                        value: cfgMargin
                        defaultValue: 4

                        accent: root.accentColor
                        foreground: root.textColor

                        onValueEdited: v => { if (root.settingsManager) root.settingsManager.set("island.margin", v) }

                        onResetRequested: {
                            root.click()
                            if (root.settingsManager) root.settingsManager.set("island.margin", defaultValue)
                        }
                    }
                }
            }

            // -------------------------------------------------
            // INDICATORS
            // -------------------------------------------------

            Column {
                width: parent.width

                spacing: 5

                SectionTitle {
                    width: parent.width

                    text: "Индикаторы"

                    detail: {
                        var count = 0

                        if (cfgWorkspaces) count++
                        if (cfgNetwork) count++
                        if (cfgBattery) count++
                        if (cfgClock) count++

                        return count + " / 4"
                    }

                    foreground: root.textColor
                    muted: root.mutedColor
                }

                Grid {
                    width: parent.width

                    columns: 2
                    spacing: 7

                    IndicatorTile {
                        width: (parent.width - parent.spacing) / 2

                        iconName: "workspaces"
                        label: "Области"

                        checked: cfgWorkspaces

                        accent: root.accentColor
                        foreground: root.textColor
                        muted: root.mutedColor

                        onToggled: {
                            root.click()
                            if (root.settingsManager) root.settingsManager.set("island.indicators.workspaces", !cfgWorkspaces)
                        }
                    }

                    IndicatorTile {
                        width: (parent.width - parent.spacing) / 2

                        iconName: "network"
                        label: "Сеть"

                        checked: cfgNetwork

                        accent: root.accentColor
                        foreground: root.textColor
                        muted: root.mutedColor

                        onToggled: {
                            root.click()
                            if (root.settingsManager) root.settingsManager.set("island.indicators.network", !cfgNetwork)
                        }
                    }

                    IndicatorTile {
                        width: (parent.width - parent.spacing) / 2

                        iconName: "battery"
                        label: "Батарея"

                        checked: cfgBattery

                        accent: root.accentColor
                        foreground: root.textColor
                        muted: root.mutedColor

                        onToggled: {
                            root.click()
                            if (root.settingsManager) root.settingsManager.set("island.indicators.battery", !cfgBattery)
                        }
                    }

                    IndicatorTile {
                        width: (parent.width - parent.spacing) / 2

                        iconName: "clock"
                        label: "Часы"

                        checked: cfgClock

                        accent: root.accentColor
                        foreground: root.textColor
                        muted: root.mutedColor

                        onToggled: {
                            root.click()
                            if (root.settingsManager) root.settingsManager.set("island.indicators.clock", !cfgClock)
                        }
                    }
                }
            }
        }

        // -----------------------------------------------------
        // DISABLED OVERLAY
        // -----------------------------------------------------

        Rectangle {
            anchors.fill: parent

            visible: !cfgEnabled

            color: Qt.rgba(0, 0, 0, 0.76)

            radius: 14

            z: 10

            Column {
                anchors.centerIn: parent

                spacing: 9

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 52
                    height: 52

                    radius: 17

                    color: Qt.rgba(1, 1, 1, 0.07)

                    Text {
                        anchors.centerIn: parent

                        text: "Ⅱ"

                        color: root.textColor

                        font.family: "Sans Serif"
                        font.pixelSize: 26
                        font.weight: Font.Medium
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: "Остров отключён"

                    color: root.textColor

                    font.family: "Sans Serif"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: "Нажми, чтобы включить"

                    color: root.mutedColor

                    font.family: "Sans Serif"
                    font.pixelSize: 12
                }
            }

            MouseArea {
                anchors.fill: parent

                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    root.click()
                    if (root.settingsManager) root.settingsManager.set("island.enabled", true)
                }
            }
        }
    }
}