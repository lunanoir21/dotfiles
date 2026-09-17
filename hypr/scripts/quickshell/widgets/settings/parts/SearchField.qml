import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Ayarlar penceresinin ana giriş noktası. Pencere açıldığı anda burası odakta:
// kullanıcı ne aradığını biliyorsa gezinmeden yazmaya başlayabilsin.
Item {
    id: sf_

    property var theme
    property real sf: 1.0
    property string text: ""
    property string placeholder: "Ayarlarda ara"
    property int resultCount: -1    // -1 = arama yok, göster­me

    signal submitted()
    signal escaped()
    signal navigate(int delta)      // ↑ / ↓ ile sonuçlarda gezinme

    function s(v) { return Math.round(v * sf_.sf); }
    function focusField() { field.forceActiveFocus(); }
    function clear() { field.text = ""; }

    implicitHeight: s(38)

    Rectangle {
        anchors.fill: parent
        radius: sf_.s(12)
        color: Qt.rgba(sf_.theme.surface0.r, sf_.theme.surface0.g, sf_.theme.surface0.b, 0.75)
        border.width: 1
        border.color: field.activeFocus
                      ? sf_.theme.mauve
                      : Qt.rgba(sf_.theme.text.r, sf_.theme.text.g, sf_.theme.text.b, 0.08)
        Behavior on border.color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: sf_.s(12)
            anchors.rightMargin: sf_.s(8)
            spacing: sf_.s(9)

            Text {
                text: "󰍉"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: sf_.s(14)
                color: field.activeFocus ? sf_.theme.mauve : sf_.theme.overlay0
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            TextField {
                id: field
                Layout.fillWidth: true
                Layout.fillHeight: true
                background: Item {}
                padding: 0
                color: sf_.theme.text
                placeholderText: sf_.placeholder
                placeholderTextColor: sf_.theme.overlay0
                font.family: "JetBrains Mono"
                font.pixelSize: sf_.s(12)
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true

                onTextChanged: sf_.text = text
                onAccepted: sf_.submitted()
                // Esc iki aşamalı: arama doluysa önce onu temizler, boşsa
                // olayı yukarı bırakır ve pencerenin kendisi kapanır.
                Keys.onEscapePressed: (e) => {
                    if (field.text !== "") {
                        sf_.escaped();
                        e.accepted = true;
                    } else {
                        e.accepted = false;
                    }
                }
                Keys.onDownPressed: (e) => { sf_.navigate(1); e.accepted = true; }
                Keys.onUpPressed: (e) => { sf_.navigate(-1); e.accepted = true; }
            }

            // Sonuç sayacı: aramanın bir şey bulup bulmadığı yazarken belli olsun.
            Text {
                visible: sf_.resultCount >= 0 && sf_.text !== ""
                text: sf_.resultCount + " sonuç"
                color: sf_.resultCount === 0 ? sf_.theme.peach : sf_.theme.overlay0
                font.family: "JetBrains Mono"
                font.pixelSize: sf_.s(10)
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Rectangle {
                visible: sf_.text !== ""
                Layout.preferredWidth: sf_.s(22)
                Layout.preferredHeight: sf_.s(22)
                radius: width / 2
                color: clearMa.containsMouse
                       ? Qt.rgba(sf_.theme.text.r, sf_.theme.text.g, sf_.theme.text.b, 0.12)
                       : "transparent"
                Behavior on color { ColorAnimation { duration: 180 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: sf_.s(11)
                    color: sf_.theme.subtext0
                }

                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { field.text = ""; field.forceActiveFocus(); }
                }
            }
        }
    }

    // Dışarıdan text sıfırlanırsa (Esc, sayfa değişimi) alan da temizlensin.
    onTextChanged: if (sf_.text !== field.text) field.text = sf_.text
}
