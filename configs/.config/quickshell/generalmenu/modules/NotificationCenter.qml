import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../notifications"

Item {
    id: root

    property var notificationList: null
    property var theme: null
    property var soundPlayer: null

    signal requestClose(var notification)
    signal requestClear()

    readonly property int outerRadius: 18
    readonly property int contentPadding: 16
    readonly property int sectionSpacing: 12
    readonly property int cardSpacing: 10

    readonly property color surfaceColor:
        theme && theme.colors && theme.colors.surface
            ? theme.colors.surface : "#1A1F26"
    readonly property color borderColor:
        theme && theme.colors && theme.colors.border
            ? theme.colors.border : "#2A323D"
    readonly property color accentColor:
        theme && theme.colors && theme.colors.accent
            ? theme.colors.accent : "#5B9BFF"
    readonly property color selectedSurfaceColor:
        theme && theme.colors && theme.colors.surfaceSelected
            ? theme.colors.surfaceSelected : "#2C3A50"
    readonly property color primaryTextColor:
        theme && theme.colors && theme.colors.text
            ? theme.colors.text : "#F0F4F8"
    readonly property color secondaryTextColor:
        theme && theme.colors && theme.colors.textSecondary
            ? theme.colors.textSecondary : "#9AA9B9"
    readonly property color disabledTextColor:
        theme && theme.colors && theme.colors.textDisabled
            ? theme.colors.textDisabled : "#5A6675"

    readonly property int notificationCount:
        notificationList && notificationList.count !== undefined
            ? notificationList.count : 0

    implicitWidth: 300
    implicitHeight: 280

    Rectangle {
        id: mainBlock

        anchors.fill: parent
        radius: root.outerRadius
        color: root.surfaceColor
        border.width: 1
        border.color: root.borderColor
        clip: true
        antialiasing: true

        ColumnLayout {
            id: contentLayout

            anchors.fill: parent
            anchors.margins: root.contentPadding
            spacing: root.sectionSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: "Уведомления"
                        color: root.primaryTextColor
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            Layout.alignment: Qt.AlignVCenter
                            radius: 3
                            color: root.notificationCount > 0
                                   ? root.accentColor : root.disabledTextColor
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.notificationCount > 0
                                  ? root.notificationCount + " новых"
                                  : "Всё прочитано"
                            color: root.secondaryTextColor
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                Rectangle {
                    id: clearButton

                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.notificationCount > 0
                    radius: 12

                    readonly property bool hovered: clearMouseArea.containsMouse
                    readonly property bool pressed: clearMouseArea.pressed

                    color: pressed
                           ? Qt.alpha("#FF453A", 0.22)
                           : hovered ? Qt.alpha("#FF453A", 0.12) : "transparent"
                    border.width: hovered ? 1 : 0
                    border.color: Qt.alpha("#FF453A", hovered ? 0.45 : 0.0)
                    scale: pressed ? 0.94 : (hovered ? 1.04 : 1.0)

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰆴"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 17
                        color: clearButton.hovered || clearButton.pressed
                               ? "#FF6259" : root.secondaryTextColor

                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    MouseArea {
                        id: clearMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.soundPlayer)
                                root.soundPlayer.play("click.wav")
                            root.requestClear()
                        }
                    }

                    Accessible.name: "Очистить уведомления"
                    Accessible.role: Accessible.Button
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.borderColor
                opacity: 0.65
            }

            Item {
                id: listContainer

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Flickable {
                    id: flickable

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: notifColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    interactive: root.notificationCount > 0
                    visible: root.notificationCount > 0

                    Column {
                        id: notifColumn

                        width: flickable.width - (verticalScrollBar.visible ? verticalScrollBar.width + 6 : 0)
                        spacing: root.cardSpacing

                        Repeater {
                            model: root.notificationList

                            delegate: NotificationCard {
                                required property var modelData

                                width: notifColumn.width
                                notification: modelData && modelData.notification !== undefined
                                             ? modelData.notification : modelData
                                theme: root.theme
                                autoClose: false

                                onClosed: {
                                    if (root.soundPlayer)
                                        root.soundPlayer.play("tick.wav")
                                    root.requestClose(notification)
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        id: verticalScrollBar

                        policy: ScrollBar.AsNeeded
                        width: 6
                        visible: flickable.contentHeight > flickable.height

                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: root.accentColor
                            opacity: verticalScrollBar.pressed ? 0.95 : 0.55

                            Behavior on opacity {
                                NumberAnimation { duration: 140 }
                            }
                        }

                        background: Rectangle {
                            radius: 3
                            color: root.selectedSurfaceColor
                            opacity: 0.25
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.notificationCount === 0

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: 54
                            height: 54
                            anchors.horizontalCenter: parent.horizontalCenter
                            radius: 18
                            color: root.selectedSurfaceColor
                            opacity: 0.7

                            Text {
                                anchors.centerIn: parent
                                text: "󰂚"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 27
                                color: root.secondaryTextColor
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            text: "Нет новых уведомлений"
                            color: root.primaryTextColor
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            text: "Здесь появятся новые события"
                            color: root.disabledTextColor
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
}
