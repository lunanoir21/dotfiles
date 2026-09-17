pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../parts"

// Bluetooth: adaptör gücü, cihaz tarama, eşleştirme ve bağlantı.
// Durum system/bluetooth.sh'ten geliyor; servis kapalıysa sayfa bunu
// gizlemek yerine açıkça söyleyip başlatmayı öneriyor.
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0

    readonly property bool hasSave: false
    readonly property bool dirty: false
    function save() {}

    function s(v) { return Math.round(v * page.sf); }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    readonly property string script: Qt.resolvedUrl("../system/bluetooth.sh").toString().replace(/^file:\/\//, "")

    property var st: ({ available: true, running: false, powered: false,
                        discovering: false, devices: [] })
    property string expandedMac: ""
    property string busyMac: ""
    property string errorText: ""

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.st = JSON.parse(this.text.trim()); } catch (e) {}
            }
        }
    }

    function refresh() {
        if (statusProc.running) return;
        statusProc.command = ["bash", "-c", "bash '" + page.script + "' status"];
        statusProc.running = true;
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.busyMac = "";
                try {
                    const r = JSON.parse(this.text.trim());
                    page.errorText = r.ok ? "" : (r.msg || "İşlem tamamlanamadı");
                } catch (e) { page.errorText = ""; }
                page.refresh();
            }
        }
    }

    function run(action, mac) {
        if (actionProc.running) return;
        page.errorText = "";
        let cmd = "bash '" + page.script + "' " + action;
        if (mac !== undefined && mac !== "") cmd += " '" + mac + "'";
        actionProc.command = ["bash", "-c", cmd];
        actionProc.running = true;
    }

    // Tarama açıkken liste hızlı değişiyor, o yüzden tempo da hızlanıyor.
    Timer {
        interval: page.st.discovering ? 2500 : 7000
        repeat: true
        running: page.visible
        triggeredOnStart: true
        onTriggered: page.refresh()
    }

    // Sayfadan çıkınca taramayı bırak: açık kalırsa pili boşuna yer.
    onVisibleChanged: if (!visible && page.st.discovering) page.run("scan-off");

    // Cihaz adından tür tahmini. bluetoothctl'in ikon alanını almak cihaz
    // başına ayrı bir sorgu demek; ad üzerinden tahmin bedava ve çoğu
    // zaman doğru, yanılırsa genel bluetooth ikonuna düşüyor.
    function deviceIcon(name) {
        const n = String(name).toLowerCase();
        if (/kulak|head|buds|airpod|wh-|wf-|earphone/.test(n)) return "󰋋";
        if (/speaker|hoparlör|soundbar|jbl|boom/.test(n)) return "󰓃";
        if (/mouse|fare/.test(n)) return "󰍽";
        if (/keyboard|klavye/.test(n)) return "󰌌";
        if (/phone|telefon|iphone|galaxy|pixel/.test(n)) return "󰄜";
        if (/watch|saat|band/.test(n)) return "󰖉";
        if (/tv|monitor/.test(n)) return "󰔂";
        return "󰂯";
    }

    spacing: s(18)

    // ---------------------------------------------------------------
    // Servis kapalı: sayfayı boş bırakmak yerine ne yapılacağını söyle
    // ---------------------------------------------------------------
    EmptyState {
        visible: !page.st.running
        theme: page.theme; sf: page.sf
        icon: page.st.available ? "󰂲" : "󰂭"
        headline: page.st.available ? "Bluetooth servisi çalışmıyor"
                                    : "Bu sistemde Bluetooth yok"
        body: page.st.available
              ? "Cihazları görmek için bluetooth servisini başlatın. Kalıcı olması için sistem servis yöneticisinden etkinleştirmeniz gerekir."
              : "bluetooth.service kurulu değil. Bir Bluetooth adaptörü takılıysa bluez paketini kurun."
        actionText: page.st.available ? "Servisi başlat" : ""
        onActionTriggered: page.run("service-start")
    }

    // ---------------------------------------------------------------
    // Adaptör
    // ---------------------------------------------------------------
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "ADAPTÖR"
        visible: page.st.running

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Bluetooth"
            hint: page.st.powered ? "Açık — cihazlar bağlanabilir" : "Kapalı"
            checked: page.st.powered
            onToggled: {
                let next = JSON.parse(JSON.stringify(page.st));
                next.powered = !page.st.powered;
                page.st = next;
                page.run("power-toggle");
            }
        }

        RowAction {
            visible: page.st.powered
            theme: page.theme; sf: page.sf
            label: "Yeni cihaz ara"
            hint: page.st.discovering
                  ? "Taranıyor — eşleştirmek istediğiniz cihazı keşfedilebilir moda alın"
                  : "Çevredeki eşleştirilmemiş cihazları bulur (tarama 3 dk sonra kendiliğinden durur)"
            buttonText: page.st.discovering ? "Durdur" : "Ara"
            buttonIcon: page.st.discovering ? "󰓛" : "󰐷"
            busy: page.st.discovering
            onTriggered: page.run(page.st.discovering ? "scan-off" : "scan-on")
        }
    }

    // --- hata ---
    Rectangle {
        Layout.fillWidth: true
        visible: page.errorText !== ""
        Layout.preferredHeight: visible ? btErr.paintedHeight + page.s(18) : 0
        radius: page.s(12)
        color: page.alpha(page.theme.red, 0.13)
        border.width: 1
        border.color: page.alpha(page.theme.red, 0.45)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: page.s(13)
            anchors.rightMargin: page.s(13)
            spacing: page.s(9)

            Text {
                text: "󰀪"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: page.s(14)
                color: page.theme.red
            }
            Text {
                id: btErr
                Layout.fillWidth: true
                text: page.errorText
                color: page.theme.red
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(10)
                wrapMode: Text.WordWrap
            }
        }
    }

    // ---------------------------------------------------------------
    // Cihazlar
    // ---------------------------------------------------------------
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "CİHAZLAR"
        visible: page.st.running && page.st.powered

        EmptyState {
            visible: page.st.devices.length === 0
            theme: page.theme; sf: page.sf
            icon: "󰂰"
            busy: page.st.discovering
            headline: page.st.discovering ? "Cihaz aranıyor" : "Henüz cihaz yok"
            body: page.st.discovering
                  ? "Eşleştirmek istediğiniz cihazı keşfedilebilir moda alın; göründüğünde listeye düşecek."
                  : "Bir cihaz eklemek için önce arama başlatın."
            actionText: page.st.discovering ? "" : "Yeni cihaz ara"
            onActionTriggered: page.run("scan-on")
        }

        Repeater {
            model: page.st.devices

            delegate: RowDevice {
                id: btRow
                required property var modelData

                theme: page.theme; sf: page.sf
                icon: page.deviceIcon(modelData.name)
                name: modelData.name
                detail: modelData.connected ? "Bağlı"
                                            : (modelData.paired ? "Eşleştirilmiş" : "Eşleştirilmemiş")
                connected: modelData.connected
                busy: page.busyMac === modelData.mac
                busyText: "işleniyor…"
                status: modelData.paired && !modelData.connected ? "kayıtlı" : ""
                statusTone: page.theme.overlay0
                expanded: page.expandedMac === modelData.mac
                onClicked: {
                    page.errorText = "";
                    page.expandedMac = (page.expandedMac === modelData.mac) ? "" : modelData.mac;
                }

                RowInfo {
                    theme: page.theme; sf: page.sf
                    label: "Adres"; value: btRow.modelData.mac; copyable: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: page.s(7)

                    // Eşleştirilmemiş cihazda tek düğme yetiyor: script
                    // eşleştirip güven verip bağlanmayı sırayla yapıyor.
                    Rectangle {
                        id: primaryBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: page.s(31)
                        radius: page.s(10)
                        readonly property color tone: btRow.modelData.connected ? page.theme.peach : page.theme.blue
                        readonly property string act: btRow.modelData.connected ? "disconnect"
                                                    : (btRow.modelData.paired ? "connect" : "pair")
                        readonly property string caption: btRow.modelData.connected ? "Bağlantıyı kes"
                                                        : (btRow.modelData.paired ? "Bağlan" : "Eşleştir ve bağlan")
                        color: primMa.containsMouse ? page.alpha(tone, 0.24) : page.alpha(tone, 0.13)
                        border.width: 1
                        border.color: page.alpha(tone, 0.45)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        scale: primMa.pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: page.s(6)
                            Text {
                                text: btRow.modelData.connected ? "󰂲" : (btRow.modelData.paired ? "󰂯" : "󰐷")
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: page.s(12)
                                color: primaryBtn.tone
                            }
                            Text {
                                text: primaryBtn.caption
                                color: page.theme.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: page.s(11)
                            }
                        }

                        MouseArea {
                            id: primMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.busyMac = btRow.modelData.mac;
                                page.run(primaryBtn.act, btRow.modelData.mac);
                            }
                        }
                    }

                    Rectangle {
                        visible: btRow.modelData.paired
                        Layout.fillWidth: true
                        Layout.preferredHeight: page.s(31)
                        radius: page.s(10)
                        color: rmMa.containsMouse ? page.alpha(page.theme.red, 0.24) : page.alpha(page.theme.red, 0.13)
                        border.width: 1
                        border.color: page.alpha(page.theme.red, 0.45)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        scale: rmMa.pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: page.s(6)
                            Text {
                                text: "󰩹"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: page.s(12)
                                color: page.theme.red
                            }
                            Text {
                                text: "Cihazı kaldır"
                                color: page.theme.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: page.s(11)
                            }
                        }

                        MouseArea {
                            id: rmMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.busyMac = btRow.modelData.mac;
                                page.run("remove", btRow.modelData.mac);
                            }
                        }
                    }
                }
            }
        }
    }
}
