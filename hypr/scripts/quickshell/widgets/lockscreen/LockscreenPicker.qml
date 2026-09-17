//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"

// Kilit ekranı seçici — "Ray + Sahne" düzeni.
// Solda dört rakamlık dar bir ray, sağda üzerine gelinen/seçilen tasarımın
// gerçek boyutlu metin özeti. Main.qml'in popup sistemi üzerinden açılır
// (SUPER+SHIFT+L). Seçim ~/.config/hypr/hypridle/active-lock dosyasına
// yazılır; hypridle/lock.sh bu dosyayı okuyup doğru QML'i başlatır.
Item {
    id: window
    focus: true
    Keys.onEscapePressed: window.closePicker()

    Scaler { id: scaler; currentWidth: Screen.width; currentHeight: Screen.height }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }
    Caching { id: paths }
    readonly property string wallpaperPath: "file://" + paths.getCacheDir("wallpaper_picker") + "/current_wallpaper.png"

    // Main.qml her widget'a bunları geçiyor; kullanılmasa da tanımlı olmalı.
    property var notifModel: null
    property var liveNotifs: null

    readonly property string activeLockPath: Quickshell.env("HOME") + "/.config/hypr/hypridle/active-lock"

    property int activeIndex: 1
    property int hoveredIndex: 0
    readonly property int shownIndex: hoveredIndex !== 0 ? hoveredIndex : activeIndex
    readonly property var shownItem: window.items[window.shownIndex - 1]

    property var items: [
        { n: 1, title: "Monolit", desc: "Sol altta dev saat, ince alt çizgi şifre. Bekleme durumunda saat yavaşça kayar.", tag: "MNL" },
        { n: 2, title: "Terminal", desc: "Login prompt gibi davranır; sistem bilgisi (wm, dm, çalışma süresi) sağda.", tag: "TRM" },
        { n: 3, title: "Nokta Matris", desc: "Noktalı ızgara zemin, LED tarzı saat. Şifre karakterleri nokta sırasını doldurur.", tag: "NKT" },
        { n: 4, title: "Buzlu Şerit", desc: "Duvar kağıdı net kalır; sağda buzlu cam bir şerit saat ve şifreyi taşır.", tag: "BZL" }
    ]

    function closePicker() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    function selectIndex(n) {
        activeIndex = n;
        writeProc.command = ["bash", "-c", "echo " + n + " > '" + window.activeLockPath + "'"];
        writeProc.running = true;
    }

    function testLock() {
        testProc.running = true;
    }

    Process {
        id: readProc
        running: true
        command: ["bash", "-c", "cat '" + window.activeLockPath + "' 2>/dev/null || echo 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text.trim());
                if (v >= 1 && v <= 4) window.activeIndex = v;
            }
        }
    }
    Process { id: writeProc }
    Process {
        id: testProc
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/hypridle/lock.sh"]
    }

    Rectangle {
        anchors.fill: parent
        color: _theme.base
        border.width: 1
        border.color: _theme.surface1

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ───────── Sol ray ─────────
            ColumnLayout {
                Layout.preferredWidth: s(190)
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(58)
                    color: "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: s(16)
                        text: "KİLİT EKRANI"
                        font.family: "JetBrains Mono"; font.weight: Font.Medium
                        font.pixelSize: s(11); font.letterSpacing: s(1.6)
                        color: _theme.overlay0
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: _theme.surface1 }

                Repeater {
                    model: window.items
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        readonly property bool isSel: window.activeIndex === modelData.n
                        readonly property bool isShown: window.shownIndex === modelData.n
                        color: isShown ? Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.05) : "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: s(3)
                            color: parent.isSel ? _theme.peach : "transparent"
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: _theme.surface1 }

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: s(22)
                            text: (modelData.n < 10 ? "0" : "") + modelData.n
                            font.family: "Bricolage Grotesque"
                            font.weight: Font.Bold
                            font.pixelSize: s(28)
                            color: parent.isShown ? _theme.text : _theme.overlay0
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: s(10)
                            visible: parent.isSel
                            text: "●"
                            font.pixelSize: s(9)
                            color: _theme.peach
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: window.hoveredIndex = modelData.n
                            onExited: window.hoveredIndex = 0
                            onClicked: window.selectIndex(modelData.n)
                        }
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: _theme.surface1 }

            // ───────── Sağ sahne ─────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(58)
                    Layout.leftMargin: s(28)
                    Layout.rightMargin: s(20)

                    Text {
                        text: (window.shownIndex < 10 ? "0" : "") + window.shownIndex + " / 0" + window.items.length
                              + (window.shownIndex === window.activeIndex ? "  ·  seçili" : "  ·  önizleme")
                        font.family: "JetBrains Mono"; font.pixelSize: s(11.5)
                        color: window.shownIndex === window.activeIndex ? _theme.peach : _theme.overlay0
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: s(96); height: s(32)
                        color: "transparent"; border.width: 1; border.color: _theme.overlay0
                        Text { anchors.centerIn: parent; text: "Test Et"; font.family: "JetBrains Mono"; font.pixelSize: s(12); color: _theme.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: window.testLock() }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: _theme.surface1 }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: s(28)
                    Layout.rightMargin: s(28)
                    Layout.topMargin: s(16)
                    Layout.bottomMargin: s(12)
                    spacing: s(12)

                    // Gerçek duvar kağıdı üzerinde küçük canlı önizleme
                    Item {
                        id: previewBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(width * 9 / 16, s(280))
                        clip: true

                        Rectangle { anchors.fill: parent; color: "#0a0a0a" }

                        Image {
                            id: pvWall
                            anchors.fill: parent
                            visible: window.shownItem.n === 1 || window.shownItem.n === 4
                            source: window.wallpaperPath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: window.shownItem.n === 1
                            color: "#000"; opacity: 0.42
                        }

                        // 1 — Monolit
                        Text {
                            anchors.left: parent.left; anchors.bottom: parent.bottom
                            anchors.margins: previewBox.height * 0.09
                            visible: window.shownItem.n === 1
                            text: "23:41"
                            font.family: "Bricolage Grotesque"; font.weight: Font.ExtraBold
                            font.pixelSize: previewBox.height * 0.34
                            color: "#eaeaea"
                        }

                        // 2 — Terminal
                        Text {
                            anchors.left: parent.left; anchors.bottom: parent.bottom
                            anchors.margins: previewBox.height * 0.08
                            visible: window.shownItem.n === 2
                            text: "23:41:07"
                            font.family: "JetBrains Mono"; font.weight: Font.Medium
                            font.pixelSize: previewBox.height * 0.22
                            color: "#333"
                        }
                        Column {
                            anchors.left: parent.left; anchors.top: parent.top
                            anchors.margins: previewBox.height * 0.1
                            visible: window.shownItem.n === 2
                            spacing: previewBox.height * 0.045
                            Text { text: "lunanoir@cachyos:"; font.family: "JetBrains Mono"; font.pixelSize: previewBox.height * 0.08; color: "#9dd6a4" }
                            Text { text: "password: ••••█"; font.family: "JetBrains Mono"; font.pixelSize: previewBox.height * 0.08; color: "#bdbdbd" }
                        }

                        // 3 — Nokta Matris
                        Canvas {
                            anchors.fill: parent
                            visible: window.shownItem.n === 3
                            onPaint: {
                                let ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.fillStyle = "#1e1e1e";
                                let step = height * 0.1;
                                for (let yy = step / 2; yy < height; yy += step)
                                    for (let xx = step / 2; xx < width; xx += step) {
                                        ctx.beginPath(); ctx.arc(xx, yy, height * 0.008, 0, Math.PI * 2); ctx.fill();
                                    }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: window.shownItem.n === 3
                            text: "23:41"
                            font.family: "Doto"; font.weight: Font.Black
                            font.pixelSize: previewBox.height * 0.32
                            color: "#eaeaea"
                        }

                        // 4 — Buzlu Şerit
                        Item {
                            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: parent.width * 0.36
                            visible: window.shownItem.n === 4
                            Rectangle { anchors.fill: parent; color: "#0a0a0a"; opacity: 0.55 }
                            Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.12) }
                            Text {
                                anchors.left: parent.left; anchors.bottom: parent.bottom
                                anchors.margins: previewBox.height * 0.1
                                text: "23:41"
                                font.family: "Bricolage Grotesque"; font.weight: Font.DemiBold
                                font.pixelSize: previewBox.height * 0.2
                                color: "#eaeaea"
                            }
                        }

                        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: _theme.surface1 }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: window.shownItem.title
                        font.family: "Bricolage Grotesque"; font.weight: Font.Bold
                        font.pixelSize: s(28); font.letterSpacing: s(-0.7)
                        color: _theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: window.shownItem.desc
                        font.family: "JetBrains Mono"; font.pixelSize: s(12); lineHeight: 1.35
                        color: _theme.subtext0
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: _theme.surface1 }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(38)
                    Layout.leftMargin: s(28)
                    Layout.rightMargin: s(20)
                    Text {
                        text: "Seçtiğin tasarım hem kilit hem bekleme görünümünü belirler."
                        font.family: "JetBrains Mono"; font.pixelSize: s(10.5); color: _theme.overlay0
                    }
                    Item { Layout.fillWidth: true }
                    Text { text: "Esc ile kapat"; font.family: "JetBrains Mono"; font.pixelSize: s(10.5); color: _theme.overlay0 }
                }
            }
        }
    }

    Component.onCompleted: forceActiveFocus()
}
