//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "core"

// Lockscreen 2 — Terminal
// Giriş istemi gibi davranan kilit ekranı. Bekleme durumunda yalnızca
// hypridle günlüğü ve kısık bir saat görünür; dokunulunca gerçek bir
// "login prompt" beliriyor.
ShellRoot {
    id: root

    Caching { id: paths }
    MatugenColors { id: _theme }
    MediaData { id: media }
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color peach: _theme.peach
    readonly property color red: _theme.red
    readonly property color green: _theme.green

    QtObject {
        id: lockUI
        property bool failed: false
        property bool authenticating: false
        property string statusText: "kilitli"
    }

    Timer { id: pamActionTimer; interval: 50; onTriggered: pam.start() }

    PamContext {
        id: pam
        Component.onCompleted: pamActionTimer.start()
        onCompleted: (result) => {
            lockUI.authenticating = false;
            if (result === PamResult.Success) { rootLock.locked = false; Qt.quit(); }
            else { lockUI.failed = true; lockUI.statusText = "erişim reddedildi"; pamActionTimer.start(); }
        }
    }

    WlSessionLock {
        id: rootLock
        locked: true

        WlSessionLockSurface {
            id: surface

            Rectangle {
                id: screenRoot
                anchors.fill: parent
                color: "#0a0a0a"

                Scaler { id: scaler; currentWidth: screenRoot.width > 0 ? screenRoot.width : Screen.width }
                readonly property real sc: scaler.baseScale
                property bool inputActive: false
                property string currentUser: "user"
                property string hostName: "cachyos"
                property string uptimeStr: ""

                Process { command: ["bash", "-c", "whoami"]; running: true; stdout: StdioCollector { onStreamFinished: { let u = this.text.trim(); if (u) screenRoot.currentUser = u; } } }
                Process { command: ["bash", "-c", "hostname"]; running: true; stdout: StdioCollector { onStreamFinished: { let h = this.text.trim(); if (h) screenRoot.hostName = h; } } }
                Process { command: ["bash", "-c", "uptime -p | sed 's/up //'"]; running: true; stdout: StdioCollector { onStreamFinished: { screenRoot.uptimeStr = this.text.trim(); } } }

                MouseArea { anchors.fill: parent; onClicked: { screenRoot.inputActive = true; inputField.forceActiveFocus(); } }

                // sol: log / prompt sütunu
                Column {
                    x: 56 * screenRoot.sc
                    y: 64 * screenRoot.sc
                    spacing: 6 * screenRoot.sc
                    width: parent.width * 0.55

                    Text { text: "CachyOS · " + screenRoot.hostName + " · tty1"; font.family: "JetBrains Mono"; font.pixelSize: 15 * screenRoot.sc; color: root.subtext0 }
                    Text {
                        text: "● oturum kilitlendi " + clockText.text
                        font.family: "JetBrains Mono"; font.pixelSize: 15 * screenRoot.sc
                        color: root.green
                        opacity: screenRoot.inputActive ? 0.5 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                    Item { width: 1; height: 10 * screenRoot.sc }

                    // --- Bekleme durumunda çalan medya: bir log satırı daha ---
                    Item {
                        id: mediaWidget
                        z: 10
                        width: parent.width
                        height: mediaCol.implicitHeight
                        visible: opacity > 0.01
                        opacity: (media.hasPlayer && !screenRoot.inputActive) ? 1 : 0
                        enabled: media.hasPlayer && !screenRoot.inputActive
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        MouseArea { anchors.fill: parent; onClicked: {} }

                        Column {
                            id: mediaCol
                            spacing: 7 * screenRoot.sc
                            width: parent.width

                            Row {
                                spacing: 7 * screenRoot.sc
                                Text { text: "♪"; font.family: "JetBrains Mono"; font.pixelSize: 15 * screenRoot.sc; color: root.green }
                                Text {
                                    width: 360 * screenRoot.sc
                                    elide: Text.ElideRight
                                    text: (media.artist !== "" ? media.artist + " — " : "") + media.title
                                    font.family: "JetBrains Mono"; font.pixelSize: 15 * screenRoot.sc
                                    color: root.subtext0
                                }
                            }

                            // Bir TUI durum çubuğu gibi tuş rozetleri (htop/fzf tarzı)
                            Row {
                                spacing: 6 * screenRoot.sc

                                component KeyChip: Rectangle {
                                    id: chip
                                    property string glyph: ""
                                    property bool danger: false
                                    signal activated()
                                    width: 30 * screenRoot.sc
                                    height: 24 * screenRoot.sc
                                    radius: 2
                                    color: chipMa.containsMouse ? Qt.rgba(root.text.r, root.text.g, root.text.b, 0.08) : "transparent"
                                    border.width: 1
                                    border.color: chipMa.containsMouse ? (chip.danger ? root.red : root.peach) : root.overlay0
                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: chip.glyph
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 13 * screenRoot.sc
                                        color: chipMa.containsMouse ? (chip.danger ? root.red : root.peach) : root.subtext0
                                    }
                                    MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; onClicked: chip.activated() }
                                }

                                KeyChip { glyph: "◀"; onActivated: media.previous() }
                                KeyChip { glyph: media.isPlaying ? "⏸" : "▶"; onActivated: media.playPause() }
                                KeyChip { glyph: "▶▶"; onActivated: media.next() }
                                KeyChip { glyph: "■"; danger: true; onActivated: media.stop() }
                            }
                        }
                    }
                    Item { width: 1; height: 4 * screenRoot.sc }

                    Row {
                        spacing: 8 * screenRoot.sc
                        visible: screenRoot.inputActive
                        Text { text: screenRoot.currentUser + "@" + screenRoot.hostName + ":"; font.family: "JetBrains Mono"; font.pixelSize: 15 * screenRoot.sc; color: root.text }
                        Text { text: "password:"; font.family: "JetBrains Mono"; font.pixelSize: 15 * screenRoot.sc; color: root.subtext0 }
                        Text { text: "•".repeat(inputField.text.length); font.family: "JetBrains Mono"; font.pixelSize: 15 * screenRoot.sc; color: root.text }
                        Rectangle { width: 2; height: 16 * screenRoot.sc; color: root.text; anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity { loops: Animation.Infinite; running: screenRoot.inputActive
                                NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
                        }
                    }

                    Text {
                        visible: lockUI.failed || lockUI.authenticating
                        text: lockUI.statusText
                        font.family: "JetBrains Mono"; font.pixelSize: 14 * screenRoot.sc
                        color: lockUI.failed ? root.red : root.peach
                    }
                }

                // sağ üst: sistem bilgi kutusu (yalnızca aktifken)
                Rectangle {
                    x: parent.width - width - 56 * screenRoot.sc
                    y: 64 * screenRoot.sc
                    width: 300 * screenRoot.sc
                    height: infoCol.implicitHeight + 28 * screenRoot.sc
                    color: "transparent"
                    border.color: root.overlay0
                    border.width: 1
                    opacity: screenRoot.inputActive ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Column {
                        id: infoCol
                        x: 18 * screenRoot.sc; y: 14 * screenRoot.sc
                        width: parent.width - 36 * screenRoot.sc
                        spacing: 6 * screenRoot.sc
                        Repeater {
                            model: [["wm", "Hyprland"], ["dm", "sddm"], ["açık", screenRoot.uptimeStr], ["ekran", screenRoot.width > 0 ? Math.round(screenRoot.width)+"×"+Math.round(screenRoot.height) : ""]]
                            Row {
                                width: infoCol.width
                                Text { text: modelData[0]; font.family: "JetBrains Mono"; font.pixelSize: 13 * screenRoot.sc; color: root.overlay0; width: infoCol.width * 0.4 }
                                Text { text: modelData[1]; font.family: "JetBrains Mono"; font.pixelSize: 13 * screenRoot.sc; color: root.text }
                            }
                        }
                    }
                }

                // sol alt: dev saat, boşta soluk, aktifken küçülür ve koyulaşır
                Text {
                    id: clockText
                    x: 56 * screenRoot.sc
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 48 * screenRoot.sc
                    font.family: "JetBrains Mono"
                    font.weight: Font.Medium
                    font.pixelSize: (screenRoot.inputActive ? 96 : 190) * screenRoot.sc
                    color: screenRoot.inputActive ? "#343434" : root.text
                    Behavior on font.pixelSize { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 350 } }
                }

                TextInput {
                    id: inputField
                    x: -1000; width: 1; height: 1
                    opacity: 0
                    echoMode: TextInput.Password
                    Component.onCompleted: forceActiveFocus()
                    onActiveFocusChanged: if (!activeFocus) forceActiveFocus()
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) { text = ""; screenRoot.inputActive = false; event.accepted = true; }
                        else if (!screenRoot.inputActive) screenRoot.inputActive = true;
                    }
                    onTextChanged: if (text.length > 0) lockUI.failed = false;
                    onAccepted: {
                        if (text.length > 0 && pam.responseRequired && !lockUI.authenticating) {
                            lockUI.authenticating = true;
                            lockUI.statusText = "doğrulanıyor…";
                            lockUI.failed = false;
                            pam.respond(text);
                            text = "";
                        }
                    }
                }

                Timer {
                    interval: 1000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: { clockText.text = Qt.formatDateTime(new Date(), "hh:mm:ss"); }
                }
            }
        }
    }
}
