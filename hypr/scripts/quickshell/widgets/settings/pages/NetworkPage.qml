pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../parts"
import "../../../core"

// Ağ: Wi-Fi, kablolu bağlantı, VPN ve aktif bağlantının adresleri.
// Tüm sistem durumu system/network.sh'ten tek bir JSON olarak geliyor.
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0

    // Sistem sayfaları anında uygular; üstteki Kaydet düğmesine ihtiyaçları yok.
    readonly property bool hasSave: false
    readonly property bool dirty: false
    function save() {}

    function s(v) { return Math.round(v * page.sf); }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    readonly property string script: Qt.resolvedUrl("../system/network.sh").toString().replace(/^file:\/\//, "")

    property var summary: null
    property var st: ({ wifiOn: (page.summary && page.summary.network) ? page.summary.network.wifiOn : false,
                        devices: [], vpns: [], nets: [],
                        address: { ip: "", gateway: "", dns: "" } })
    property bool scanning: false
    property string expandedSsid: ""
    property string busySsid: ""
    property string errorText: ""

    // UTF-8 güvenli base64 — SSID ve parola kabuk komutuna gömülüyor.
    function b64(str) {
        const enc = encodeURIComponent(String(str));
        let out = "";
        for (let i = 0; i < enc.length; i++) {
            if (enc[i] === "%") { out += String.fromCharCode(parseInt(enc.substr(i + 1, 2), 16)); i += 2; }
            else out += enc[i];
        }
        return Qt.btoa(out);
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.scanning = false;
                try {
                    const parsed = JSON.parse(this.text.trim());
                    if (parsed && typeof parsed.wifiOn === "boolean") {
                        page.st = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    function refresh(rescan) {
        if (statusProc.running) return;
        if (rescan) page.scanning = true;
        statusProc.command = ["bash", "-c", "bash '" + page.script + "' status" + (rescan ? " rescan" : "")];
        statusProc.running = true;
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.busySsid = "";
                try {
                    const r = JSON.parse(this.text.trim());
                    page.errorText = r.ok ? "" : (r.msg || "İşlem tamamlanamadı");
                    if (r.ok) page.expandedSsid = "";
                } catch (e) { page.errorText = ""; }
                page.refresh(false);
            }
        }
    }

    function run(action, arg1, arg2) {
        if (actionProc.running) return;
        page.errorText = "";
        let cmd = "bash '" + page.script + "' " + action;
        if (arg1 !== undefined && arg1 !== "") cmd += " '" + page.b64(arg1) + "'";
        if (arg2 !== undefined && arg2 !== "") cmd += " '" + page.b64(arg2) + "'";
        actionProc.command = ["bash", "-c", cmd];
        actionProc.running = true;
    }

    Timer {
        interval: 6000
        repeat: true
        running: page.visible
        triggeredOnStart: true
        onTriggered: page.refresh(false)
    }

    Component.onCompleted: page.refresh(false)
    onVisibleChanged: if (visible) page.refresh(false)

    function signalIcon(sig) {
        if (sig >= 75) return "󰤨";
        if (sig >= 55) return "󰤥";
        if (sig >= 35) return "󰤢";
        if (sig >= 15) return "󰤟";
        return "󰤯";
    }

    function netDetail(net) {
        if (net.inUse) return "Bağlı" + (net.signal > 0 ? " · sinyal %" + net.signal : "");
        if (!net.visible) return "Kayıtlı · menzil dışında";
        let bits = ["sinyal %" + net.signal];
        if (net.saved) bits.push("kayıtlı");
        bits.push(net.secured ? "korumalı" : "açık ağ");
        return bits.join(" · ");
    }

    spacing: s(18)

    // ---------------------------------------------------------------
    // Wi-Fi
    // ---------------------------------------------------------------
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "WI-FI"

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Wi-Fi"
            hint: page.st.wifiOn ? "Açık — çevredeki ağlar aşağıda" : "Kapalı"
            checked: page.st.wifiOn
            onToggled: {
                // Anahtarın hemen tepki vermesi için iyimser güncelleme;
                // bir sonraki poll gerçeği yazar.
                let next = JSON.parse(JSON.stringify(page.st));
                next.wifiOn = !page.st.wifiOn;
                page.st = next;
                page.run("wifi-toggle");
            }
        }

        RowAction {
            visible: page.st.wifiOn
            theme: page.theme; sf: page.sf
            label: "Ağları tara"
            hint: page.scanning ? "Taranıyor…" : (page.st.nets.length + " ağ bulundu")
            buttonText: "Tara"
            buttonIcon: "󰑐"
            busy: page.scanning
            onTriggered: page.refresh(true)
        }
    }

    // --- nmcli hata mesajı ---
    Rectangle {
        Layout.fillWidth: true
        visible: page.errorText !== ""
        Layout.preferredHeight: visible ? errText.paintedHeight + page.s(18) : 0
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
                id: errText
                Layout.fillWidth: true
                text: page.errorText
                color: page.theme.red
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(10)
                wrapMode: Text.WordWrap
            }
        }
    }

    // --- ağ listesi ---
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "ÇEVREDEKİ AĞLAR"
        visible: page.st.wifiOn

        EmptyState {
            visible: page.st.nets.length === 0
            theme: page.theme; sf: page.sf
            icon: "󰤭"
            busy: page.scanning
            headline: page.scanning ? "Ağlar aranıyor" : "Ağ bulunamadı"
            body: page.scanning ? "Çevredeki Wi-Fi ağları taranıyor."
                                : "Menzilde ağ görünmüyor. Yönlendiricinin açık olduğundan emin olup yeniden tarayın."
            actionText: page.scanning ? "" : "Yeniden tara"
            onActionTriggered: page.refresh(true)
        }

        Repeater {
            model: page.st.nets

            delegate: RowDevice {
                id: netRow
                required property var modelData

                theme: page.theme; sf: page.sf
                icon: modelData.visible ? page.signalIcon(modelData.signal) : "󰤮"
                name: modelData.ssid
                detail: page.netDetail(modelData)
                connected: modelData.inUse
                dimmed: !modelData.visible
                busy: page.busySsid === modelData.ssid
                status: modelData.secured ? "󰌾" : ""
                statusTone: page.theme.overlay0
                expanded: page.expandedSsid === modelData.ssid

                onClicked: {
                    page.errorText = "";
                    page.expandedSsid = (page.expandedSsid === modelData.ssid) ? "" : modelData.ssid;
                }

                // --- parola ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.s(34)
                    visible: netRow.modelData.secured && !netRow.modelData.inUse
                    radius: page.s(10)
                    color: page.alpha(page.theme.base, 0.55)
                    border.width: 1
                    border.color: pwField.activeFocus ? page.theme.mauve : page.alpha(page.theme.text, 0.1)
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: page.s(11)
                        anchors.rightMargin: page.s(8)
                        spacing: page.s(8)

                        Text {
                            text: "󰌆"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: page.s(13)
                            color: pwField.activeFocus ? page.theme.mauve : page.theme.overlay0
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        TextField {
                            id: pwField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            background: Item {}
                            padding: 0
                            echoMode: reveal.showing ? TextInput.Normal : TextInput.Password
                            color: page.theme.text
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(11)
                            placeholderText: netRow.modelData.saved ? "Kayıtlı parola kullanılacak" : "Ağ parolası"
                            placeholderTextColor: page.theme.overlay0
                            verticalAlignment: TextInput.AlignVCenter
                            onAccepted: {
                                page.busySsid = netRow.modelData.ssid;
                                page.run("connect", netRow.modelData.ssid, text);
                            }
                        }

                        Text {
                            id: reveal
                            property bool showing: false
                            text: showing ? "󰛐" : "󰛑"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: page.s(13)
                            color: page.theme.overlay0

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -page.s(5)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: reveal.showing = !reveal.showing
                            }
                        }
                    }
                }

                // --- eylemler ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: page.s(7)

                    Rectangle {
                        id: connBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: page.s(31)
                        radius: page.s(10)
                        readonly property color tone: netRow.modelData.inUse ? page.theme.peach : page.theme.blue
                        color: connMa.containsMouse ? page.alpha(tone, 0.24) : page.alpha(tone, 0.13)
                        border.width: 1
                        border.color: page.alpha(tone, 0.45)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        scale: connMa.pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: page.s(6)
                            Text {
                                text: netRow.modelData.inUse ? "󰖪" : "󰤨"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: page.s(12)
                                color: connBtn.tone
                            }
                            Text {
                                text: netRow.modelData.inUse ? "Bağlantıyı kes" : "Bağlan"
                                color: page.theme.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: page.s(11)
                            }
                        }

                        MouseArea {
                            id: connMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.busySsid = netRow.modelData.ssid;
                                if (netRow.modelData.inUse) page.run("disconnect", netRow.modelData.ssid);
                                else page.run("connect", netRow.modelData.ssid,
                                              netRow.modelData.secured ? pwField.text : "");
                            }
                        }
                    }

                    Rectangle {
                        visible: netRow.modelData.saved
                        Layout.fillWidth: true
                        Layout.preferredHeight: page.s(31)
                        radius: page.s(10)
                        color: forgetMa.containsMouse ? page.alpha(page.theme.red, 0.24) : page.alpha(page.theme.red, 0.13)
                        border.width: 1
                        border.color: page.alpha(page.theme.red, 0.45)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        scale: forgetMa.pressed ? 0.96 : 1.0
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
                                text: "Ağı unut"
                                color: page.theme.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: page.s(11)
                            }
                        }

                        MouseArea {
                            id: forgetMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.busySsid = netRow.modelData.ssid;
                                page.run("forget", netRow.modelData.ssid);
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------
    // Kablolu + VPN
    // ---------------------------------------------------------------
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "KABLOLU"
        visible: page.wiredDevices.length > 0

        Repeater {
            model: page.wiredDevices

            delegate: RowDevice {
                required property var modelData

                theme: page.theme; sf: page.sf
                icon: "󰈀"
                name: modelData.connection !== "" ? modelData.connection : modelData.name
                detail: {
                    if (modelData.state === "connected") return modelData.name + " · bağlı";
                    if (modelData.state === "unavailable") return modelData.name + " · kablo takılı değil";
                    return modelData.name + " · " + modelData.state;
                }
                connected: modelData.state === "connected"
                dimmed: modelData.state === "unavailable"
                expanded: false
                onClicked: {
                    if (modelData.state === "unavailable") return;
                    if (modelData.state === "connected") page.run("device-down", modelData.name);
                    else page.run("device-up", modelData.name);
                }
            }
        }
    }

    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "VPN"
        visible: page.st.vpns.length > 0

        Repeater {
            model: page.st.vpns

            delegate: RowDevice {
                required property var modelData

                theme: page.theme; sf: page.sf
                icon: "󰦝"
                name: modelData.name
                detail: modelData.active ? "Bağlı" : "Bağlı değil"
                connected: modelData.active
                expanded: false
                onClicked: page.run(modelData.active ? "vpn-down" : "vpn-up", modelData.name)
            }
        }
    }

    // Kablolu aygıtlar ayrı bir property: RowDevice'ın model ifadesi içinde
    // filtrelemek her yeniden değerlendirmede delegate'leri yeniden kurardı.
    readonly property var wiredDevices: {
        let out = [];
        for (let i = 0; i < page.st.devices.length; i++)
            if (page.st.devices[i].type === "ethernet") out.push(page.st.devices[i]);
        return out;
    }

    // ---------------------------------------------------------------
    // Adres bilgileri
    // ---------------------------------------------------------------
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "BAĞLANTI BİLGİSİ"
        visible: page.st.address.ip !== ""

        RowInfo {
            theme: page.theme; sf: page.sf
            label: "IP adresi"; value: page.st.address.ip; copyable: true
        }
        RowInfo {
            theme: page.theme; sf: page.sf
            label: "Ağ geçidi"; value: page.st.address.gateway; copyable: true
        }
        RowInfo {
            theme: page.theme; sf: page.sf
            label: "DNS"; value: page.st.address.dns; copyable: true
        }
    }
}
