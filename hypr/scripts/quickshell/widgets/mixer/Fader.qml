import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire

// Tek bir ses kanalı: dikey ekolayzer sürgüsü (kanal şeridi).
//
// Kendi Scaler/MatugenColors örneğini kurmuyor — ikisi de Process açtığı için
// her sütunda bir tane olması boşuna sistem yükü. Ölçek ve tema dışarıdan gelir.
Item {
    id: fader

    property var  node: null
    property var  theme: null
    property real sc: 1.0
    property string label: ""
    property string sublabel: ""
    property string iconSource: ""
    property string iconGlyph: ""
    property color accent: "#cba6f7"
    property bool isMaster: false
    property bool selected: false
    property bool meterEnabled: false
    property real maxVolume: 1.5

    signal clicked()

    function s(v) { return Math.round(v * fader.sc); }

    readonly property var  audio:  node && node.audio ? node.audio : null
    readonly property real volume: audio ? audio.volume : 0.0
    readonly property bool muted:  audio ? audio.muted  : false
    readonly property int  percent: Math.round(volume * 100)
    readonly property bool boosted: percent > 100

    // Yükseltme bölgesinde renk kırmızıya kayıyor: 100 üstü sesin bozulmaya
    // başladığı yer, sürgünün kendisi bunu söylemeli.
    readonly property color liveColor: fader.muted
        ? theme.overlay0
        : (fader.boosted ? theme.red : fader.accent)

    function setVolume(v) {
        if (!audio) return;
        audio.volume = Math.max(0.0, Math.min(fader.maxVolume, v));
    }

    // Sesi yukarı çekmek sessizi otomatik açar: mute'tayken sürgüyü kaldırıp
    // "neden ses gelmiyor" demek en sık yapılan hata.
    function nudge(delta) {
        if (!audio) return;
        if (delta > 0 && audio.muted) audio.muted = false;
        setVolume(Math.round((fader.volume + delta) * 100) / 100);
    }

    function toggleMute() { if (audio) audio.muted = !audio.muted; }

    // ---------------------------------------------------------------
    // Canlı seviye ölçer. Peak monitor pipewire'da gerçek bir stream
    // açıyor, o yüzden sadece pencere gerçekten görünürken çalışır.
    // ---------------------------------------------------------------
    PwNodePeakMonitor {
        id: peakMonitor
        node: fader.node
        enabled: fader.meterEnabled && fader.node !== null
    }

    readonly property real peak: peakMonitor.enabled ? peakMonitor.peak : 0.0

    // Anlık peak değeri titriyor; gözle takip edilebilir olsun diye yükselişi
    // anında, düşüşü yavaşlatılmış bir zarf tutuyoruz.
    property real meterLevel: 0.0
    onPeakChanged: {
        if (peak > meterLevel) meterLevel = peak;
        else meterDecay.start();
    }
    Timer {
        id: meterDecay
        interval: 40
        repeat: true
        onTriggered: {
            if (fader.meterLevel <= fader.peak + 0.001) { stop(); return; }
            fader.meterLevel = Math.max(fader.peak, fader.meterLevel - 0.03);
        }
    }

    // =========================================================
    // KART
    // =========================================================
    Rectangle {
        id: card
        anchors.fill: parent
        radius: fader.s(16)

        color: fader.selected
            ? Qt.rgba(fader.accent.r, fader.accent.g, fader.accent.b, 0.09)
            : (hoverArea.containsMouse
                ? Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.55)
                : Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.22))

        border.width: 1
        border.color: fader.selected
            ? Qt.rgba(fader.accent.r, fader.accent.g, fader.accent.b, 0.45)
            : Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.35)

        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }
    }

    // =========================================================
    // İÇERİK
    // =========================================================
    ColumnLayout {
        id: strip
        anchors.fill: parent
        anchors.topMargin: fader.s(12)
        anchors.bottomMargin: fader.s(10)
        anchors.leftMargin: fader.s(8)
        anchors.rightMargin: fader.s(8)
        spacing: fader.s(6)

        // ---------------- uygulama simgesi ----------------
        Rectangle {
            id: iconChip
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: fader.s(42)
            Layout.preferredHeight: fader.s(42)
            radius: fader.s(13)
            color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.45)
            border.width: 1
            border.color: Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.35)

            Image {
                id: appIcon
                anchors.centerIn: parent
                width: fader.s(26)
                height: fader.s(26)
                visible: fader.iconSource !== "" && status === Image.Ready
                source: fader.iconSource
                sourceSize.width: fader.s(64)
                sourceSize.height: fader.s(64)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                // Sessizdeyken simge de sönüyor: hangi kanalın kapalı olduğu
                // tek bakışta anlaşılsın.
                opacity: fader.muted ? 0.35 : 1.0
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }

            // .desktop girdisi bulunamayan akışlar (tarayıcı sekmeleri, CLI
            // oynatıcılar) için yazı tipi simgesi.
            Text {
                anchors.centerIn: parent
                visible: !appIcon.visible
                text: fader.iconGlyph
                font.family: "Font Awesome 6 Free Solid"
                font.pixelSize: fader.s(17)
                color: fader.muted ? theme.overlay0 : theme.subtext0
            }
        }

        // ---------------- isim ----------------
        Text {
            Layout.fillWidth: true
            text: fader.label
            color: fader.muted ? theme.overlay1 : theme.text
            font.pixelSize: fader.s(12)
            font.weight: fader.isMaster ? Font.Bold : Font.DemiBold
            font.family: "Inter, sans-serif"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: -fader.s(4)
            visible: fader.sublabel !== ""
            text: fader.sublabel
            color: theme.overlay1
            font.pixelSize: fader.s(10)
            font.family: "Inter, sans-serif"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // ---------------- sürgü rayı ----------------
        Item {
            id: trackHost
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            Layout.topMargin: fader.s(4)
            Layout.preferredWidth: fader.s(54)

            // Skala: 0 / 50 / 100 / 150 çizgileri. Rayın solunda durur ki
            // dolgunun üstünü kirletmesin.
            Repeater {
                model: [0.0, 0.5, 1.0, 1.5]

                delegate: Item {
                    required property real modelData
                    width: fader.s(9)
                    height: 1
                    x: 0
                    y: Math.round(track.y + track.height * (1 - modelData / fader.maxVolume))

                    Rectangle {
                        anchors.fill: parent
                        // 100% çizgisi diğerlerinden belirgin: sürgünün
                        // "normal" sınırı orası.
                        color: modelData === 1.0
                            ? Qt.rgba(theme.overlay1.r, theme.overlay1.g, theme.overlay1.b, 0.8)
                            : Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.7)
                        width: modelData === 1.0 ? fader.s(9) : fader.s(5)
                    }
                }
            }

            Rectangle {
                id: track
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: fader.s(4)
                y: 0
                width: fader.s(32)
                height: parent.height
                radius: width / 2
                color: Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.85)
                border.width: 1
                border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.8)
                clip: true

                // canlı seviye ölçer — dolgunun arkasında soluk bir sütun
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.min(parent.height, parent.height * Math.min(1.0, fader.meterLevel * 1.7))
                    color: Qt.rgba(fader.accent.r, fader.accent.g, fader.accent.b, 0.20)
                    visible: fader.meterEnabled && !fader.muted
                    Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                }

                // asıl dolgu
                Rectangle {
                    id: fill
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(0, Math.min(parent.height,
                            parent.height * (fader.volume / fader.maxVolume)))
                    opacity: fader.muted ? 0.28 : 1.0

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: fader.liveColor }
                        GradientStop {
                            position: 1.0
                            color: Qt.rgba(fader.liveColor.r, fader.liveColor.g, fader.liveColor.b, 0.45)
                        }
                    }

                    Behavior on height {
                        enabled: !dragArea.pressed
                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                }

                // Dolgunun üst kenarındaki ince parlak çizgi: sürgünün
                // durduğu yeri rayın içinden okunur kılıyor.
                Rectangle {
                    width: parent.width
                    height: fader.s(2)
                    y: parent.height - fill.height
                    visible: fill.height > 0 && !fader.muted
                    color: Qt.lighter(fader.liveColor, 1.5)
                    opacity: 0.9
                }
            }

            // tutamak
            Rectangle {
                id: knob
                width: fader.s(38)
                height: fader.s(12)
                radius: fader.s(5)
                x: track.x + (track.width - width) / 2
                y: Math.max(0, Math.min(track.height - height,
                       track.height - fill.height - height / 2))

                color: fader.muted ? theme.surface2 : theme.text
                border.width: 1
                border.color: Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.6)
                scale: dragArea.pressed ? 1.08 : 1.0
                opacity: dragArea.pressed || hoverArea.containsMouse || fader.selected ? 1.0 : 0.85

                // Ortadaki oluk: tutamağı bir çizgi değil, tutulacak bir parça
                // gibi gösteriyor.
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.42
                    height: 1
                    color: Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.55)
                }

                Behavior on y {
                    enabled: !dragArea.pressed
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 130 } }
                Behavior on color { ColorAnimation { duration: 130 } }
            }
        }

        // ---------------- yüzde ----------------
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: fader.s(4)
            text: fader.muted ? "sessiz" : fader.percent + "%"
            color: fader.muted ? theme.overlay1 : (fader.boosted ? theme.red : theme.text)
            font.pixelSize: fader.s(13)
            font.weight: Font.Bold
            font.family: "JetBrains Mono, monospace"
        }

        // ---------------- sessiz düğmesi ----------------
        Rectangle {
            id: muteButton
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: fader.s(34)
            Layout.preferredHeight: fader.s(26)
            radius: fader.s(9)
            color: fader.muted
                ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.18)
                : (muteArea.containsMouse
                    ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.8)
                    : "transparent")
            border.width: fader.muted ? 1 : 0
            border.color: Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.35)

            Behavior on color { ColorAnimation { duration: 130 } }

            Text {
                anchors.centerIn: parent
                text: fader.muted ? "" : ""
                font.family: "Font Awesome 6 Free Solid"
                font.pixelSize: fader.s(12)
                color: fader.muted ? theme.red : theme.subtext0
            }

            MouseArea {
                id: muteArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: { fader.clicked(); fader.toggleMute(); }
            }
        }
    }

    // =========================================================
    // ETKİLEŞİM
    // =========================================================
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // Sürükleme alanı rayın kutusuyla sınırlı: kartın her yerine basınca
    // ses zıplamıyor, sadece ray tutuluyor. Tekerlek ise kartın tamamında
    // çalışıyor (aşağıdaki ayrı WheelHandler).
    MouseArea {
        id: dragArea
        parent: trackHost
        x: 0
        y: 0
        width: trackHost.width
        height: trackHost.height
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true

        function applyFromY(y) {
            let ratio = 1.0 - ((y - track.y) / track.height);
            fader.setVolume(Math.max(0, Math.min(1, ratio)) * fader.maxVolume);
        }

        onPressed: (m) => {
            fader.clicked();
            if (m.button === Qt.MiddleButton) { fader.toggleMute(); return; }
            if (fader.muted && fader.audio) fader.audio.muted = false;
            applyFromY(m.y);
        }

        onPositionChanged: (m) => {
            if (!pressed || !(pressedButtons & Qt.LeftButton)) return;
            applyFromY(m.y);
        }

        // Çift tıklama %100'e döndürür: elle sürükleyerek tam 100'ü
        // tutturmak zor, en çok istenen değer de o.
        onDoubleClicked: fader.setVolume(1.0)
    }

    WheelHandler {
        target: fader
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            fader.clicked();
            fader.nudge(event.angleDelta.y > 0 ? 0.02 : -0.02);
        }
    }

    // Kart üzerinde herhangi bir yere sol tık: sadece seçim yapar.
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        onClicked: fader.clicked()
    }
}
