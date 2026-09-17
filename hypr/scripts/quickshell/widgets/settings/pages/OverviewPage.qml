pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

// Genel bakış, diğer sayfalardan farklı olarak bir ayar kataloğu değil.
// Tek işi: şu anki sistem durumunu okumayı, dikkat isteyen noktayı görmeyi ve
// doğru sayfaya tek tıkla geçmeyi kolaylaştırmak.
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0
    property var summary: null

    readonly property bool hasSave: false
    readonly property bool dirty: false
    function save() {}

    signal openPage(string key)

    function s(v) { return Math.round(v * page.sf); }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function pct(v) { return Math.max(0, Math.min(100, Number(v) || 0)); }

    readonly property var sys: page.summary ? page.summary.system : null
    readonly property var net: page.summary ? page.summary.network : null
    readonly property var bt: page.summary ? page.summary.bluetooth : null
    readonly property var audio: page.summary ? page.summary.audio : null
    readonly property var bat: page.summary ? page.summary.battery : null

    function profileName(p) {
        if (p === "power-saver") return "Güç tasarrufu";
        if (p === "balanced") return "Dengeli mod";
        if (p === "performance") return "Yüksek performans";
        return "Profil okunamadı";
    }

    function systemTitle() {
        if (!page.summary) return "Sistem bilgisi hazırlanıyor";
        if (page.bat && page.bat.present && page.bat.capacity <= 15 && !page.bat.charging)
            return "Pil seviyesi düşük";
        if (page.net && page.net.up) return "Sistem hazır";
        return "Sistem çevrimdışı";
    }

    function attentionKey() {
        if (!page.summary) return "";
        if (page.net && !page.net.up) return "network";
        if (page.bat && page.bat.present && page.bat.capacity <= 20 && !page.bat.charging)
            return "power";
        if (page.bt && !page.bt.running) return "bluetooth";
        return "";
    }

    function attentionTitle() {
        const key = page.attentionKey();
        if (key === "network") return "Ağ bağlantısı kapalı";
        if (key === "power") return "Pil seviyesi düşük";
        if (key === "bluetooth") return "Bluetooth servisi çalışmıyor";
        return "Sistem sakin";
    }

    function attentionDetail() {
        const key = page.attentionKey();
        if (key === "network") return "İnternet ve Wi-Fi durumunu kontrol et";
        if (key === "power") return "Güç ayarlarını açıp pil davranışını düzenle";
        if (key === "bluetooth") return "Bluetooth sayfasından servisi ve cihazları kontrol et";
        return "İzlenen temel bağlantılarda dikkat gerektiren bir durum yok";
    }

    function attentionAction() {
        const key = page.attentionKey();
        if (key === "network") return "AĞI AÇ";
        if (key === "power") return "GÜCÜ AÇ";
        if (key === "bluetooth") return "BT'Yİ AÇ";
        return "";
    }

    function metricColor(value) {
        const v = page.pct(value);
        if (v >= 88) return page.theme.red;
        if (v >= 68) return page.theme.peach;
        return page.theme.mauve;
    }

    readonly property var metrics: [
        { icon: "󰻠", label: "İşlemci", value: page.sys ? page.sys.cpuPercent : 0,
          valueText: page.sys ? ("%" + page.sys.cpuPercent) : "%0",
          detail: page.sys ? ((page.sys.cpuTemp || "") + (page.sys.cpuTemp ? " · " : "") + "yük " + page.sys.loadAvg) : "veri bekleniyor" },
        { icon: "󰍛", label: "Bellek", value: page.sys ? page.sys.memPercent : 0,
          valueText: page.sys ? ("%" + page.sys.memPercent) : "%0",
          detail: page.sys ? (page.sys.memory || "veri bekleniyor") : "veri bekleniyor" },
        { icon: "󰋊", label: "Depolama /", value: page.sys ? page.sys.diskPercent : 0,
          valueText: page.sys ? ("%" + page.sys.diskPercent) : "%0",
          detail: page.sys ? (page.sys.disk || "veri bekleniyor") : "veri bekleniyor" }
    ]

    readonly property var statusRows: [
        { key: "network", icon: page.net && page.net.up
              ? (page.net.type === "ethernet" ? "󰈀" : "󰤨") : "󰤮",
          label: "Ağ ve internet",
          value: page.net && page.net.up ? page.net.name : (page.net && page.net.wifiOn ? "Bağlı değil" : "Wi-Fi kapalı"),
          detail: page.net && page.net.up ? (page.net.ip || "Bağlantı aktif") : "Ağ ayarlarını aç",
          tone: page.net && page.net.up ? "good" : "quiet" },
        { key: "bluetooth", icon: page.bt && page.bt.powered ? "󰂯" : "󰂲",
          label: "Bluetooth",
          value: page.bt && page.bt.running
              ? (page.bt.powered ? (page.bt.device || (page.bt.connected > 0 ? page.bt.connected + " cihaz bağlı" : "Açık")) : "Kapalı")
              : "Servis kapalı",
          detail: page.bt && page.bt.powered ? (page.bt.connected > 0 ? page.bt.connected + " bağlı" : "Eşleşme bekleniyor") : "Bluetooth ayarlarını aç",
          tone: page.bt && page.bt.powered ? "good" : "quiet" },
        { key: "audio", icon: page.audio && page.audio.muted ? "󰝟" : "󰕾",
          label: "Ses düzeyi",
          value: page.audio && page.audio.sink !== "" ? (page.audio.sink + " · %" + page.audio.volume) : "Cihaz yok",
          detail: page.audio && page.audio.muted ? "Sessiz" : "Varsayılan çıkış",
          tone: page.audio && page.audio.muted ? "warn" : "good" },
        { key: "power", icon: page.bat && page.bat.present ? (page.bat.charging ? "󰂄" : "󰁹") : "󰚥",
          label: "Güç ve pil",
          value: page.bat && page.bat.present ? ("%" + page.bat.capacity + (page.bat.charging ? " · Şarjda" : "")) : "Masaüstü · AC güç",
          detail: page.summary ? page.profileName(page.summary.profile) : "Profil okunuyor",
          tone: page.bat && page.bat.present && page.bat.capacity <= 20 ? "warn" : "good" }
    ]

    readonly property var quickLinks: [
        { key: "appearance", icon: "󰏘", label: "Görünüm" },
        { key: "keybinds", icon: "󰌌", label: "Kısayollar" },
        { key: "widgets", icon: "󰕮", label: "Widget'lar" }
    ]

    spacing: page.s(14)

    // Sayfanın imza detayı: sistem durumunu tek bir yatay bilgi şeridinde
    // topluyor. Sağdaki küçük özet, aşağıdaki tabloları tekrar etmez; sadece
    // hızlı bakışta en önemli iki sayıyı öne çıkarır.
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: page.s(132)
        radius: page.s(12)
        color: page.alpha(page.theme.surface0, 0.28)
        border.width: 1
        border.color: page.alpha(page.theme.text, 0.08)

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: page.s(2)
            color: page.attentionKey() === "" ? page.theme.green : page.theme.peach
            opacity: 0.88
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: page.s(24)
            anchors.rightMargin: page.s(24)
            spacing: page.s(18)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: page.s(5)

                Text {
                    text: "CACHYOS  /  HYPRLAND"
                    color: page.theme.mauve
                    font.family: "JetBrains Mono"
                    font.weight: Font.DemiBold
                    font.pixelSize: page.s(9)
                    font.letterSpacing: page.s(0.8)
                }

                RowLayout {
                    spacing: page.s(8)

                    Text {
                        text: page.systemTitle()
                        color: page.theme.text
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                        font.pixelSize: page.s(20)
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.preferredWidth: page.s(7)
                        Layout.preferredHeight: width
                        radius: width / 2
                        color: page.attentionKey() === "" ? page.theme.green : page.theme.peach
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: page.sys
                          ? ((page.sys.distro || "Linux") + "  ·  " + (page.sys.hostname || "hyprland"))
                          : "Sistem bilgileri toplanıyor…"
                    color: page.theme.subtext0
                    font.family: "JetBrains Mono"
                    font.pixelSize: page.s(10)
                    elide: Text.ElideRight
                }

                RowLayout {
                    spacing: page.s(8)

                    Text {
                        text: page.sys ? ("Açık " + page.sys.uptime) : "Açık —"
                        color: page.theme.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: page.s(9)
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: page.s(12)
                        color: page.alpha(page.theme.text, 0.14)
                    }

                    Text {
                        text: page.summary ? page.profileName(page.summary.profile) : "Profil —"
                        color: page.theme.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: page.s(9)
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: page.s(1)
                Layout.preferredHeight: page.s(72)
                color: page.alpha(page.theme.text, 0.10)
            }

            ColumnLayout {
                Layout.preferredWidth: page.s(126)
                spacing: page.s(3)

                Text {
                    text: "CANLI ÖLÇÜM"
                    color: page.theme.overlay0
                    font.family: "JetBrains Mono"
                    font.weight: Font.DemiBold
                    font.pixelSize: page.s(8)
                    font.letterSpacing: page.s(0.7)
                }

                Text {
                    text: page.sys ? ("%" + page.sys.cpuPercent + " CPU") : "—"
                    color: page.theme.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: page.s(12)
                }

                Text {
                    text: page.sys ? ("%" + page.sys.memPercent + " bellek") : "—"
                    color: page.theme.subtext0
                    font.family: "JetBrains Mono"
                    font.pixelSize: page.s(10)
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: page.width >= page.s(900) ? 2 : 1
        columnSpacing: page.s(12)
        rowSpacing: page.s(12)

        // Kaynaklar bir tablo gibi okunuyor: değer, çizgi ve kısa bağlam.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: metricsColumn.implicitHeight + page.s(18)
            radius: page.s(10)
            color: page.alpha(page.theme.surface0, 0.22)
            border.width: 1
            border.color: page.alpha(page.theme.text, 0.07)

            ColumnLayout {
                id: metricsColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: page.s(12)
                anchors.bottomMargin: page.s(6)
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: page.s(14)
                    Layout.rightMargin: page.s(14)
                    Layout.bottomMargin: page.s(6)

                    Text {
                        text: "KAYNAKLAR"
                        color: page.theme.subtext0
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                        font.pixelSize: page.s(9)
                        font.letterSpacing: page.s(0.6)
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: page.summary ? "canlı ölçüm" : "veri bekleniyor"
                        color: page.theme.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: page.s(8)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: page.alpha(page.theme.text, 0.07)
                }

                Repeater {
                    model: page.metrics

                    delegate: Item {
                        id: metricRow
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: page.s(64)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: page.s(14)
                            anchors.rightMargin: page.s(14)
                            spacing: page.s(10)

                            Text {
                                text: metricRow.modelData.icon
                                color: page.theme.mauve
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: page.s(16)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: page.s(3)

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: metricRow.modelData.label
                                        color: page.theme.text
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: page.s(10)
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: metricRow.modelData.valueText
                                        color: page.metricColor(metricRow.modelData.value)
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.DemiBold
                                        font.pixelSize: page.s(10)
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: page.s(4)
                                    radius: height / 2
                                    color: page.alpha(page.theme.surface2, 0.55)
                                    clip: true

                                    Rectangle {
                                        width: parent.width * page.pct(metricRow.modelData.value) / 100
                                        height: parent.height
                                        radius: height / 2
                                        color: page.metricColor(metricRow.modelData.value)
                                        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: metricRow.modelData.detail
                                    color: page.theme.overlay0
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: page.s(8)
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle {
                            visible: metricRow.index < page.metrics.length - 1
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: page.s(14)
                            anchors.rightMargin: page.s(14)
                            anchors.bottom: parent.bottom
                            height: 1
                            color: page.alpha(page.theme.text, 0.06)
                        }
                    }
                }
            }
        }

        // Bağlantılar kaynaklardan farklı okunuyor: her satır gerçek bir
        // hedefe gider, bu yüzden yön oku ve hover yalnızca burada kullanılır.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: statusColumn.implicitHeight + page.s(18)
            radius: page.s(10)
            color: page.alpha(page.theme.surface0, 0.22)
            border.width: 1
            border.color: page.alpha(page.theme.text, 0.07)

            ColumnLayout {
                id: statusColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: page.s(12)
                anchors.bottomMargin: page.s(6)
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: page.s(14)
                    Layout.rightMargin: page.s(14)
                    Layout.bottomMargin: page.s(6)

                    Text {
                        text: "BAĞLANTILAR"
                        color: page.theme.subtext0
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                        font.pixelSize: page.s(9)
                        font.letterSpacing: page.s(0.6)
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "ayrıntı için seç"
                        color: page.theme.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: page.s(8)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: page.alpha(page.theme.text, 0.07)
                }

                Repeater {
                    model: page.statusRows

                    delegate: Item {
                        id: statusRow
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: page.s(64)

                        readonly property color tone: statusRow.modelData.tone === "good"
                            ? page.theme.green
                            : (statusRow.modelData.tone === "warn" ? page.theme.peach : page.theme.overlay0)

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: page.s(7)
                            anchors.rightMargin: page.s(7)
                            radius: page.s(7)
                            color: statusMouse.containsMouse ? page.alpha(page.theme.surface1, 0.34) : "transparent"
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: page.s(7)
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: page.s(2)
                            color: statusRow.tone
                            opacity: statusMouse.containsMouse ? 1 : 0.65
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: page.s(20)
                            anchors.rightMargin: page.s(14)
                            spacing: page.s(10)

                            Text {
                                text: statusRow.modelData.icon
                                color: statusRow.tone
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: page.s(17)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: page.s(2)

                                Text {
                                    text: statusRow.modelData.label
                                    color: page.theme.text
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: page.s(10)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: statusRow.modelData.value
                                    color: page.theme.subtext0
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: page.s(10)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: statusRow.modelData.detail
                                    color: page.theme.overlay0
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: page.s(8)
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                text: "󰅂"
                                color: statusMouse.containsMouse ? page.theme.mauve : page.theme.overlay0
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: page.s(12)
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                        }

                        MouseArea {
                            id: statusMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.openPage(statusRow.modelData.key)
                        }

                        Rectangle {
                            visible: statusRow.index < page.statusRows.length - 1
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: page.s(14)
                            anchors.rightMargin: page.s(14)
                            anchors.bottom: parent.bottom
                            height: 1
                            color: page.alpha(page.theme.text, 0.06)
                        }
                    }
                }
            }
        }
    }

    // Bu bant artık dekoratif buton ızgarası değil; yalnızca sık kullanılan
    // üç rotayı, sayfanın ana görevini bölmeden erişilebilir tutuyor.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: page.s(58)
        radius: page.s(10)
        color: page.alpha(page.theme.surface0, 0.16)
        border.width: 1
        border.color: page.alpha(page.theme.text, 0.07)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: page.s(10)
            anchors.rightMargin: page.s(10)
            spacing: page.s(5)

            Repeater {
                model: page.quickLinks

                delegate: Item {
                    id: quickRow
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        radius: page.s(7)
                        color: quickMouse.containsMouse ? page.alpha(page.theme.mauve, 0.10) : "transparent"
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: page.s(7)

                        Text {
                            text: quickRow.modelData.icon
                            color: quickMouse.containsMouse ? page.theme.mauve : page.theme.subtext0
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: page.s(13)
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }

                        Text {
                            text: quickRow.modelData.label
                            color: page.theme.subtext0
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(9)
                        }
                    }

                    MouseArea {
                        id: quickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.openPage(quickRow.modelData.key)
                    }
                }
            }
        }
    }

    // Kullanıcının sistemdeki tek dikkat noktasını, rotaları bölmeden görünür
    // kılan son satır. Sorun yoksa yeşil yerine nötr metin kullanıyoruz.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: page.s(58)
        radius: page.s(10)
        color: page.alpha(page.attentionKey() === "" ? page.theme.green : page.theme.peach, 0.06)
        border.width: 1
        border.color: page.alpha(page.attentionKey() === "" ? page.theme.green : page.theme.peach, 0.16)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: page.s(16)
            anchors.rightMargin: page.s(10)
            spacing: page.s(10)

            Rectangle {
                Layout.preferredWidth: page.s(2)
                Layout.preferredHeight: page.s(26)
                radius: width / 2
                color: page.attentionKey() === "" ? page.theme.green : page.theme.peach
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: page.s(2)

                Text {
                    text: page.attentionTitle()
                    color: page.theme.text
                    font.family: "JetBrains Mono"
                    font.weight: Font.DemiBold
                    font.pixelSize: page.s(10)
                }

                Text {
                    Layout.fillWidth: true
                    text: page.attentionDetail()
                    color: page.theme.overlay0
                    font.family: "JetBrains Mono"
                    font.pixelSize: page.s(8)
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: page.attentionKey() !== ""
                Layout.preferredWidth: attentionButton.implicitWidth + page.s(22)
                Layout.preferredHeight: page.s(30)
                radius: page.s(8)
                color: attentionMouse.containsMouse ? page.alpha(page.theme.peach, 0.22) : page.alpha(page.theme.peach, 0.10)
                border.width: 1
                border.color: page.alpha(page.theme.peach, 0.38)
                Behavior on color { ColorAnimation { duration: 160 } }

                Text {
                    id: attentionButton
                    anchors.centerIn: parent
                    text: page.attentionAction()
                    color: page.theme.text
                    font.family: "JetBrains Mono"
                    font.weight: Font.DemiBold
                    font.pixelSize: page.s(8)
                    font.letterSpacing: page.s(0.4)
                }

                MouseArea {
                    id: attentionMouse
                    anchors.fill: parent
                    enabled: page.attentionKey() !== ""
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.openPage(page.attentionKey())
                }
            }
        }
    }
}
