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

// Lockscreen 4 — Buzlu Şerit
// Duvar kağıdı net kalır; sağda buzlu cam bir şerit saat/kullanıcı/şifre
// taşır. Bekleme durumunda şerit daralıp sadece saat gösterir.
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
            else { lockUI.failed = true; lockUI.statusText = "Erişim Reddedildi"; pamActionTimer.start(); }
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
                property bool inputActive: false
                property string currentUser: "user"
                property string staticWallpaperPath: "file://" + paths.getCacheDir("wallpaper_picker") + "/current_wallpaper.png"
                property bool isDesktop: true
                property string batPct: "100"

                Process { command: ["bash", "-c", "whoami"]; running: true; stdout: StdioCollector { onStreamFinished: { let u = this.text.trim(); if (u) screenRoot.currentUser = u; } } }
                Process {
                    running: true
                    command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                    stdout: StdioCollector { onStreamFinished: { screenRoot.isDesktop = (this.text.trim() === "desktop"); } }
                }
                Process {
                    running: !screenRoot.isDesktop
                    command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo '100'"]
                    stdout: StdioCollector { onStreamFinished: { screenRoot.batPct = this.text.trim() || "100"; } }
                }

                // Ken Burns: boşta yavaş yakınlaşma (yalnızca duvar kağıdı ölçeklenir)
                property real kb: 0
                NumberAnimation on kb {
                    running: !screenRoot.inputActive
                    from: 0; to: 1; duration: 30000
                    loops: Animation.Infinite
                    easing.type: Easing.InOutSine
                }

                Image {
                    id: wallpaperImg
                    anchors.fill: parent
                    source: screenRoot.staticWallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    transform: Scale {
                        origin.x: wallpaperImg.width / 2; origin.y: wallpaperImg.height / 2
                        xScale: 1 + 0.06 * Math.sin(screenRoot.kb * Math.PI)
                        yScale: 1 + 0.06 * Math.sin(screenRoot.kb * Math.PI)
                    }
                }

                MouseArea { anchors.fill: parent; onClicked: { screenRoot.inputActive = true; inputField.forceActiveFocus(); } }

                // --- Buzlu şerit (sağ) ---
                Item {
                    id: strip
                    width: (screenRoot.inputActive ? 460 : 260) * screenRoot.sc
                    height: parent.height
                    anchors.right: parent.right
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    clip: true

                    ShaderEffectSource {
                        id: wallSample
                        sourceItem: wallpaperImg
                        sourceRect: Qt.rect(screenRoot.width - strip.width, 0, strip.width, screenRoot.height)
                        anchors.fill: parent
                        visible: false
                        live: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: wallSample
                        blurEnabled: true
                        blur: 0.9
                        blurMax: 48 * screenRoot.sc
                        brightness: -0.1
                        saturation: -0.3
                    }
                    Rectangle { anchors.fill: parent; color: "#0a0a0a"; opacity: 0.38 }
                    Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: Qt.rgba(1,1,1,0.09) }

                    Column {
                        id: stripCol
                        x: 34 * screenRoot.sc
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 68 * screenRoot.sc
                        spacing: 20 * screenRoot.sc

                        Text { id: dateText; font.family: "JetBrains Mono"; font.pixelSize: 13 * screenRoot.sc; font.letterSpacing: 3; color: root.subtext0 }
                        Text {
                            id: clockText
                            font.family: "Bricolage Grotesque"; font.weight: Font.DemiBold
                            font.pixelSize: (screenRoot.inputActive ? 68 : 84) * screenRoot.sc
                            color: root.text
                            Behavior on font.pixelSize { NumberAnimation { duration: 300 } }
                        }

                        Row {
                            spacing: 12 * screenRoot.sc
                            visible: screenRoot.inputActive
                            opacity: screenRoot.inputActive ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            Rectangle {
                                width: 36 * screenRoot.sc; height: 36 * screenRoot.sc; radius: 18 * screenRoot.sc
                                color: root.text
                                Text { anchors.centerIn: parent; text: screenRoot.currentUser.charAt(0).toUpperCase(); font.family: "Bricolage Grotesque"; font.weight: Font.Bold; font.pixelSize: 16 * screenRoot.sc; color: "#0e0e0e" }
                            }
                            Text { text: screenRoot.currentUser; font.family: "JetBrains Mono"; font.pixelSize: 14 * screenRoot.sc; color: root.subtext0; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Item {
                            width: parent.width
                            height: (screenRoot.inputActive ? 46 : 0) * screenRoot.sc
                            clip: true
                            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                            Rectangle {
                                width: parent.width; height: 42 * screenRoot.sc
                                color: "transparent"
                                border.width: 1
                                border.color: lockUI.failed ? root.red : Qt.rgba(1,1,1,0.28)
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 10 * screenRoot.sc
                                    Text { text: "•".repeat(inputField.text.length); font.family: "JetBrains Mono"; font.pixelSize: 15 * screenRoot.sc; font.letterSpacing: 4; color: root.text; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }

                        // --- Bekleme durumunda çalan medya: kapak karesi + başlık/sanatçı + kontrol ---
                        Item {
                            id: mediaWidget
                            z: 10
                            width: parent.width
                            height: mediaRow.implicitHeight
                            visible: opacity > 0.01
                            opacity: (media.hasPlayer && !screenRoot.inputActive) ? 1 : 0
                            enabled: media.hasPlayer && !screenRoot.inputActive
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            MouseArea { anchors.fill: parent; onClicked: {} }

                            Row {
                                id: mediaRow
                                spacing: 10 * screenRoot.sc

                                Rectangle {
                                    visible: media.artUrl !== ""
                                    width: 34 * screenRoot.sc; height: 34 * screenRoot.sc
                                    radius: 6 * screenRoot.sc
                                    color: "#141414"
                                    clip: true
                                    Image {
                                        anchors.fill: parent
                                        source: media.artUrl !== "" ? ("file://" + media.artUrl) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }

                                Column {
                                    spacing: 2 * screenRoot.sc
                                    width: stripCol.width - 44 * screenRoot.sc

                                    Text {
                                        width: parent.width; elide: Text.ElideRight
                                        text: media.title
                                        font.family: "JetBrains Mono"; font.pixelSize: 13 * screenRoot.sc
                                        color: root.text
                                    }
                                    Text {
                                        width: parent.width; elide: Text.ElideRight
                                        text: media.artist
                                        font.family: "JetBrains Mono"; font.pixelSize: 11 * screenRoot.sc
                                        color: root.subtext0
                                    }

                                    Row {
                                        spacing: 12 * screenRoot.sc
                                        topPadding: 2 * screenRoot.sc

                                        Text {
                                            text: "󰒮"; font.family: "Iosevka Nerd Font"; font.pixelSize: 16 * screenRoot.sc
                                            color: prevMa.containsMouse ? "#fff" : Qt.rgba(1, 1, 1, 0.55)
                                            MouseArea { id: prevMa; anchors.fill: parent; anchors.margins: -5 * screenRoot.sc; hoverEnabled: true; onClicked: media.previous() }
                                        }
                                        Text {
                                            text: media.isPlaying ? "󰏤" : "󰐊"; font.family: "Iosevka Nerd Font"; font.pixelSize: 16 * screenRoot.sc
                                            color: playMa.containsMouse ? "#fff" : Qt.rgba(1, 1, 1, 0.85)
                                            MouseArea { id: playMa; anchors.fill: parent; anchors.margins: -5 * screenRoot.sc; hoverEnabled: true; onClicked: media.playPause() }
                                        }
                                        Text {
                                            text: "󰒭"; font.family: "Iosevka Nerd Font"; font.pixelSize: 16 * screenRoot.sc
                                            color: nextMa.containsMouse ? "#fff" : Qt.rgba(1, 1, 1, 0.55)
                                            MouseArea { id: nextMa; anchors.fill: parent; anchors.margins: -5 * screenRoot.sc; hoverEnabled: true; onClicked: media.next() }
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: 18 * screenRoot.sc
                            visible: !screenRoot.inputActive
                            Text { text: "wlan0"; font.family: "JetBrains Mono"; font.pixelSize: 11 * screenRoot.sc; color: root.overlay0 }
                            Text { text: screenRoot.isDesktop ? "AC" : ("pil " + screenRoot.batPct + "%"); font.family: "JetBrains Mono"; font.pixelSize: 11 * screenRoot.sc; color: root.overlay0 }
                        }

                        Text {
                            visible: lockUI.failed || lockUI.authenticating
                            text: lockUI.statusText
                            font.family: "JetBrains Mono"; font.pixelSize: 12 * screenRoot.sc
                            color: lockUI.failed ? root.red : root.peach
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
