pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../parts"
import "../../../core"

// Ekran düzeni. Yerleşim matematiği (çakışma, kenara yapışma, origin
// normalleştirme) zaten Config.qml'de: monitorsModel, monForceLayoutUpdate,
// applyMonitors. Burası onun görsel yüzü.
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0

    readonly property bool hasSave: true
    property bool dirty: false

    function s(v) { return Math.round(v * page.sf); }

    function save() {
        Config.applyMonitors();
        page.dirty = false;
    }

    // Sayfa görünür olunca `hyprctl monitors -j` ile taze oku.
    onVisibleChanged: if (visible) Config.displayPoller.running = true
    Component.onCompleted: if (visible) Config.displayPoller.running = true

    readonly property var selected: Config.monitorsModel.count > Config.monActiveEditIndex
                                    ? Config.monitorsModel.get(Config.monActiveEditIndex)
                                    : null

    // availableModes "1920x1080@144.00Hz" biçiminde geliyor; çözünürlük ve
    // yenileme hızını ayrı listelere ayırıyoruz.
    function modesOf(idx) {
        if (idx < 0 || idx >= Config.monitorsModel.count) return [];
        try { return JSON.parse(Config.monitorsModel.get(idx).availableModes || "[]"); }
        catch (e) { return []; }
    }
    function resolutions(idx) {
        let out = [];
        for (let m of page.modesOf(idx)) {
            let r = m.split("@")[0];
            if (out.indexOf(r) === -1) out.push(r);
        }
        return out;
    }
    function ratesFor(idx, res) {
        let out = [];
        for (let m of page.modesOf(idx)) {
            let parts = m.split("@");
            if (parts[0] !== res) continue;
            let hz = Math.round(parseFloat(parts[1])).toString();
            if (out.indexOf(hz) === -1) out.push(hz);
        }
        return out;
    }

    function setRes(res) {
        let i = Config.monActiveEditIndex;
        let wh = res.split("x");
        Config.monitorsModel.setProperty(i, "resW", parseInt(wh[0]));
        Config.monitorsModel.setProperty(i, "resH", parseInt(wh[1]));
        // Yeni çözünürlükte mevcut hız yoksa en yükseğine düş.
        let rates = page.ratesFor(i, res);
        if (rates.indexOf(Config.monitorsModel.get(i).rate) === -1 && rates.length > 0)
            Config.monitorsModel.setProperty(i, "rate", rates[0]);
        page.dirty = true;
    }

    spacing: s(14)

    // ---- ekran düzeni tuvali ----
    Text {
        Layout.leftMargin: page.s(4)
        text: "DÜZEN"
        color: page.theme.subtext0
        font.family: "JetBrains Mono"
        font.weight: Font.Bold
        font.pixelSize: page.s(11)
    }

    Rectangle {
        id: canvas
        Layout.fillWidth: true
        Layout.preferredHeight: page.s(240)
        radius: page.s(14)
        color: Qt.rgba(page.theme.surface0.r, page.theme.surface0.g, page.theme.surface0.b, 0.5)
        border.width: 1
        border.color: Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.06)
        clip: true

        Text {
            anchors.centerIn: parent
            visible: Config.monitorsModel.count === 0
            text: "Ekran bulunamadı"
            color: page.theme.overlay0
            font.family: "JetBrains Mono"
            font.pixelSize: page.s(11)
        }

        // Monitörleri tuvalin ortasına toplayan kaydırma. uiX/uiY sol-üst
        // köşeye göre normalize edildiği için ortalamayı burada yapıyoruz.
        Item {
            id: field
            anchors.fill: parent

            property real spanW: {
                let mx = 0;
                for (let i = 0; i < Config.monitorsModel.count; i++) {
                    let m = Config.monitorsModel.get(i);
                    let p = m.transform === 1 || m.transform === 3;
                    let w = m.uiX + ((p ? m.resH : m.resW) / m.sysScale) * Config.monUiScale;
                    if (w > mx) mx = w;
                }
                return mx;
            }
            property real spanH: {
                let my = 0;
                for (let i = 0; i < Config.monitorsModel.count; i++) {
                    let m = Config.monitorsModel.get(i);
                    let p = m.transform === 1 || m.transform === 3;
                    let h = m.uiY + ((p ? m.resW : m.resH) / m.sysScale) * Config.monUiScale;
                    if (h > my) my = h;
                }
                return my;
            }
            property real offX: (width - spanW) / 2
            property real offY: (height - spanH) / 2

            Repeater {
                model: Config.monitorsModel

                delegate: Rectangle {
                    id: mon

                    required property int index
                    // Rol adlarını tek tek `required property` yapamıyoruz:
                    // "transform" QQuickItem'ın final property'sini gölgeliyor.
                    required property var model

                    readonly property string mName: mon.model.name
                    readonly property int mResW: mon.model.resW
                    readonly property int mResH: mon.model.resH
                    readonly property real mScale: mon.model.sysScale
                    readonly property string mRate: mon.model.rate
                    readonly property real mUiX: mon.model.uiX
                    readonly property real mUiY: mon.model.uiY
                    readonly property int mTransform: mon.model.transform

                    readonly property bool portrait: mon.mTransform === 1 || mon.mTransform === 3
                    readonly property bool active: Config.monActiveEditIndex === mon.index

                    width: ((portrait ? mon.mResH : mon.mResW) / mon.mScale) * Config.monUiScale
                    height: ((portrait ? mon.mResW : mon.mResH) / mon.mScale) * Config.monUiScale
                    x: field.offX + mon.mUiX
                    y: field.offY + mon.mUiY

                    radius: page.s(8)
                    color: mon.active
                           ? Qt.rgba(page.theme.mauve.r, page.theme.mauve.g, page.theme.mauve.b, 0.28)
                           : Qt.rgba(page.theme.surface2.r, page.theme.surface2.g, page.theme.surface2.b, 0.6)
                    border.width: mon.active ? 2 : 1
                    border.color: mon.active ? page.theme.mauve : Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.15)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: mon.mName
                            color: page.theme.text
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: page.s(11)
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: mon.mResW + "×" + mon.mResH
                            color: page.theme.subtext0
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(9)
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: mon.mRate + "Hz"
                            color: page.theme.overlay0
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(9)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        drag.target: Config.monitorsModel.count > 1 ? mon : null

                        onPressed: Config.monActiveEditIndex = mon.index

                        // Sürükleme boyunca modeldeki uiX/uiY'yi güncelliyoruz ki
                        // Config'in yapışma matematiği doğru veriyle çalışsın.
                        onPositionChanged: {
                            if (!drag.active) return;
                            Config.monitorsModel.setProperty(mon.index, "uiX", mon.x - field.offX);
                            Config.monitorsModel.setProperty(mon.index, "uiY", mon.y - field.offY);
                        }

                        onReleased: {
                            if (Config.monitorsModel.count > 1) {
                                Config.monActiveEditIndex = mon.index;
                                Config.monForceLayoutUpdate();
                            }
                            page.dirty = true;
                        }
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: page.s(4)
        visible: Config.monitorsModel.count > 1
        text: "Ekranları sürükleyerek konumlandır — bırakınca komşu kenara yapışır."
        color: page.theme.overlay0
        font.family: "JetBrains Mono"
        font.pixelSize: page.s(10)
    }

    // ---- seçili ekranın ayarları ----
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: page.selected ? page.selected.name.toUpperCase() : "EKRAN"
        visible: page.selected !== null

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: page.s(14)
            Layout.rightMargin: page.s(14)
            Layout.topMargin: page.s(6)
            spacing: page.s(8)

            Text {
                Layout.preferredWidth: page.s(88)
                text: "Çözünürlük"
                color: page.theme.text
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(11)
            }

            Segmented {
                Layout.fillWidth: true
                theme: page.theme
                sf: page.sf
                options: page.resolutions(Config.monActiveEditIndex).slice(0, 5)
                currentIndex: page.selected
                              ? page.resolutions(Config.monActiveEditIndex).slice(0, 5)
                                    .indexOf(page.selected.resW + "x" + page.selected.resH)
                              : -1
                onPicked: (i) => page.setRes(page.resolutions(Config.monActiveEditIndex).slice(0, 5)[i])
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: page.s(14)
            Layout.rightMargin: page.s(14)
            spacing: page.s(8)

            Text {
                Layout.preferredWidth: page.s(88)
                text: "Yenileme"
                color: page.theme.text
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(11)
            }

            Segmented {
                Layout.fillWidth: true
                theme: page.theme
                sf: page.sf
                options: page.selected
                         ? page.ratesFor(Config.monActiveEditIndex, page.selected.resW + "x" + page.selected.resH).slice(0, 5)
                         : []
                currentIndex: page.selected
                              ? page.ratesFor(Config.monActiveEditIndex, page.selected.resW + "x" + page.selected.resH)
                                    .slice(0, 5).indexOf(page.selected.rate)
                              : -1
                onPicked: (i) => {
                    let r = page.ratesFor(Config.monActiveEditIndex, page.selected.resW + "x" + page.selected.resH).slice(0, 5)[i];
                    Config.monitorsModel.setProperty(Config.monActiveEditIndex, "rate", r);
                    page.dirty = true;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: page.s(14)
            Layout.rightMargin: page.s(14)
            spacing: page.s(8)

            Text {
                Layout.preferredWidth: page.s(88)
                text: "Dönüş"
                color: page.theme.text
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(11)
            }

            Segmented {
                Layout.fillWidth: true
                theme: page.theme
                sf: page.sf
                options: ["0", "1", "2", "3"]
                labels: ["Normal", "90°", "180°", "270°"]
                currentIndex: page.selected ? page.selected.transform : 0
                onPicked: (i) => {
                    Config.monitorsModel.setProperty(Config.monActiveEditIndex, "transform", i);
                    Config.monDelayedLayoutUpdate.restart();
                    page.dirty = true;
                }
            }
        }

        RowSlider {
            theme: page.theme
            sf: page.sf
            label: "Ölçek"
            hint: "Hyprland monitör ölçeği — kesirli değerler bazı çözünürlüklerde reddedilir"
            from: 0.5; to: 3.0; stepSize: 0.05; decimals: 2
            value: page.selected ? page.selected.sysScale : 1.0
            onMoved: (v) => {
                Config.monitorsModel.setProperty(Config.monActiveEditIndex, "sysScale", Number(v.toFixed(2)));
                page.dirty = true;
            }
            onCommitted: (v) => {
                Config.monitorsModel.setProperty(Config.monActiveEditIndex, "sysScale", Number(v.toFixed(2)));
                Config.monDelayedLayoutUpdate.restart();
                page.dirty = true;
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: page.s(4)
        text: "Kaydet, düzeni hem çalışan Hyprland'e uygular hem de settings.json'a yazar."
        color: page.theme.overlay0
        font.family: "JetBrains Mono"
        font.pixelSize: page.s(10)
        wrapMode: Text.WordWrap
    }
}
