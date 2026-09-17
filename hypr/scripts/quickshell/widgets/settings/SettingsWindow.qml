pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../core"
import "parts"
import "pages"

// Ayarlar penceresi: sakin bir kontrol merkezi.
//
// Renkler MatugenColors'tan gelir; bu dosya yalnızca hiyerarşiyi, boşluğu ve
// hareket ritmini belirler. Hareket üç yerde anlam taşır: pencerenin sahneye
// gelişi, aktif kategorinin izlenmesi ve sayfa içeriğinin yer değiştirmesi.
Item {
    id: root

    property var notifModel: null
    property var liveNotifs: ({})
    property real layoutWidth: width
    property real layoutHeight: height

    MatugenColors { id: colors }
    Scaler { id: scaler; currentWidth: Screen.width; currentHeight: Screen.height }

    function s(value) { return scaler.s(value); }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    readonly property int tFast: 150
    readonly property int tBase: 230
    readonly property int tPage: 360
    readonly property int navStagger: 24

    // ---------------------------------------------------------------
    // Gezinme modeli
    // ---------------------------------------------------------------
    property string currentKey: "overview"
    property string activeMode: ""
    property real activeNavY: 0
    property real activeNavH: 0
    property bool navIndicatorReady: false

    readonly property var pageOrder: [
        "overview", "network", "bluetooth", "audio", "power",
        "appearance", "keybinds", "monitors", "general", "startup",
        "weather", "widgets"
    ]

    readonly property var navGroups: [
        { title: "", items: [
            { key: "overview", icon: "󰋜", name: "Genel bakış", desc: "Sistemin canlı durumu" }
        ]},
        { title: "SİSTEM", items: [
            { key: "network", icon: "󰤨", name: "Ağ", desc: "Wi-Fi, Ethernet ve VPN" },
            { key: "bluetooth", icon: "󰂯", name: "Bluetooth", desc: "Cihazları eşleştir ve bağla" },
            { key: "audio", icon: "󰕾", name: "Ses", desc: "Çıkış, giriş ve seviyeler" },
            { key: "power", icon: "󰁹", name: "Güç & pil", desc: "Pil ve güç davranışı" }
        ]},
        { title: "MASAÜSTÜ", items: [
            { key: "appearance", icon: "󰏘", name: "Görünüm", desc: "Pencereler ve animasyon" },
            { key: "keybinds", icon: "󰌌", name: "Kısayollar", desc: "Klavye kısayolları" },
            { key: "monitors", icon: "󰍹", name: "Monitörler", desc: "Ekran ve ölçek düzeni" }
        ]},
        { title: "YÖNETİM", items: [
            { key: "general", icon: "󰒓", name: "Genel", desc: "Arayüz, klavye ve duvar kağıdı" },
            { key: "startup", icon: "󰅐", name: "Başlangıç", desc: "Oturum açılış komutları" },
            { key: "weather", icon: "󰖐", name: "Hava", desc: "OpenWeather bağlantısı" },
            { key: "widgets", icon: "󰕮", name: "Widget'lar", desc: "Tüm sistem yüzeyleri" }
        ]}
    ]

    readonly property var currentMeta: {
        for (let g = 0; g < root.navGroups.length; g++) {
            const items = root.navGroups[g].items;
            for (let i = 0; i < items.length; i++) {
                if (items[i].key === root.currentKey) return items[i];
            }
        }
        return { name: "Genel bakış", desc: "Sistemin canlı durumu" };
    }

    function goPage(key) {
        if (!key) return;
        if (key.indexOf("island:") === 0) {
            root.openIslandSection(key.substring(7));
            return;
        }
        if (root.pageOrder.indexOf(key) < 0) return;
        root.currentKey = key;
        root.clearSearch();
    }

    function openIslandSection(section) {
        Quickshell.execDetached(["quickshell", "-p",
            Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/Shell.qml",
            "ipc", "call", "dynamicIsland", "settingsSection", section]);
        Quickshell.execDetached(["bash",
            Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    onActiveModeChanged: {
        if (root.activeMode !== "" && root.pageOrder.indexOf(root.activeMode) >= 0)
            root.goPage(root.activeMode);
    }

    // ---------------------------------------------------------------
    // Arama
    // ---------------------------------------------------------------
    SettingsIndex { id: idx }
    property string searchText: ""
    property int resultIndex: 0
    readonly property bool searching: root.searchText.trim() !== ""
    readonly property var results: root.searching ? idx.search(root.searchText) : []

    function clearSearch() {
        root.searchText = "";
        searchField.clear();
        root.resultIndex = 0;
    }

    function moveResult(delta) {
        if (root.results.length === 0) return;
        let next = root.resultIndex + delta;
        if (next < 0) next = root.results.length - 1;
        if (next >= root.results.length) next = 0;
        root.resultIndex = next;
    }

    function submitResult() {
        if (root.results.length === 0) return;
        const result = root.results[Math.min(root.resultIndex, root.results.length - 1)];
        root.goPage(result.kind === "page" ? result.hint.page : result.entry.page);
    }

    onSearchTextChanged: root.resultIndex = 0

    // ---------------------------------------------------------------
    // Sistem özeti — tek Process, tek poll döngüsü
    // ---------------------------------------------------------------
    readonly property string summaryScript: Qt.resolvedUrl("system/summary.sh").toString().replace(/^file:\/\//, "")
    property var summary: null

    Process {
        id: summaryProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.summary = JSON.parse(this.text.trim()); } catch (e) { }
            }
        }
    }

    function pollSummary() {
        if (summaryProc.running) return;
        summaryProc.command = ["bash", "-c", "bash '" + root.summaryScript + "'"];
        summaryProc.running = true;
    }

    Timer {
        interval: 6000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.pollSummary()
    }

    function navBadge(key) {
        const sm = root.summary;
        if (!sm) return "";
        if (key === "network")
            return sm.network.up ? sm.network.name : (sm.network.wifiOn ? "bağlı değil" : "kapalı");
        if (key === "bluetooth") {
            if (!sm.bluetooth.running) return "kapalı";
            if (!sm.bluetooth.powered) return "kapalı";
            return sm.bluetooth.connected > 0 ? String(sm.bluetooth.connected) : "açık";
        }
        if (key === "audio") return sm.audio.muted ? "sessiz" : "%" + sm.audio.volume;
        if (key === "power") return sm.battery.present ? "%" + sm.battery.capacity : "";
        return "";
    }

    function navBadgeTone(key) {
        const sm = root.summary;
        if (!sm) return colors.overlay0;
        if (key === "network") return sm.network.up ? colors.green : colors.overlay0;
        if (key === "bluetooth") return sm.bluetooth.powered ? colors.green : colors.overlay0;
        if (key === "audio") return sm.audio.muted ? colors.peach : colors.overlay0;
        if (key === "power") {
            if (!sm.battery.present) return colors.overlay0;
            if (sm.battery.charging) return colors.green;
            if (sm.battery.capacity <= 20) return colors.red;
        }
        return colors.overlay0;
    }

    // ---------------------------------------------------------------
    // Giriş ritmi
    // ---------------------------------------------------------------
    property bool frameReady: false
    property bool navReady: false
    property bool bodyReady: false

    Timer { id: frameKick; interval: 16; onTriggered: root.frameReady = true }
    Timer { id: navKick; interval: 85; onTriggered: root.navReady = true }
    Timer { id: bodyKick; interval: 145; onTriggered: root.bodyReady = true }
    Timer { id: focusKick; interval: 120; onTriggered: searchField.focusField() }

    onVisibleChanged: {
        if (root.visible) {
            root.frameReady = false;
            root.navReady = false;
            root.bodyReady = false;
            frameKick.restart();
            navKick.restart();
            bodyKick.restart();
            focusKick.restart();
            root.pollSummary();
        } else {
            root.clearSearch();
            root.frameReady = false;
            root.navReady = false;
            root.bodyReady = false;
        }
    }

    Component.onCompleted: {
        if (root.visible) {
            root.frameReady = true;
            root.navReady = true;
            root.bodyReady = true;
        }
    }

    readonly property var activePage: {
        const index = root.pageOrder.indexOf(root.currentKey);
        return (index >= 0 && index < pageStack.children.length) ? pageStack.children[index] : null;
    }
    readonly property bool pageHasSave: root.activePage && root.activePage.hasSave === true
    readonly property bool pageDirty: root.activePage && root.activePage.dirty === true

    // ---------------------------------------------------------------
    // Görsel kabuk
    // ---------------------------------------------------------------
    Rectangle {
        id: shell
        anchors.fill: parent
        radius: root.s(22)
        color: colors.crust
        border.width: 1
        border.color: root.alpha(colors.text, 0.1)
        clip: true
        opacity: root.frameReady ? 1 : 0
        scale: root.frameReady ? 1 : 0.985
        Behavior on opacity { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: root.tPage; easing.type: Easing.OutCubic } }

        // İnce üst sinyal hattı; pencerenin merkezini tarif ediyor ama dikkat
        // isteyen parlak bir dekorasyona dönüşmüyor.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.s(2)
            color: colors.mauve
            opacity: root.frameReady ? 0.8 : 0
            Behavior on opacity { NumberAnimation { duration: root.tBase } }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // -------------------------------------------------------
            // Üst başlık ve arama
            // -------------------------------------------------------
            RowLayout {
                id: topBar
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(76)
                Layout.leftMargin: root.s(24)
                Layout.rightMargin: root.s(22)
                spacing: root.s(18)
                opacity: root.frameReady ? 1 : 0
                transform: Translate {
                    y: root.frameReady ? 0 : -root.s(10)
                    Behavior on y { NumberAnimation { duration: root.tPage; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    Layout.preferredWidth: root.s(190)
                    spacing: root.s(2)
                    Text {
                        text: "AYARLAR"
                        color: colors.text
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: root.s(17)
                        font.letterSpacing: root.s(0.7)
                    }
                    Text {
                        text: "CACHYOS  /  HYPRLAND"
                        color: colors.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(9)
                        font.letterSpacing: root.s(0.5)
                    }
                }

                SearchField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.s(500)
                    theme: colors
                    sf: scaler.baseScale
                    placeholder: "Ayarlarda ara  ·  wifi, boşluk, pil…"
                    resultCount: root.searching ? root.results.length : -1
                    onTextChanged: root.searchText = text
                    onEscaped: root.clearSearch()
                    onSubmitted: root.submitResult()
                    onNavigate: (delta) => root.moveResult(delta)
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: root.s(8)
                    Text {
                        text: root.summary ? "●  canlı" : "○  okunuyor"
                        color: root.summary ? colors.green : colors.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(9)
                        Behavior on color { ColorAnimation { duration: root.tBase } }
                    }

                    Rectangle {
                        visible: root.pageHasSave && !root.searching
                        Layout.preferredWidth: root.s(104)
                        Layout.preferredHeight: root.s(34)
                        radius: root.s(11)
                        color: root.pageDirty ? root.alpha(colors.green, saveMouse.containsMouse ? 0.28 : 0.13)
                                               : root.alpha(colors.surface1, 0.45)
                        border.width: 1
                        border.color: root.pageDirty ? root.alpha(colors.green, 0.75)
                                                       : root.alpha(colors.text, 0.08)
                        opacity: root.pageDirty ? 1 : 0.48
                        Behavior on color { ColorAnimation { duration: root.tFast } }
                        Behavior on border.color { ColorAnimation { duration: root.tFast } }
                        Behavior on opacity { NumberAnimation { duration: root.tFast } }
                        scale: saveMouse.pressed ? 0.96 : 1
                        Behavior on scale { NumberAnimation { duration: root.tFast; easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: root.s(6)
                            Text { text: "󰆓"; color: colors.text; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(12) }
                            Text { text: "Kaydet"; color: colors.text; font.family: "JetBrains Mono"; font.pixelSize: root.s(10) }
                        }
                        MouseArea {
                            id: saveMouse
                            anchors.fill: parent
                            enabled: root.pageDirty
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.activePage) root.activePage.save()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.alpha(colors.text, 0.08)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ---------------------------------------------------
                // Sol navigasyon rayı
                // ---------------------------------------------------
                Rectangle {
                    id: navPane
                    Layout.preferredWidth: root.s(252)
                    Layout.fillHeight: true
                    color: root.alpha(colors.mantle, 0.78)
                    opacity: root.navReady ? 1 : 0
                    transform: Translate {
                        x: root.navReady ? 0 : -root.s(18)
                        Behavior on x { NumberAnimation { duration: root.tPage; easing.type: Easing.OutCubic } }
                    }
                    Behavior on opacity { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.s(15)
                        anchors.rightMargin: root.s(13)
                        anchors.topMargin: root.s(17)
                        anchors.bottomMargin: root.s(15)
                        spacing: root.s(8)

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: root.s(5)
                            spacing: root.s(7)
                            Text {
                                text: "KONTROL MERKEZİ"
                                color: colors.overlay0
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(9)
                                font.letterSpacing: root.s(0.5)
                            }
                            Rectangle {
                                Layout.preferredWidth: root.s(5)
                                Layout.preferredHeight: width
                                radius: width / 2
                                color: root.summary ? colors.green : colors.overlay0
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(54)
                            radius: root.s(13)
                            color: root.alpha(colors.surface0, 0.52)
                            border.width: 1
                            border.color: root.alpha(colors.text, 0.06)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: root.s(12)
                                anchors.rightMargin: root.s(10)
                                spacing: root.s(9)
                                Text {
                                    text: root.summary ? "󰒓" : "󰔟"
                                    color: root.summary ? colors.mauve : colors.overlay0
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: root.s(18)
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.summary && root.summary.system ? root.summary.system.hostname : "Sistem"
                                        color: colors.text
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.DemiBold
                                        font.pixelSize: root.s(10)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.summary ? "durumlar güncel" : "veri toplanıyor"
                                        color: colors.overlay0
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: root.s(9)
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Flickable {
                            id: navScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: navColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Rectangle {
                                id: activeRail
                                z: 2
                                x: root.s(1)
                                y: root.activeNavY + (root.activeNavH - height) / 2
                                width: root.s(3)
                                height: Math.max(root.s(12), root.activeNavH * 0.54)
                                radius: width / 2
                                color: colors.mauve
                                opacity: root.navIndicatorReady && root.navReady ? 1 : 0
                                Behavior on y { NumberAnimation { duration: root.tPage; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: root.tBase } }
                            }

                            ColumnLayout {
                                id: navColumn
                                width: parent.width
                                spacing: root.s(3)

                                Repeater {
                                    model: root.navGroups
                                    delegate: ColumnLayout {
                                        id: navGroup
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        spacing: root.s(3)

                                        Text {
                                            visible: navGroup.modelData.title !== ""
                                            Layout.leftMargin: root.s(10)
                                            Layout.topMargin: navGroup.index === 0 ? 0 : root.s(12)
                                            Layout.bottomMargin: root.s(3)
                                            text: navGroup.modelData.title
                                            color: root.alpha(colors.overlay0, 0.9)
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Bold
                                            font.pixelSize: root.s(9)
                                            font.letterSpacing: root.s(0.5)
                                        }

                                        Repeater {
                                            model: navGroup.modelData.items
                                            delegate: Rectangle {
                                                id: navItem
                                                required property var modelData
                                                required property int index
                                                readonly property bool active: root.currentKey === navItem.modelData.key
                                                readonly property string badge: root.navBadge(navItem.modelData.key)
                                                readonly property int revealDelay: (navGroup.index * 3 + navItem.index) * root.navStagger

                                                Layout.fillWidth: true
                                                Layout.preferredHeight: root.s(41)
                                                radius: root.s(11)
                                                color: navItem.active ? root.alpha(colors.mauve, 0.16)
                                                      : navMouse.containsMouse ? root.alpha(colors.surface1, 0.52) : "transparent"
                                                opacity: root.navReady ? 1 : 0
                                                transform: Translate { x: root.navReady ? 0 : -root.s(12) }
                                                Behavior on color { ColorAnimation { duration: root.tFast } }
                                                Behavior on opacity {
                                                    SequentialAnimation {
                                                        PauseAnimation { duration: navItem.revealDelay }
                                                        NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic }
                                                    }
                                                }
                                                Behavior on x {
                                                    SequentialAnimation {
                                                        PauseAnimation { duration: navItem.revealDelay }
                                                        NumberAnimation { duration: root.tPage; easing.type: Easing.OutCubic }
                                                    }
                                                }
                                                scale: navMouse.pressed ? 0.975 : 1
                                                Behavior on scale { NumberAnimation { duration: root.tFast; easing.type: Easing.OutCubic } }

                                                function reportPosition() {
                                                    if (!navItem.active) return;
                                                    root.activeNavY = navItem.mapToItem(navColumn, 0, 0).y;
                                                    root.activeNavH = navItem.height;
                                                    root.navIndicatorReady = true;
                                                }
                                                onActiveChanged: navItem.reportPosition()
                                                onYChanged: navItem.reportPosition()
                                                Component.onCompleted: Qt.callLater(navItem.reportPosition)

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: root.s(13)
                                                    anchors.rightMargin: root.s(10)
                                                    spacing: root.s(9)
                                                    Text {
                                                        text: navItem.modelData.icon
                                                        color: navItem.active ? colors.mauve : colors.subtext0
                                                        font.family: "Iosevka Nerd Font"
                                                        font.pixelSize: root.s(14)
                                                        scale: navItem.active ? 1.08 : (navMouse.containsMouse ? 1.04 : 1)
                                                        Behavior on color { ColorAnimation { duration: root.tFast } }
                                                        Behavior on scale { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: navItem.modelData.name
                                                        color: navItem.active ? colors.text : colors.subtext0
                                                        font.family: "JetBrains Mono"
                                                        font.weight: navItem.active ? Font.DemiBold : Font.Normal
                                                        font.pixelSize: root.s(11)
                                                        elide: Text.ElideRight
                                                        Behavior on color { ColorAnimation { duration: root.tFast } }
                                                    }
                                                    Text {
                                                        visible: navItem.badge !== ""
                                                        Layout.maximumWidth: root.s(75)
                                                        text: navItem.badge
                                                        color: root.navBadgeTone(navItem.modelData.key)
                                                        font.family: "JetBrains Mono"
                                                        font.pixelSize: root.s(9)
                                                        horizontalAlignment: Text.AlignRight
                                                        elide: Text.ElideRight
                                                        Behavior on color { ColorAnimation { duration: root.tBase } }
                                                    }
                                                }

                                                MouseArea {
                                                    id: navMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.goPage(navItem.modelData.key)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(34)
                            radius: root.s(10)
                            color: reloadMouse.containsMouse ? root.alpha(colors.surface1, 0.52) : "transparent"
                            Behavior on color { ColorAnimation { duration: root.tFast } }
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: root.s(7)
                                Text { text: "󰑐"; color: reloadMouse.containsMouse ? colors.mauve : colors.overlay0; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(12) }
                                Text { text: "Hyprland'i yeniden yükle"; color: colors.overlay0; font.family: "JetBrains Mono"; font.pixelSize: root.s(9) }
                            }
                            MouseArea {
                                id: reloadMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["hyprctl", "reload"])
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: root.alpha(colors.text, 0.08)
                }

                // ---------------------------------------------------
                // Sağ içerik alanı
                // ---------------------------------------------------
                ColumnLayout {
                    id: contentPane
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0
                    opacity: root.bodyReady ? 1 : 0
                    transform: Translate {
                        y: root.bodyReady ? 0 : root.s(15)
                        Behavior on y { NumberAnimation { duration: root.tPage; easing.type: Easing.OutCubic } }
                    }
                    Behavior on opacity { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        visible: !root.searching
                        Layout.fillWidth: true
                        Layout.leftMargin: root.s(26)
                        Layout.rightMargin: root.s(24)
                        Layout.topMargin: root.s(23)
                        Layout.bottomMargin: root.s(13)
                        spacing: root.s(3)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            Text {
                                text: root.currentMeta.name
                                color: colors.text
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(20)
                            }
                            Rectangle {
                                Layout.preferredWidth: root.s(6)
                                Layout.preferredHeight: width
                                radius: width / 2
                                color: colors.mauve
                                opacity: 0.8
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.currentKey.toUpperCase()
                                color: colors.overlay0
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(8)
                                font.letterSpacing: root.s(0.7)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.currentMeta.desc
                            color: colors.overlay0
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(10)
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        visible: root.searching
                        Layout.fillWidth: true
                        Layout.leftMargin: root.s(26)
                        Layout.rightMargin: root.s(24)
                        Layout.topMargin: root.s(23)
                        Layout.bottomMargin: root.s(13)
                        spacing: root.s(8)
                        Text {
                            Layout.fillWidth: true
                            text: root.results.length > 0
                                  ? "“" + root.searchText + "” için sonuçlar"
                                  : "“" + root.searchText + "” bulunamadı"
                            color: colors.text
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: root.s(16)
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: root.results.length > 0
                            text: "↑↓ gez  ·  Enter aç  ·  Esc temizle"
                            color: colors.overlay0
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(9)
                        }
                    }

                    Flickable {
                        id: body
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: root.s(26)
                        Layout.rightMargin: root.s(18)
                        Layout.bottomMargin: root.s(19)
                        contentWidth: width
                        contentHeight: root.searching ? resultsColumn.implicitHeight
                                                       : (root.activePage ? root.activePage.implicitHeight : 0)
                        clip: true
                        boundsBehavior: Flickable.OvershootBounds
                        flickDeceleration: 3500

                        ScrollBar.vertical: ScrollBar {
                            id: vbar
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: root.s(4)
                                radius: width / 2
                                color: vbar.pressed ? colors.overlay1 : colors.surface2
                                opacity: vbar.active ? 0.9 : 0
                                Behavior on opacity { NumberAnimation { duration: root.tBase } }
                            }
                        }

                        ColumnLayout {
                            id: resultsColumn
                            width: body.width
                            visible: root.searching
                            spacing: root.s(8)
                            opacity: root.searching ? 1 : 0
                            transform: Translate {
                                y: root.searching ? 0 : root.s(10)
                                Behavior on y { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }
                            }
                            Behavior on opacity { NumberAnimation { duration: root.tFast } }

                            Repeater {
                                model: root.searching ? root.results : []
                                delegate: SearchResultRow {
                                    required property var modelData
                                    required property int index
                                    theme: colors
                                    sf: scaler.baseScale
                                    result: modelData
                                    active: root.resultIndex === index
                                    onChanged: (entry, value) => idx.apply(entry, value)
                                    onOpenPage: (key) => root.goPage(key)
                                }
                            }

                            EmptyState {
                                visible: root.results.length === 0
                                theme: colors
                                sf: scaler.baseScale
                                icon: "󰍉"
                                headline: "Eşleşen ayar yok"
                                body: "Başka bir kelime deneyin: “bulanıklık”, “parola” veya “ekran”."
                            }
                        }

                        // Sayfalar bir kez oluşturulur; sayfa değişince ayar
                        // alanları ve kaydırma durumu kaybolmaz.
                        Item {
                            id: pageStack
                            width: body.width
                            visible: !root.searching
                            implicitHeight: root.activePage ? root.activePage.implicitHeight : 0
                            opacity: root.searching ? 0 : 1
                            transform: Translate {
                                id: pageShift
                                y: root.searching ? root.s(10) : 0
                            }
                            Behavior on opacity { NumberAnimation { duration: root.tFast } }
                            Behavior on y { NumberAnimation { duration: root.tPage; easing.type: Easing.OutCubic } }

                            Connections {
                                target: root
                                function onCurrentKeyChanged() { pageEnter.restart(); }
                                function onSearchingChanged() { if (!root.searching) pageEnter.restart(); }
                            }
                            SequentialAnimation {
                                id: pageEnter
                                PropertyAction { target: pageStack; property: "opacity"; value: 0 }
                                PropertyAction { target: pageShift; property: "y"; value: root.s(13) }
                                ParallelAnimation {
                                    NumberAnimation { target: pageStack; property: "opacity"; to: 1; duration: root.tBase; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: pageShift; property: "y"; to: 0; duration: root.tPage; easing.type: Easing.OutCubic }
                                }
                            }

                            OverviewPage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "overview"; enabled: visible; summary: root.summary; onOpenPage: (key) => root.goPage(key) }
                            NetworkPage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "network"; enabled: visible; summary: root.summary }
                            BluetoothPage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "bluetooth"; enabled: visible }
                            AudioPage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "audio"; enabled: visible }
                            PowerPage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "power"; enabled: visible }
                            AppearancePage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "appearance"; enabled: visible }
                            KeybindsPage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "keybinds"; enabled: visible }
                            MonitorsPage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "monitors"; enabled: visible }
                            GeneralPage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "general"; enabled: visible }
                            StartupPage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "startup"; enabled: visible }
                            WeatherPage { theme: colors; sf: scaler.baseScale; width: parent.width; visible: root.currentKey === "weather"; enabled: visible }
                            IslandPage {
                                theme: colors
                                sf: scaler.baseScale
                                width: parent.width
                                visible: root.currentKey === "widgets"
                                enabled: visible
                                onSectionOpened: (section) => root.openIslandSection(section)
                                onPageOpened: (key) => root.goPage(key)
                            }
                        }
                    }
                }
            }
        }
    }
}
