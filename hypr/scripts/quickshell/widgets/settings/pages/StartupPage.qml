pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../parts"
import "../../../core"

// Hyprland açılışında çalışacak komutlar. settings.json -> "startup" dizisi,
// oradan settings_watcher.sh ile autostart.conf'a `exec-once = ...` satırları.
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0

    readonly property bool hasSave: true
    property bool dirty: false

    function s(v) { return Math.round(v * page.sf); }

    function save() {
        let arr = [];
        for (let i = 0; i < items.count; i++) {
            let c = items.get(i).command.trim();
            if (c !== "") arr.push({ command: c });
        }
        Config.saveAllStartup(arr);
        page.dirty = false;
    }

    function reload() {
        items.clear();
        let data = Config.startupData || [];
        for (let i = 0; i < data.length; i++)
            items.append({ command: data[i].command || "" });
        page.dirty = false;
    }

    ListModel { id: items }

    Component.onCompleted: page.reload()

    // Config JSON'u okumayı bitirdiğinde (ve her kayıttan sonra) listeyi tazele.
    Connections {
        target: Config
        function onStartupLoaded() { page.reload(); }
    }

    spacing: s(12)

    RowLayout {
        Layout.fillWidth: true
        spacing: page.s(8)

        Text {
            Layout.fillWidth: true
            text: items.count + " başlangıç komutu"
            color: page.theme.subtext0
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: page.s(11)
        }

        Rectangle {
            Layout.preferredWidth: page.s(96)
            Layout.preferredHeight: page.s(30)
            radius: page.s(9)
            color: addMa.containsMouse
                   ? Qt.rgba(page.theme.mauve.r, page.theme.mauve.g, page.theme.mauve.b, 0.25)
                   : Qt.rgba(page.theme.surface1.r, page.theme.surface1.g, page.theme.surface1.b, 0.7)
            Behavior on color { ColorAnimation { duration: 200 } }
            scale: addMa.pressed ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

            Text {
                anchors.centerIn: parent
                text: "+  Ekle"
                color: page.theme.text
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(11)
            }

            MouseArea {
                id: addMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    items.append({ command: "" });
                    page.dirty = true;
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: rows.implicitHeight + page.s(12)
        radius: page.s(14)
        color: Qt.rgba(page.theme.surface0.r, page.theme.surface0.g, page.theme.surface0.b, 0.5)
        border.width: 1
        border.color: Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.06)

        ColumnLayout {
            id: rows
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: page.s(6)
            spacing: page.s(4)

            Text {
                visible: items.count === 0
                Layout.fillWidth: true
                Layout.topMargin: page.s(14)
                Layout.bottomMargin: page.s(14)
                horizontalAlignment: Text.AlignHCenter
                text: "Henüz başlangıç komutu yok"
                color: page.theme.overlay0
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(11)
            }

            Repeater {
                model: items

                delegate: Item {
                    id: entry

                    required property int index
                    required property string command

                    Layout.fillWidth: true
                    implicitHeight: page.s(44)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: page.s(12)
                        anchors.rightMargin: page.s(12)
                        spacing: page.s(8)

                        Text {
                            text: "󰅩"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: page.s(12)
                            color: page.theme.overlay0
                        }

                        TextField {
                            id: cmdField
                            Layout.fillWidth: true
                            Layout.preferredHeight: page.s(30)

                            Component.onCompleted: text = entry.command

                            placeholderText: "çalıştırılacak komut"
                            color: page.theme.text
                            placeholderTextColor: page.theme.overlay0
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(11)
                            selectByMouse: true
                            leftPadding: page.s(10)
                            rightPadding: page.s(10)

                            background: Rectangle {
                                radius: page.s(8)
                                color: Qt.rgba(page.theme.surface1.r, page.theme.surface1.g, page.theme.surface1.b, 0.6)
                                border.width: 1
                                border.color: cmdField.activeFocus
                                              ? page.theme.mauve
                                              : Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.06)
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                            }

                            onTextChanged: {
                                if (text !== entry.command) {
                                    items.setProperty(entry.index, "command", text);
                                    page.dirty = true;
                                }
                            }
                        }

                        Text {
                            text: "󰅖"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: page.s(12)
                            color: delMa.containsMouse ? page.theme.red : page.theme.overlay0
                            Behavior on color { ColorAnimation { duration: 180 } }
                            scale: delMa.pressed ? 0.75 : (delMa.containsMouse ? 1.2 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                anchors.margins: page.s(-6)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    items.remove(entry.index);
                                    page.dirty = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: page.s(4)
        text: "Boş satırlar kaydedilirken atılır. Değişiklikler Hyprland yeniden başlatıldığında etkili olur."
        color: page.theme.overlay0
        font.family: "JetBrains Mono"
        font.pixelSize: page.s(10)
        wrapMode: Text.WordWrap
    }
}
