//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "core"

// Lockscreen 1 — Monolit
// Sol altta dev bir saat, şifre yalnızca ince bir alt çizgi. inputActive
// false iken (Bekleme) sadece saat görünür; kullanıcı yazmaya başlayınca
// (Kilit) kullanıcı adı + şifre satırı belirir.
ShellRoot {
    id: root

    Caching { id: paths }
    MatugenColors { id: _theme }
    MediaData { id: media }
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color surface0: _theme.surface0
    readonly property color peach: _theme.peach
    readonly property color red: _theme.red
    readonly property color overlay0: _theme.overlay0

    QtObject {
        id: lockUI
        property bool failed: false
        property bool authenticating: false
        property string statusText: "Kilitli"
    }

    Timer { id: pamActionTimer; interval: 50; onTriggered: pam.start() }

    PamContext {
        id: pam
        Component.onCompleted: pamActionTimer.start()
        onCompleted: (result) => {
            lockUI.authenticating = false;
            if (result === PamResult.Success) {
                rootLock.locked = false;
                Qt.quit();
            } else {
                lockUI.failed = true;
                lockUI.statusText = "Erişim Reddedildi";
                pamActionTimer.start();
            }
        }
    }

    WlSessionLock {
        id: rootLock
        locked: true

        WlSessionLockSurface {
            id: surface

            Item {
                id: screenRoot
                anchors.fill: parent

                Scaler { id: scaler; currentWidth: screenRoot.width > 0 ? screenRoot.width : Screen.width }
                readonly property real sc: scaler.baseScale

                property string staticWallpaperPath: "file://" + paths.getCacheDir("wallpaper_picker") + "/current_wallpaper.png"
                property string currentUser: "user"
                property bool inputActive: false

                Process {
                    id: userProc
                    running: true
                    command: ["bash", "-c", "whoami"]
                    stdout: StdioCollector { onStreamFinished: { let u = this.text.trim(); if (u !== "") screenRoot.currentUser = u; } }
                }

                Timer { id: idleBackTimer; interval: 20000; running: screenRoot.inputActive && inputField.text.length === 0; onTriggered: screenRoot.inputActive = false }

                Image {
                    id: wallpaperImg
                    anchors.fill: parent
                    source: screenRoot.staticWallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: false
                }
                MultiEffect {
                    source: wallpaperImg
                    anchors.fill: wallpaperImg
                    brightness: -0.55
                    saturation: -0.4
                    blurEnabled: false
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: screenRoot.inputActive = true
                }

                // --- Bekleme durumunda çalan medya, saatin hemen üstünde ---
                Item {
                    id: mediaWidget
                    x: 64 * screenRoot.sc
                    anchors.bottom: mainColumn.top
                    anchors.bottomMargin: 22 * screenRoot.sc
                    width: 420 * screenRoot.sc
                    height: mediaRow.implicitHeight
                    z: 10
                    visible: opacity > 0.01
                    opacity: (media.hasPlayer && !screenRoot.inputActive) ? 1 : 0
                    enabled: media.hasPlayer && !screenRoot.inputActive
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    MouseArea { anchors.fill: parent; onClicked: {} }

                    Row {
                        id: mediaRow
                        spacing: 14 * screenRoot.sc

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 280 * screenRoot.sc
                            elide: Text.ElideRight
                            text: "♫ " + (media.artist !== "" ? media.artist + " — " : "") + media.title
                            font.family: "JetBrains Mono"
                            font.pixelSize: 13 * screenRoot.sc
                            color: root.subtext0
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10 * screenRoot.sc

                            Text {
                                text: "󰒮"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 15 * screenRoot.sc
                                color: prevMa.containsMouse ? root.peach : root.overlay0
                                MouseArea { id: prevMa; anchors.fill: parent; anchors.margins: -6 * screenRoot.sc; hoverEnabled: true; onClicked: media.previous() }
                            }
                            Text {
                                text: media.isPlaying ? "󰏤" : "󰐊"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 15 * screenRoot.sc
                                color: playMa.containsMouse ? root.peach : root.text
                                MouseArea { id: playMa; anchors.fill: parent; anchors.margins: -6 * screenRoot.sc; hoverEnabled: true; onClicked: media.playPause() }
                            }
                            Text {
                                text: "󰒭"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 15 * screenRoot.sc
                                color: nextMa.containsMouse ? root.peach : root.overlay0
                                MouseArea { id: nextMa; anchors.fill: parent; anchors.margins: -6 * screenRoot.sc; hoverEnabled: true; onClicked: media.next() }
                            }
                        }
                    }
                }

                // --- Sol alt blok: tarih + dev saat + şifre satırı ---
                Column {
                    id: mainColumn
                    x: 64 * screenRoot.sc
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 56 * screenRoot.sc
                    spacing: 8 * screenRoot.sc

                    Text {
                        id: dateText
                        text: ""
                        font.family: "JetBrains Mono"
                        font.pixelSize: 16 * screenRoot.sc
                        font.letterSpacing: 3
                        color: root.subtext0
                    }

                    Text {
                        id: clockText
                        text: ""
                        font.family: "Bricolage Grotesque"
                        font.weight: Font.ExtraBold
                        font.pixelSize: 210 * screenRoot.sc
                        color: root.text
                        lineHeight: 0.78
                        lineHeightMode: Text.ProportionalHeight
                    }

                    Item {
                        width: 420 * screenRoot.sc
                        height: (screenRoot.inputActive ? 64 : 0) * screenRoot.sc
                        clip: true
                        Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

                        Text {
                            id: pwDots
                            anchors.top: parent.top
                            anchors.topMargin: 2 * screenRoot.sc
                            anchors.left: parent.left
                            text: "•".repeat(inputField.text.length)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 26 * screenRoot.sc
                            font.letterSpacing: 6
                            color: root.text
                        }

                        Row {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2 * screenRoot.sc
                            width: parent.width
                            spacing: 16 * screenRoot.sc

                            Rectangle {
                                width: parent.width - userLabel.width - 16 * screenRoot.sc
                                height: 1
                                color: lockUI.failed ? root.red : (lockUI.authenticating ? root.peach : root.overlay0)
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 250 } }

                                TextInput {
                                    id: inputField
                                    anchors.fill: parent
                                    opacity: 0
                                    echoMode: TextInput.Password
                                    Component.onCompleted: forceActiveFocus()
                                    onActiveFocusChanged: if (!activeFocus) forceActiveFocus()
                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Escape) { text = ""; screenRoot.inputActive = false; event.accepted = true; }
                                    }
                                    onTextChanged: { if (text.length > 0) { screenRoot.inputActive = true; lockUI.failed = false; } }
                                    onAccepted: {
                                        if (text.length > 0 && pam.responseRequired && !lockUI.authenticating) {
                                            lockUI.authenticating = true;
                                            lockUI.statusText = "Doğrulanıyor…";
                                            lockUI.failed = false;
                                            pam.respond(text);
                                            text = "";
                                        }
                                    }
                                }
                            }

                            Text {
                                id: userLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: screenRoot.currentUser
                                font.family: "JetBrains Mono"
                                font.pixelSize: 15 * screenRoot.sc
                                color: root.subtext0
                            }
                        }
                    }

                    Text {
                        visible: lockUI.failed || lockUI.authenticating
                        text: lockUI.statusText
                        font.family: "JetBrains Mono"
                        font.pixelSize: 13 * screenRoot.sc
                        font.letterSpacing: 2
                        color: lockUI.failed ? root.red : root.peach
                    }
                }

                Timer {
                    interval: 1000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: {
                        let d = new Date();
                        clockText.text = Qt.formatDateTime(d, "hh:mm");
                        dateText.text = Qt.formatDateTime(d, "dddd, d MMMM").toUpperCase();
                    }
                }
            }
        }
    }
}
