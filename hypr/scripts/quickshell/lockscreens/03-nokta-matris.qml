//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "core"

// Lockscreen 3 — Nokta Matris
// Noktalı ızgara zemin üzerinde Doto (LED tarzı) fontla saat. Şifre
// karakterleri alttaki nokta sırasını dolduruyor (maks 12 gösterge).
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
            if (result === PamResult.Success) { rootLock.locked = false; Qt.quit(); }
            else {
                lockUI.failed = true;
                lockUI.statusText = "Erişim Reddedildi";
                dotShake.restart();
                pamActionTimer.start();
            }
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

                Process { command: ["bash", "-c", "whoami"]; running: true; stdout: StdioCollector { onStreamFinished: { let u = this.text.trim(); if (u) screenRoot.currentUser = u; } } }

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = "#1e1e1e";
                        let step = 26 * screenRoot.sc;
                        for (let yy = 0; yy < height; yy += step) {
                            for (let xx = 0; xx < width; xx += step) {
                                ctx.beginPath();
                                ctx.arc(xx, yy, 1.1 * screenRoot.sc, 0, Math.PI * 2);
                                ctx.fill();
                            }
                        }
                    }
                }

                MouseArea { anchors.fill: parent; onClicked: { screenRoot.inputActive = true; inputField.forceActiveFocus(); } }

                Column {
                    anchors.centerIn: parent
                    spacing: 18 * screenRoot.sc

                    Text {
                        id: clockText
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: "Doto"
                        font.weight: Font.Black
                        font.pixelSize: (screenRoot.inputActive ? 96 : 180) * screenRoot.sc
                        color: root.text
                        Behavior on font.pixelSize { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        id: dateText
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: "Doto"
                        font.weight: Font.Bold
                        font.pixelSize: 20 * screenRoot.sc
                        font.letterSpacing: 4
                        color: root.subtext0
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !screenRoot.inputActive
                        text: screenRoot.currentUser.toUpperCase() + " — DOKUN"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12 * screenRoot.sc
                        font.letterSpacing: 3
                        color: root.overlay0
                    }

                    // Şifre nokta göstergesi
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: dotsRow.width
                        height: (screenRoot.inputActive ? 24 : 0) * screenRoot.sc
                        clip: true
                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        Row {
                            id: dotsRow
                            y: 4 * screenRoot.sc
                            spacing: 14 * screenRoot.sc
                            transform: Translate { id: dotShakeT; x: 0 }
                            SequentialAnimation {
                                id: dotShake
                                NumberAnimation { target: dotShakeT; property: "x"; from: 0; to: -10 * screenRoot.sc; duration: 90 }
                                NumberAnimation { target: dotShakeT; property: "x"; from: -10 * screenRoot.sc; to: 10 * screenRoot.sc; duration: 90 }
                                NumberAnimation { target: dotShakeT; property: "x"; from: 10 * screenRoot.sc; to: 0; duration: 90 }
                            }
                            Repeater {
                                model: 12
                                Rectangle {
                                    width: 10 * screenRoot.sc; height: 10 * screenRoot.sc; radius: 5 * screenRoot.sc
                                    property bool filled: index < inputField.text.length
                                    color: filled ? (lockUI.failed ? root.red : root.peach) : "transparent"
                                    border.width: 1 * screenRoot.sc
                                    border.color: lockUI.failed ? root.red : root.overlay0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: lockUI.failed || lockUI.authenticating
                        text: lockUI.statusText
                        font.family: "JetBrains Mono"; font.pixelSize: 13 * screenRoot.sc
                        color: lockUI.failed ? root.red : root.peach
                    }
                }

                // --- Bekleme durumunda çalan medya: ortalanmış saat sütununun DIŞINDA,
                // alt-orta konumda, 12-nokta şifre göstergesiyle aynı dilden rozetler ---
                Item {
                    id: mediaWidget
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40 * screenRoot.sc
                    width: mediaRow.implicitWidth
                    height: mediaRow.implicitHeight
                    z: 10
                    visible: opacity > 0.01
                    opacity: (media.hasPlayer && !screenRoot.inputActive) ? 1 : 0
                    enabled: media.hasPlayer && !screenRoot.inputActive
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    MouseArea { anchors.fill: parent; onClicked: {} }

                    Row {
                        id: mediaRow
                        spacing: 12 * screenRoot.sc

                        Rectangle {
                            visible: media.artUrl !== ""
                            width: 28 * screenRoot.sc; height: 28 * screenRoot.sc
                            radius: 4 * screenRoot.sc
                            color: "#141414"
                            border.width: 1; border.color: root.overlay0
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                anchors.fill: parent
                                source: media.artUrl !== "" ? ("file://" + media.artUrl) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1 * screenRoot.sc
                            Text {
                                width: 160 * screenRoot.sc; elide: Text.ElideRight
                                text: media.artist.toUpperCase()
                                font.family: "Doto"; font.weight: Font.Bold
                                font.pixelSize: 11 * screenRoot.sc; font.letterSpacing: 1
                                color: root.overlay0
                            }
                            Text {
                                width: 160 * screenRoot.sc; elide: Text.ElideRight
                                text: media.title
                                font.family: "Doto"; font.weight: Font.Bold
                                font.pixelSize: 14 * screenRoot.sc
                                color: root.subtext0
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8 * screenRoot.sc

                            Rectangle {
                                width: 24 * screenRoot.sc; height: 24 * screenRoot.sc; radius: 12 * screenRoot.sc
                                color: "transparent"; border.width: 1 * screenRoot.sc
                                border.color: prevMa.containsMouse ? root.peach : root.overlay0
                                Text { anchors.centerIn: parent; text: "󰒮"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10 * screenRoot.sc; color: prevMa.containsMouse ? root.peach : root.overlay0 }
                                MouseArea { id: prevMa; anchors.fill: parent; anchors.margins: -4 * screenRoot.sc; hoverEnabled: true; onClicked: media.previous() }
                            }
                            Rectangle {
                                width: 24 * screenRoot.sc; height: 24 * screenRoot.sc; radius: 12 * screenRoot.sc
                                color: "transparent"; border.width: 1 * screenRoot.sc
                                border.color: playMa.containsMouse ? root.peach : root.overlay0
                                Text { anchors.centerIn: parent; text: media.isPlaying ? "󰏤" : "󰐊"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10 * screenRoot.sc; color: playMa.containsMouse ? root.peach : root.subtext0 }
                                MouseArea { id: playMa; anchors.fill: parent; anchors.margins: -4 * screenRoot.sc; hoverEnabled: true; onClicked: media.playPause() }
                            }
                            Rectangle {
                                width: 24 * screenRoot.sc; height: 24 * screenRoot.sc; radius: 12 * screenRoot.sc
                                color: "transparent"; border.width: 1 * screenRoot.sc
                                border.color: nextMa.containsMouse ? root.peach : root.overlay0
                                Text { anchors.centerIn: parent; text: "󰒭"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10 * screenRoot.sc; color: nextMa.containsMouse ? root.peach : root.overlay0 }
                                MouseArea { id: nextMa; anchors.fill: parent; anchors.margins: -4 * screenRoot.sc; hoverEnabled: true; onClicked: media.next() }
                            }
                        }
                    }
                }

                TextInput {
                    id: inputField
                    x: -1000; width: 1; height: 1
                    opacity: 0
                    echoMode: TextInput.Password
                    Component.onCompleted: forceActiveFocus()
                    onActiveFocusChanged: if (!activeFocus) forceActiveFocus()
                    validator: RegularExpressionValidator { regularExpression: /.{0,12}/ }
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) { text = ""; screenRoot.inputActive = false; event.accepted = true; }
                        else if (!screenRoot.inputActive) screenRoot.inputActive = true;
                    }
                    onTextChanged: if (text.length > 0) lockUI.failed = false;
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
