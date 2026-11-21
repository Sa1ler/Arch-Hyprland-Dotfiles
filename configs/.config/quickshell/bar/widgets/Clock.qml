import QtQuick

Item {
    id: root

    property var theme: null
    property var soundManager: null

    readonly property color textColor: root.theme && root.theme.colors ? root.theme.colors.text : "#FFFFFF"

    property string currentTime: ""

    implicitWidth: timeText.implicitWidth
    implicitHeight: timeText.implicitHeight

    Component.onCompleted: updateTime()

    function updateTime() {
        var now = new Date()
        var h = now.getHours()
        var m = now.getMinutes()
        currentTime = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
    }

    Text {
        id: timeText
        anchors.centerIn: parent
        text: root.currentTime
        color: root.textColor
        font.pixelSize: 17
        font.weight: Font.Black
        font.family: "Inter"
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.updateTime()
    }
}