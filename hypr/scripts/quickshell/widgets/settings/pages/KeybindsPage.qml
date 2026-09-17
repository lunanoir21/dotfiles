pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../parts"
import "../../../core"

// settings.json -> "keybinds" dizisi. settings_watcher.sh bunu
// config/keybindings.conf'a `<tür> = <mods>, <tuş>, <dispatcher>, <komut>`
// satırları olarak basıyor.
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0

    readonly property bool hasSave: true
    property bool dirty: false

    readonly property var bindTypes: ["bind", "binde", "bindl", "bindel", "bindm"]

    property string filter: ""

    function s(v) { return Math.round(v * page.sf); }

    ListModel { id: binds }

    function reload() {
        binds.clear();
        let data = Config.keybindsData || [];
        for (let i = 0; i < data.length; i++) {
            binds.append({
                type: data[i].type || "bind",
                mods: data[i].mods || "",
                key: data[i].key || "",
                dispatcher: data[i].dispatcher || "exec",
                command: data[i].command || "",
                expanded: false
            });
        }
        page.dirty = false;
    }

    function save() {
        let arr = [];
        for (let i = 0; i < binds.count; i++) {
            let b = binds.get(i);
            if ((b.key || "").trim() === "") continue;   // tuşsuz satır conf'u bozar
            arr.push({
                type: b.type, mods: b.mods, key: b.key,
                dispatcher: b.dispatcher, command: b.command, isEditing: false
            });
        }
        Config.saveAllKeybinds(arr);
        page.dirty = false;
    }

    function matches(i) {
        if (page.filter === "") return true;
        let b = binds.get(i);
        let hay = (b.mods + " " + b.key + " " + b.dispatcher + " " + b.command).toLowerCase();
        return hay.indexOf(page.filter.toLowerCase()) !== -1;
    }

    Component.onCompleted: page.reload()
    Connections {
        target: Config
        function onKeybindsLoaded() { page.reload(); }
    }

    spacing: s(12)

    // ---- üst şerit: filtre + ekle ----
    RowLayout {
        Layout.fillWidth: true
        spacing: page.s(8)

        TextField {
            id: filterField
            Layout.fillWidth: true
            Layout.preferredHeight: page.s(32)
            placeholderText: "Kısayollarda ara…"
            color: page.theme.text
            placeholderTextColor: page.theme.overlay0
            font.family: "JetBrains Mono"
            font.pixelSize: page.s(11)
            selectByMouse: true
            leftPadding: page.s(12)
            rightPadding: page.s(12)
            onTextChanged: page.filter = text

            background: Rectangle {
                radius: page.s(9)
                color: Qt.rgba(page.theme.surface1.r, page.theme.surface1.g, page.theme.surface1.b, 0.6)
                border.width: 1
                border.color: filterField.activeFocus
                              ? page.theme.mauve
                              : Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.07)
                Behavior on border.color { ColorAnimation { duration: 200 } }
            }
        }

        Rectangle {
            Layout.preferredWidth: page.s(96)
            Layout.preferredHeight: page.s(32)
            radius: page.s(9)
            color: addMa.containsMouse
                   ? Qt.rgba(page.theme.mauve.r, page.theme.mauve.g, page.theme.mauve.b, 0.28)
                   : Qt.rgba(page.theme.surface1.r, page.theme.surface1.g, page.theme.surface1.b, 0.7)
            Behavior on color { ColorAnimation { duration: 200 } }
            scale: addMa.pressed ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

            Text {
                anchors.centerIn: parent
                text: "+  Ekle"
                color: page.theme.text
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(11)
            }

            MouseArea {
                id: addMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    binds.insert(0, {
                        type: "bind", mods: "", key: "",
                        dispatcher: "exec", command: "", expanded: true
                    });
                    page.dirty = true;
                }
            }
        }
    }

    // ---- liste ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: rows.implicitHeight + page.s(12)
        radius: page.s(14)
        color: Qt.rgba(page.theme.surface0.r, page.theme.surface0.g, page.theme.surface0.b, 0.5)
        border.width: 1
        border.color: Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.06)

        ColumnLayout {
            id: rows
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: page.s(6)
            spacing: page.s(3)

            Text {
                visible: binds.count === 0
                Layout.fillWidth: true
                Layout.topMargin: page.s(16)
                Layout.bottomMargin: page.s(16)
                horizontalAlignment: Text.AlignHCenter
                text: "Tanımlı kısayol yok"
                color: page.theme.overlay0
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(11)
            }

            Repeater {
                model: binds

                delegate: Item {
                    id: bindRow

                    required property int index
                    required property string type
                    required property string mods
                    required property string key
                    required property string dispatcher
                    required property string command
                    required property bool expanded

                    readonly property bool shown: page.matches(bindRow.index)

                    Layout.fillWidth: true
                    visible: bindRow.shown
                    implicitHeight: bindRow.shown
                                    ? page.s(46) + (bindRow.expanded ? editPanel.implicitHeight + page.s(10) : 0)
                                    : 0
                    Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: page.s(4)
                        anchors.rightMargin: page.s(4)
                        anchors.bottomMargin: page.s(2)
                        radius: page.s(10)
                        color: bindRow.expanded
                               ? Qt.rgba(page.theme.surface1.r, page.theme.surface1.g, page.theme.surface1.b, 0.6)
                               : (headMa.containsMouse
                                  ? Qt.rgba(page.theme.surface1.r, page.theme.surface1.g, page.theme.surface1.b, 0.4)
                                  : "transparent")
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    // --- kapalı satır ---
                    RowLayout {
                        id: head
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: page.s(12)
                        anchors.rightMargin: page.s(12)
                        height: page.s(46)
                        spacing: page.s(10)

                        Rectangle {
                            Layout.preferredWidth: page.s(168)
                            Layout.preferredHeight: page.s(26)
                            radius: page.s(7)
                            color: Qt.rgba(page.theme.mauve.r, page.theme.mauve.g, page.theme.mauve.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(page.theme.mauve.r, page.theme.mauve.g, page.theme.mauve.b, 0.45)

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - page.s(10)
                                horizontalAlignment: Text.AlignHCenter
                                text: (bindRow.mods !== "" ? bindRow.mods + " + " : "") + (bindRow.key !== "" ? bindRow.key : "—")
                                color: page.theme.text
                                font.family: "JetBrains Mono"
                                font.weight: Font.DemiBold
                                font.pixelSize: page.s(10)
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            Layout.preferredWidth: page.s(74)
                            text: bindRow.dispatcher
                            color: page.theme.sapphire
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(10)
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: bindRow.command !== "" ? bindRow.command : "—"
                            color: page.theme.subtext0
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(10)
                            elide: Text.ElideRight
                        }

                        Text {
                            text: bindRow.expanded ? "󰅃" : "󰏫"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: page.s(12)
                            color: bindRow.expanded ? page.theme.mauve : page.theme.overlay0
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        Text {
                            text: "󰅖"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: page.s(12)
                            color: delMa.containsMouse ? page.theme.red : page.theme.overlay0
                            Behavior on color { ColorAnimation { duration: 180 } }
                            scale: delMa.pressed ? 0.75 : (delMa.containsMouse ? 1.2 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                anchors.margins: page.s(-6)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    binds.remove(bindRow.index);
                                    page.dirty = true;
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: headMa
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: page.s(46)
                        anchors.rightMargin: page.s(58)   // silme ikonunun altını kaplama
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: binds.setProperty(bindRow.index, "expanded", !bindRow.expanded)
                    }

                    // --- açılan düzenleme paneli ---
                    ColumnLayout {
                        id: editPanel
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: page.s(46)
                        anchors.leftMargin: page.s(12)
                        anchors.rightMargin: page.s(12)
                        visible: bindRow.expanded
                        spacing: page.s(8)

                        // Kısayol yakalama. Odaktayken Hyprland'i boş bir submap'e
                        // alıyoruz, yoksa yakalamaya çalıştığın kombinasyon
                        // Hyprland'in kendi bind'ını tetiklerdi.
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: page.s(34)
                            radius: page.s(9)
                            color: captureTrap.activeFocus
                                   ? Qt.rgba(page.theme.red.r, page.theme.red.g, page.theme.red.b, 0.22)
                                   : Qt.rgba(page.theme.surface0.r, page.theme.surface0.g, page.theme.surface0.b, 0.9)
                            border.width: 1
                            border.color: captureTrap.activeFocus ? page.theme.red : Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.1)
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            Text {
                                anchors.centerIn: parent
                                text: captureTrap.activeFocus
                                      ? "Tuşlara bas (Esc ile bitir)…"
                                      : ((bindRow.mods !== "" ? bindRow.mods + " + " : "") +
                                         (bindRow.key !== "" ? bindRow.key : "Kısayol kaydetmek için tıkla"))
                                color: captureTrap.activeFocus ? page.theme.red : page.theme.text
                                font.family: "JetBrains Mono"
                                font.weight: Font.DemiBold
                                font.pixelSize: page.s(11)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    captureTrap.accMods = [];
                                    captureTrap.accKey = "";
                                    captureTrap.forceActiveFocus();
                                }
                            }

                            Item {
                                id: captureTrap
                                focus: false
                                property var accMods: []
                                property string accKey: ""

                                Keys.onShortcutOverride: (event) => { event.accepted = true; }
                                Keys.onEscapePressed: (event) => { captureTrap.focus = false; event.accepted = true; }
                                Keys.onTabPressed: (event) => { event.accepted = true; captureTrap.grab(event); }
                                Keys.onBacktabPressed: (event) => { event.accepted = true; captureTrap.grab(event); }
                                Keys.onReturnPressed: (event) => { event.accepted = true; captureTrap.grab(event); }
                                Keys.onEnterPressed: (event) => { event.accepted = true; captureTrap.grab(event); }
                                Keys.onReleased: (event) => { event.accepted = true; }
                                Keys.onPressed: (event) => { event.accepted = true; captureTrap.grab(event); }

                                function grab(event) {
                                    if (event.key === Qt.Key_Escape) return;

                                    let newMods = [];
                                    if (event.modifiers & Qt.MetaModifier)    newMods.push("$mainMod");
                                    if (event.modifiers & Qt.ControlModifier) newMods.push("CTRL");
                                    if (event.modifiers & Qt.AltModifier)     newMods.push("ALT");
                                    if (event.modifiers & Qt.ShiftModifier)   newMods.push("SHIFT_L");

                                    let modifierOnly = (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R ||
                                                        event.key === Qt.Key_Meta || event.key === Qt.Key_Control ||
                                                        event.key === Qt.Key_Alt || event.key === Qt.Key_Shift ||
                                                        event.key === Qt.Key_CapsLock);

                                    if (modifierOnly) {
                                        let merged = captureTrap.accMods.slice();
                                        for (let m of newMods) if (merged.indexOf(m) === -1) merged.push(m);
                                        captureTrap.accMods = merged;
                                        binds.setProperty(bindRow.index, "mods", merged.join(" "));
                                        page.dirty = true;
                                        return;
                                    }

                                    let k;
                                    if (event.key === Qt.Key_Space) k = "SPACE";
                                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) k = "RETURN";
                                    else if (event.key === Qt.Key_Tab) k = "TAB";
                                    else if (event.key === Qt.Key_Print) k = "Print";
                                    else if (event.key === Qt.Key_Left) k = "left";
                                    else if (event.key === Qt.Key_Right) k = "right";
                                    else if (event.key === Qt.Key_Up) k = "up";
                                    else if (event.key === Qt.Key_Down) k = "down";
                                    else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) k = "F" + (event.key - Qt.Key_F1 + 1);
                                    else if (event.text && event.text.length > 0) k = event.text.toUpperCase();
                                    else k = event.key.toString();

                                    let allMods = captureTrap.accMods.slice();
                                    for (let m of newMods) if (allMods.indexOf(m) === -1) allMods.push(m);
                                    captureTrap.accMods = allMods;
                                    captureTrap.accKey = k;

                                    binds.setProperty(bindRow.index, "mods", allMods.join(" "));
                                    binds.setProperty(bindRow.index, "key", k);
                                    page.dirty = true;
                                }

                                onActiveFocusChanged: {
                                    if (activeFocus) {
                                        Quickshell.execDetached(["hyprctl", "dispatch", "submap", "passthru"]);
                                    } else {
                                        captureTrap.accMods = [];
                                        captureTrap.accKey = "";
                                        Quickshell.execDetached(["hyprctl", "dispatch", "submap", "reset"]);
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: page.s(8)

                            Text {
                                Layout.preferredWidth: page.s(64)
                                text: "Tür"
                                color: page.theme.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: page.s(10)
                            }

                            Segmented {
                                Layout.fillWidth: true
                                theme: page.theme
                                sf: page.sf
                                options: page.bindTypes
                                currentIndex: page.bindTypes.indexOf(bindRow.type)
                                onPicked: (i) => {
                                    binds.setProperty(bindRow.index, "type", page.bindTypes[i]);
                                    page.dirty = true;
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: page.s(8)

                            Text {
                                Layout.preferredWidth: page.s(64)
                                text: "Dispatcher"
                                color: page.theme.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: page.s(10)
                            }

                            TextField {
                                id: dispField
                                Layout.fillWidth: true
                                Layout.preferredHeight: page.s(30)
                                Component.onCompleted: text = bindRow.dispatcher
                                placeholderText: "exec, killactive, movefocus…"
                                color: page.theme.text
                                placeholderTextColor: page.theme.overlay0
                                font.family: "JetBrains Mono"
                                font.pixelSize: page.s(10)
                                selectByMouse: true
                                leftPadding: page.s(10)
                                background: Rectangle {
                                    radius: page.s(8)
                                    color: Qt.rgba(page.theme.surface0.r, page.theme.surface0.g, page.theme.surface0.b, 0.9)
                                    border.width: 1
                                    border.color: dispField.activeFocus ? page.theme.mauve : Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.08)
                                    Behavior on border.color { ColorAnimation { duration: 180 } }
                                }
                                onTextChanged: {
                                    if (text !== bindRow.dispatcher) {
                                        binds.setProperty(bindRow.index, "dispatcher", text);
                                        page.dirty = true;
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: page.s(10)
                            spacing: page.s(8)

                            Text {
                                Layout.preferredWidth: page.s(64)
                                text: "Komut"
                                color: page.theme.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: page.s(10)
                            }

                            TextField {
                                id: cmdField2
                                Layout.fillWidth: true
                                Layout.preferredHeight: page.s(30)
                                Component.onCompleted: text = bindRow.command
                                placeholderText: "dispatcher argümanı (exec için komut)"
                                color: page.theme.text
                                placeholderTextColor: page.theme.overlay0
                                font.family: "JetBrains Mono"
                                font.pixelSize: page.s(10)
                                selectByMouse: true
                                leftPadding: page.s(10)
                                background: Rectangle {
                                    radius: page.s(8)
                                    color: Qt.rgba(page.theme.surface0.r, page.theme.surface0.g, page.theme.surface0.b, 0.9)
                                    border.width: 1
                                    border.color: cmdField2.activeFocus ? page.theme.mauve : Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.08)
                                    Behavior on border.color { ColorAnimation { duration: 180 } }
                                }
                                onTextChanged: {
                                    if (text !== bindRow.command) {
                                        binds.setProperty(bindRow.index, "command", text);
                                        page.dirty = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: page.s(4)
        text: "Tuşu boş bırakılan satırlar kaydedilirken atılır."
        color: page.theme.overlay0
        font.family: "JetBrains Mono"
        font.pixelSize: page.s(10)
        wrapMode: Text.WordWrap
    }
}
