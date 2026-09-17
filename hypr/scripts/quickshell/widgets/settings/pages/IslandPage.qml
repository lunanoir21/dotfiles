pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../parts"

// Widget kataloğu.
//
// Bu sayfa sistemdeki tüm Quickshell yüzeylerini tek bir listede toplar.
// Ayarlar doğrudan listeye yığılmaz: soldan bir yüzey seçilir, sağda yalnızca
// o yüzeyin inspector'ı açılır. Böylece katalog büyüdükçe arayüz kalabalıklaşmaz.
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0
    property string selectedWidget: "topbar"

    readonly property bool hasSave: false
    readonly property bool dirty: false
    function save() {}

    function s(v) { return Math.round(v * page.sf); }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    signal sectionOpened(string section)
    signal pageOpened(string key)

    readonly property var widgetItems: [
        { key: "topbar",        icon: "󰆍", name: "Top Bar",          kind: "Sabit", desc: "Çalışma alanları, durum ve hızlı erişim" },
        { key: "dynamicIsland", icon: "󰣇", name: "Dynamic Island",   kind: "Ayar",  desc: "Bildirim, medya, saat ve zaman araçları" },
        { key: "quay",          icon: "󱂬", name: "Quay",             kind: "Ayar",  desc: "Dikey uygulama başlatıcı: sabitlenenler, klasörler ve açık pencereler" },
        { key: "sidebarcenter", icon: "󰕮", name: "Sidebar Center",   kind: "Sabit", desc: "Bildirim geçmişi ve sistem merkezi" },
        { key: "applauncher",   icon: "󰀻", name: "App Launcher",     kind: "Sabit", desc: "Uygulama arama ve başlatma yüzeyi" },
        { key: "clipboard",     icon: "󰅍", name: "Clipboard",         kind: "Sabit", desc: "Yerel pano geçmişi" },
        { key: "mixer",         icon: "󰕾", name: "Ses Mikseri",       kind: "Sabit", desc: "Uygulama bazlı ses kanalları" },
        { key: "processes",     icon: "󰒓", name: "Süreçler",           kind: "Sabit", desc: "CPU ve bellek kullanımını izler" },
        { key: "workspaces",    icon: "󰍹", name: "Çalışma Alanları",  kind: "Sabit", desc: "Tüm workspace'leri tek bakışta gösterir" },
        { key: "wallpaper",     icon: "󰋩", name: "Duvar Kağıdı",      kind: "Sabit", desc: "Duvar kağıdı seçici ve önizleme" }
    ]

    readonly property var selectedMeta: {
        for (let i = 0; i < page.widgetItems.length; i++) {
            if (page.widgetItems[i].key === page.selectedWidget)
                return page.widgetItems[i];
        }
        return page.widgetItems[0];
    }

    // Görsel, saat, medya ve bildirim ayrıntıları adanın odaklı menüsünde
    // kalır; güç ve veri davranışı ise ana Güç & pil sayfasının sorumluluğudur.
    property string notifDesign: "classic"
    property string notifEntrance: "drop"
    property bool notifCardOn: true
    property string callView: "detailed"

    readonly property string islandShell: Quickshell.shellDir + "/Shell.qml"

    readonly property var routesByWidget: ({
        "topbar": [
            { icon: "󰏘", label: "Görünüm ayarları", hint: "Barın yazı, renk ve pencere davranışı", page: "appearance" },
            { icon: "󰌌", label: "Kısayollar", hint: "Bar düğmelerinin klavye davranışı", page: "keybinds" }
        ],
        "sidebarcenter": [
            { icon: "󰌌", label: "Kısayollar", hint: "Sidebar Center'ı açan tuşu düzenle", page: "keybinds" },
            { icon: "󰂚", label: "Bildirimler", hint: "Bildirim geçmişi ve sistem bildirimleri", page: "general" }
        ],
        "applauncher": [
            { icon: "󰌌", label: "Kısayollar", hint: "Uygulama aramasını açan tuşu düzenle", page: "keybinds" }
        ],
        "clipboard": [
            { icon: "󰌌", label: "Kısayollar", hint: "Pano geçmişini açan tuşu düzenle", page: "keybinds" }
        ],
        "mixer": [
            { icon: "󰕾", label: "Ses ayarları", hint: "Çıkış, giriş ve seviye ayarları", page: "audio" },
            { icon: "󰌌", label: "Kısayollar", hint: "Ses mikserini açan tuşu düzenle", page: "keybinds" }
        ],
        "processes": [
            { icon: "󰌌", label: "Kısayollar", hint: "Süreçler panelini açan tuşu düzenle", page: "keybinds" }
        ],
        "workspaces": [
            { icon: "󰍹", label: "Monitör ve workspace ayarları", hint: "Ekran düzeni ve workspace sayısı", page: "monitors" },
            { icon: "󰌌", label: "Kısayollar", hint: "Workspace görünümünü açan tuşu düzenle", page: "keybinds" }
        ],
        "wallpaper": [
            { icon: "󰋩", label: "Duvar kağıdı ayarları", hint: "Klasör ve masaüstü görünümü", page: "general" }
        ],
        "quay": [
            { icon: "󰌌", label: "Kısayollar", hint: "Quay'i açan tuşu düzenle", page: "keybinds" }
        ]
    })

    function routesFor(key) {
        return page.routesByWidget[key] || [];
    }

    function islandCall(fn, arg) {
        Quickshell.execDetached(["quickshell", "-p", page.islandShell,
            "ipc", "call", "dynamicIsland", fn, arg]);
    }

    // Quay owns its own settings surface and its own settings file; this page
    // only mirrors a summary and hands over to it.
    property string quayMode: "hover"
    property string quayEdge: "right"
    property int quayColumns: 1
    property int quayRows: 6
    property int quayPinCount: 0

    readonly property var quayModeLabels: ({
        "always": "Her zaman açık",
        "hover": "İmleçle açılır",
        "shortcut": "Kısayolla açılır"
    })

    readonly property var quayEdgeLabels: ({
        "left": "Sol kenar",
        "right": "Sağ kenar",
        "top": "Üst kenar",
        "bottom": "Alt kenar"
    })

    function quayCall(fn) {
        Quickshell.execDetached(["quickshell", "-p", page.islandShell, "ipc", "call", "quay", fn]);
    }

    FileView {
        id: quaySettings
        path: Quickshell.env("HOME") + "/.config/quickshell/quay/settings.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: quaySettings.reload()
        onTextChanged: page.readQuaySettings()
        Component.onCompleted: page.readQuaySettings()
    }

    function readQuaySettings() {
        try {
            let raw = String(quaySettings.text() || "").trim();
            if (!raw) return;
            let parsed = JSON.parse(raw);
            let trigger = parsed.trigger || {};
            let layout = parsed.layout || {};
            if (typeof trigger.mode === "string") page.quayMode = trigger.mode;
            if (typeof trigger.edge === "string") page.quayEdge = trigger.edge;
            if (typeof layout.columns === "number") page.quayColumns = layout.columns;
            if (typeof layout.rows === "number") page.quayRows = layout.rows;
            page.quayPinCount = Array.isArray(parsed.items) ? parsed.items.length : 0;
        } catch (e) { }
    }

    FileView {
        id: islandSettings
        path: Quickshell.env("HOME") + "/.config/quickshell/dynamic-island/settings.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: page.readIslandSettings()
        Component.onCompleted: page.readIslandSettings()
    }

    function readIslandSettings() {
        try {
            let raw = String(islandSettings.text() || "").trim();
            if (!raw) return;
            let parsed = JSON.parse(raw);
            if (typeof parsed.notificationLayout === "string") page.notifDesign = parsed.notificationLayout;
            if (typeof parsed.notificationEntrance === "string") page.notifEntrance = parsed.notificationEntrance;
            if (typeof parsed.notificationPopup === "boolean") page.notifCardOn = parsed.notificationPopup;
            if (typeof parsed.callView === "string") page.callView = parsed.callView;
        } catch (e) { }
    }

    spacing: s(14)

    Rectangle {
        id: workspace
        Layout.fillWidth: true
        implicitHeight: page.s(610)
        radius: page.s(14)
        color: page.alpha(page.theme.surface0, 0.30)
        border.width: 1
        border.color: page.alpha(page.theme.text, 0.08)

        RowLayout {
            anchors.fill: parent
            anchors.margins: page.s(1)
            spacing: 0

            // Sol taraf katalogdur. Satırlar bilerek kısa tutuldu; 11 yüzey
            // tek bakışta görünür, seçili olan ince bir çizgiyle ayrılır.
            ColumnLayout {
                Layout.preferredWidth: page.s(288)
                Layout.minimumWidth: page.s(245)
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.s(54)
                    Layout.leftMargin: page.s(16)
                    Layout.rightMargin: page.s(14)

                    Text {
                        text: "YÜZEYLER"
                        color: page.theme.subtext0
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                        font.pixelSize: page.s(9)
                        font.letterSpacing: page.s(0.7)
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: page.selectedMeta.name
                        color: page.theme.mauve
                        font.family: "JetBrains Mono"
                        font.pixelSize: page.s(9)
                        elide: Text.ElideRight
                        Layout.maximumWidth: page.s(110)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: page.alpha(page.theme.text, 0.07)
                }

                Flickable {
                    id: widgetFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: widgetList.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: widgetList
                        width: widgetFlick.width
                        spacing: 0

                        Repeater {
                            model: page.widgetItems

                            delegate: Item {
                                id: widgetRow
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredHeight: page.s(50)

                                readonly property bool selected: page.selectedWidget === widgetRow.modelData.key

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.leftMargin: page.s(8)
                                    anchors.rightMargin: page.s(8)
                                    radius: page.s(8)
                                    color: widgetRow.selected
                                           ? page.alpha(page.theme.mauve, 0.10)
                                           : (rowMouse.containsMouse
                                              ? page.alpha(page.theme.surface1, 0.38)
                                              : "transparent")
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: page.s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: page.s(2)
                                    height: page.s(24)
                                    radius: width / 2
                                    color: page.theme.mauve
                                    opacity: widgetRow.selected ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 160 } }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: page.s(22)
                                    anchors.rightMargin: page.s(16)
                                    spacing: page.s(11)

                                    Text {
                                        text: widgetRow.modelData.icon
                                        color: widgetRow.selected ? page.theme.mauve : page.theme.subtext0
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: page.s(16)
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            Layout.fillWidth: true
                                            text: widgetRow.modelData.name
                                            color: widgetRow.selected ? page.theme.text : page.theme.subtext0
                                            font.family: "JetBrains Mono"
                                            font.weight: widgetRow.selected ? Font.DemiBold : Font.Normal
                                            font.pixelSize: page.s(10)
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: widgetRow.modelData.kind
                                            color: page.theme.overlay0
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: page.s(8)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: widgetRow.selected ? "󰅂" : ""
                                        color: page.theme.mauve
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: page.s(12)
                                        opacity: widgetRow.selected ? 0.9 : 0
                                    }
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.selectedWidget = widgetRow.modelData.key
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: page.s(3)
                            radius: width / 2
                            color: page.theme.surface2
                            opacity: 0.8
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: page.alpha(page.theme.text, 0.08)
            }

            // Sağ taraf inspector'dır. Loader yalnızca seçilen widget'ın
            // ayarlarını üretir; diğer yüzeylerin kontrolleri ekranda kalmaz.
            ColumnLayout {
                id: inspector
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: page.s(26)
                Layout.rightMargin: page.s(26)
                Layout.topMargin: page.s(22)
                Layout.bottomMargin: page.s(18)
                spacing: page.s(16)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: page.s(13)

                    Rectangle {
                        Layout.preferredWidth: page.s(40)
                        Layout.preferredHeight: page.s(40)
                        radius: page.s(11)
                        color: page.alpha(page.theme.mauve, 0.10)
                        border.width: 1
                        border.color: page.alpha(page.theme.mauve, 0.25)

                        Text {
                            anchors.centerIn: parent
                            text: page.selectedMeta.icon
                            color: page.theme.mauve
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: page.s(18)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: page.s(2)

                        Text {
                            text: page.selectedMeta.name
                            color: page.theme.text
                            font.family: "JetBrains Mono"
                            font.weight: Font.DemiBold
                            font.pixelSize: page.s(16)
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: page.selectedMeta.desc
                            color: page.theme.overlay0
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(10)
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: page.selectedMeta.kind === "Ayar" ? "AYARLANABİLİR" : "SİSTEM YÜZEYİ"
                        color: page.selectedMeta.kind === "Ayar" ? page.theme.mauve : page.theme.overlay0
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                        font.pixelSize: page.s(8)
                        font.letterSpacing: page.s(0.5)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: page.alpha(page.theme.text, 0.08)
                }

                Loader {
                    id: detailLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: {
                        if (page.selectedWidget === "dynamicIsland") return islandSettingsComponent;
                        if (page.selectedWidget === "quay") return quaySettingsComponent;
                        return genericSettings;
                    }
                    opacity: 1
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Connections {
                        target: page
                        function onSelectedWidgetChanged() {
                            detailLoader.opacity = 0.0;
                            detailReveal.restart();
                        }
                    }

                    Timer {
                        id: detailReveal
                        interval: 30
                        onTriggered: detailLoader.opacity = 1.0
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Inspector içerikleri
    // ------------------------------------------------------------------
    Component {
        id: islandSettingsComponent

        ColumnLayout {
            width: detailLoader.width
            spacing: page.s(12)

            Text {
                text: "Dynamic Island"
                color: page.theme.subtext0
                font.family: "JetBrains Mono"
                font.weight: Font.DemiBold
                font.pixelSize: page.s(10)
                font.letterSpacing: page.s(0.6)
            }

            Text {
                Layout.fillWidth: true
                text: "Güç ve veri davranışını ana Güç & pil sayfasından yönetebilirsin. Renk, saat, medya ve bildirim ayrıntıları için odaklı ada menüsünü aç."
                color: page.theme.overlay0
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(10)
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: islandActions.implicitHeight + page.s(12)
                radius: page.s(10)
                color: page.alpha(page.theme.surface1, 0.20)
                border.width: 1
                border.color: page.alpha(page.theme.text, 0.07)

                ColumnLayout {
                    id: islandActions
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: page.s(6)
                    anchors.bottomMargin: page.s(6)
                    spacing: page.s(1)

                    RowAction {
                        theme: page.theme; sf: page.sf
                        label: "Güç & pil ayarları"
                        hint: "Ana Settings içindeki Dynamic Island güç ve veri bölümü"
                        buttonText: "AÇ"
                        buttonIcon: "󰅂"
                        onTriggered: page.pageOpened("power")
                    }

                    RowAction {
                        theme: page.theme; sf: page.sf
                        label: "Ada ayarlarını aç"
                        hint: "8 bölüm: görünüm, saat, medya, bildirim ve daha fazlası"
                        buttonText: "AÇ"
                        buttonIcon: "󰅂"
                        onTriggered: page.sectionOpened("appearance")
                    }

                    RowAction {
                        theme: page.theme; sf: page.sf
                        label: "Örnek bildirim gönder"
                        hint: "Mevcut ada görünümünü hızlıca test et"
                        buttonText: "DENE"
                        buttonIcon: "󰂚"
                        onTriggered: page.islandCall("notifyTest", "")
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: quickIsland.implicitHeight + page.s(16)
                radius: page.s(10)
                color: page.alpha(page.theme.mauve, 0.06)
                border.width: 1
                border.color: page.alpha(page.theme.mauve, 0.16)

                ColumnLayout {
                    id: quickIsland
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: page.s(12)
                    spacing: page.s(4)

                    Text {
                        text: "Hızlı durum"
                        color: page.theme.text
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                        font.pixelSize: page.s(10)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.notifCardOn ? "Bildirim kartı açık" : "Bildirim kartı kapalı"
                        color: page.theme.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: page.s(10)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Ayrıntılı bildirim ve arama seçenekleri için yukarıdaki menüyü aç."
                        color: page.theme.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: page.s(9)
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: quaySettingsComponent

        ColumnLayout {
            width: detailLoader.width
            spacing: page.s(12)

            Text {
                text: "Quay kendi ayar panelini taşıyor"
                color: page.theme.subtext0
                font.family: "JetBrains Mono"
                font.weight: Font.DemiBold
                font.pixelSize: page.s(10)
                font.letterSpacing: page.s(0.6)
            }

            Text {
                Layout.fillWidth: true
                text: "Quay ayrı bir widget: ayarları kendi dosyasında (~/.config/quickshell/quay/settings.json) tutuyor ve kendi panelinden düzenleniyor. Bu sayfa yalnızca özeti gösterir."
                color: page.theme.overlay0
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(10)
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: quaySummary.implicitHeight + page.s(20)
                radius: page.s(10)
                color: page.alpha(page.theme.surface1, 0.20)
                border.width: 1
                border.color: page.alpha(page.theme.text, 0.07)

                GridLayout {
                    id: quaySummary
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: page.s(14)
                    anchors.rightMargin: page.s(14)
                    columns: 2
                    columnSpacing: page.s(10)
                    rowSpacing: page.s(4)

                    Repeater {
                        model: [
                            { label: "Tetikleme", value: page.quayModeLabels[page.quayMode] || page.quayMode },
                            { label: "Kenar", value: page.quayEdgeLabels[page.quayEdge] || page.quayEdge },
                            { label: "Izgara", value: page.quayColumns + " sütun × " + page.quayRows + " satır" },
                            { label: "Sabitlenen", value: page.quayPinCount + " öğe" }
                        ]

                        delegate: Text {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.label + ": " + modelData.value
                            color: page.theme.text
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(10)
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: quayRoutes.implicitHeight + page.s(12)
                radius: page.s(10)
                color: page.alpha(page.theme.surface1, 0.20)
                border.width: 1
                border.color: page.alpha(page.theme.text, 0.07)

                ColumnLayout {
                    id: quayRoutes
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: page.s(6)
                    spacing: page.s(1)

                    RowNav {
                        theme: page.theme
                        sf: page.sf
                        icon: "󰒓"
                        label: "Quay ayarlarını aç"
                        hint: "Tetikleme, ızgara ve sabitlenen uygulamalar"
                        onActivated: page.quayCall("settings")
                    }

                    RowNav {
                        theme: page.theme
                        sf: page.sf
                        icon: "󰑐"
                        label: "Uygulama listesini yenile"
                        hint: "Yeni kurulan uygulamalar görünmüyorsa"
                        onActivated: page.quayCall("refreshApps")
                    }

                    Repeater {
                        model: page.routesFor("quay")

                        delegate: RowNav {
                            required property var modelData
                            theme: page.theme
                            sf: page.sf
                            icon: modelData.icon
                            label: modelData.label
                            hint: modelData.hint
                            onActivated: page.pageOpened(modelData.page)
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: genericSettings

        ColumnLayout {
            width: detailLoader.width
            spacing: page.s(12)

            Text {
                text: "Bu yüzey nasıl ayarlanır?"
                color: page.theme.subtext0
                font.family: "JetBrains Mono"
                font.weight: Font.DemiBold
                font.pixelSize: page.s(10)
                font.letterSpacing: page.s(0.6)
            }

            Text {
                Layout.fillWidth: true
                text: "Bu widget'ın ayrı bir görünüm paneli yok. Aşağıdaki bağlantılar yalnızca ilgili ayar alanını açar; yüzeyin kendisi olduğu yerde kalır."
                color: page.theme.overlay0
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(10)
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: genericRoutes.implicitHeight + page.s(12)
                radius: page.s(10)
                color: page.alpha(page.theme.surface1, 0.20)
                border.width: 1
                border.color: page.alpha(page.theme.text, 0.07)

                ColumnLayout {
                    id: genericRoutes
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: page.s(6)
                    anchors.bottomMargin: page.s(6)
                    spacing: page.s(1)

                    Repeater {
                        model: page.routesFor(page.selectedWidget)

                        delegate: RowNav {
                            required property var modelData
                            theme: page.theme
                            sf: page.sf
                            icon: modelData.icon
                            label: modelData.label
                            hint: modelData.hint
                            onActivated: page.pageOpened(modelData.page)
                        }
                    }

                    Text {
                        visible: page.routesFor(page.selectedWidget).length === 0
                        Layout.fillWidth: true
                        Layout.leftMargin: page.s(16)
                        Layout.rightMargin: page.s(16)
                        Layout.topMargin: page.s(14)
                        Layout.bottomMargin: page.s(14)
                        text: "Bu yüzeyin bağımsız bir ayarı bulunmuyor."
                        color: page.theme.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: page.s(10)
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
