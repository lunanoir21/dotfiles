import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import "WindowRegistry.js" as Registry
import "core"


PanelWindow {
    id: masterWindow
    color: "transparent"

    Caching { id: paths }

    IpcHandler {
        target: "main"

        function forceReload(): void {
            Quickshell.reload(true)
        }

        function handleCommand(cmd: string, targetWidget: string, arg: string): void {
            cmd = cmd || "";
            targetWidget = targetWidget || "";
            arg = arg || "";

            let isClosing = (masterWindow.currentActive !== "hidden" && !masterWindow.isVisible);
            let effectivelyActive = isClosing ? "hidden" : masterWindow.currentActive;

            if (cmd === "close") {
                switchWidget("hidden", "");
            } else if (cmd === "toggle" || cmd === "open") {
                delayedClear.stop();

                if (targetWidget === effectivelyActive) {
                    let currentItem = widgetStack.currentItem;

                    if (arg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== arg) {
                        currentItem.activeMode = arg;
                    } else if (cmd === "toggle") {
                        switchWidget("hidden", "");
                    }
                } else if (getLayout(targetWidget)) {
                    switchWidget(targetWidget, arg);
                }
            } else if (getLayout(cmd)) {
                let legacyArg = targetWidget;
                delayedClear.stop();

                if (cmd === effectivelyActive) {
                    let currentItem = widgetStack.currentItem;
                    if (legacyArg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== legacyArg) {
                        currentItem.activeMode = legacyArg;
                    } else {
                        switchWidget("hidden", "");
                    }
                } else {
                    switchWidget(cmd, legacyArg);
                }
            }
        }
    }

    WlrLayershell.namespace: "qs-master"
    WlrLayershell.layer: WlrLayer.Overlay

    exclusionMode: ExclusionMode.Ignore
    focusable: true

    implicitWidth: masterWindow.screen.width
    implicitHeight: masterWindow.screen.height

    visible: isVisible

    mask: Region { item: topBarHole; intersection: Intersection.Xor }

    Item {
        id: topBarHole
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48

        anchors.leftMargin: (masterWindow.currentActive !== "hidden" && masterWindow.animX < 10 && masterWindow.animY < height) ? masterWindow.animW : 0
        anchors.rightMargin: (masterWindow.currentActive !== "hidden" && (masterWindow.animX + masterWindow.animW) > (parent.width - 10) && masterWindow.animY < height) ? masterWindow.animW : 0

        Behavior on anchors.leftMargin {
            enabled: masterWindow.currentActive !== "hidden"
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.rightMargin {
            enabled: masterWindow.currentActive !== "hidden"
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: masterWindow.isVisible
        onClicked: switchWidget("hidden", "")
    }

    // =========================================================
    // --- DAEMON: PRELOADING SYSTEM
    // =========================================================
    Item {
        id: preloaderContainer
        visible: false
    }

    property var widgetCache: ({})

    function preloadWidget(name) {
        if (widgetCache[name]) return;
        let t = getLayout(name);
        if (!t || !t.comp) return;
        // t.comp is a path string (see WindowRegistry.js); StackView.replace()
        // resolves those itself, but createObject() needs an actual Component.
        let component = Qt.createComponent(t.comp);
        if (component.status === Component.Error) {
            console.warn("preloadWidget: failed to load", t.comp, component.errorString());
            return;
        }
        let obj = component.createObject(preloaderContainer, {
            "notifModel": masterWindow.notifModel,
            "liveNotifs": masterWindow.liveNotifs,
            "visible": false
        });
        if (obj) widgetCache[name] = obj;
    }

    Component.onCompleted: {
        Qt.callLater(() => preloadWidget("settings"));
        preloadStaggerTimer.start();
    }

    Timer {
        id: preloadStaggerTimer
        interval: 900
        repeat: false
        onTriggered: {
            // Sidebar center'ı da önden kur: kendi poll'unu gizliyken yavaş
            // tempoda çalıştırdığı için açıldığı anda ekranda taze sistem
            // durumu oluyor, "önce boş sonra dolan" panel yok.
            preloadWidget("sidebarcenter");
        }
    }

    // =========================================================

    property string currentActive: "hidden"

    onCurrentActiveChanged: {
        Quickshell.execDetached(["bash", "-c", "echo '" + currentActive + "' > " + paths.runDir + "/current_widget"]);
    }

    // Masaüstü değişince açık paneli kapat. Kullanıcı başka bir işe geçiyor;
    // panelin ekranın ortasında asılı kalması engel oluyor. Kısayol, jest ya
    // da başka bir uygulama — kaynağı ne olursa olsun Hyprland'in kendi olayını
    // dinlediğimiz için hepsi kapsanıyor.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (masterWindow.currentActive === "hidden") return;
            if (event.name === "workspace" || event.name === "workspacev2"
                || event.name === "focusedmon") {
                masterWindow.switchWidget("hidden", "");
            }
        }
    }

    property bool isVisible: false
    property string activeArg: ""
    property bool disableMorph: false

    property int morphDuration: 230
    property int morphDurationSwitch: 210
    property int exitDuration: 160

    property real animW: 1
    property real animH: 1
    property real animX: 0
    property real animY: 0

    property real targetW: 1
    property real targetH: 1

    property real globalUiScale: Settings.uiScale

    // =========================================================
    // --- DAEMON: NOTIFICATION HANDLING
    // =========================================================
    ListModel { id: globalNotificationHistory }
    ListModel { id: activePopupsModel }

    property var liveNotifs: ({})
    property int _popupCounter: 0

    // Lets the dynamic island answer/reject calls (and drive any other
    // notification action) through the app's own D-Bus action instead of
    // faking input — the same live Notification object the OSD popups invoke.
    IpcHandler {
        target: "notificationBridge"

        function invokeAction(uid: string, actionId: string): void {
            let n = masterWindow.liveNotifs[uid];
            if (!n || !n.actions) return;
            for (let i = 0; i < n.actions.length; i++) {
                if (n.actions[i].identifier === actionId) {
                    n.actions[i].invoke();
                    break;
                }
            }
        }

        function sendInlineReply(uid: string, text: string): void {
            let n = masterWindow.liveNotifs[uid];
            if (!n || !n.hasInlineReply) return;
            n.sendInlineReply(text);
        }
    }

    // --- NEW: Startup Grace Period Flag & Timer ---
    property bool isStartup: true
    Timer {
        interval: 500
        running: true
        onTriggered: masterWindow.isStartup = false
    }

    function removePopup(uid) {
        for (let i = 0; i < activePopupsModel.count; i++) {
            if (activePopupsModel.get(i).uid === uid) {
                activePopupsModel.remove(i);
                break;
            }
        }
    } 

    NotificationServer {
        id: globalNotificationServer
        // Bildirim geçmişi Sidebar Center'ın kendi listesidir. Quickshell'in
        // varsayılanı true olduğu için reload sonrası eski nesiller tekrar
        // onNotification'a düşüyor ve kullanıcı temizlediği kayıtları yeniden
        // görüyordu.
        keepOnReload: false
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        // Without this, senders never even see inline-reply advertised as a
        // server capability, so they have no reason to attach the
        // "inline-reply" action in the first place — Notification.hasInlineReply
        // would just stay false for everyone, capable app or not.
        inlineReplySupported: true

        onNotification: (n) => {
            // keepOnReload false olsa da geçiş sırasında önceki nesil ulaşırsa
            // geçmişe sokma. lastGeneration yalnızca reload'dan taşınan
            // bildirimlerde true olur; yeni gelenler normal akıştan geçer.
            if (n.lastGeneration) {
                n.tracked = false;
                return;
            }

            n.tracked = true;

            let extractedActions = [];
            if (n.actions) {
                for (let i = 0; i < n.actions.length; i++) {
                    extractedActions.push({
                        "id": n.actions[i].identifier || "",
                        "text": n.actions[i].text || n.actions[i].name || "Action"
                    });
                }
            }

            masterWindow._popupCounter++;
            let currentUid = masterWindow._popupCounter;

            // Always store the live object so the history center can interact with it
            masterWindow.liveNotifs[currentUid] = n;

            let notifData = {
                "appName":     n.appName  !== "" ? n.appName  : "System",
                "summary":     n.summary  !== "" ? n.summary  : "No Title",
                "body":        n.body     !== "" ? n.body     : "",
                // Browser-sent notifications (WhatsApp Web, web.telegram.org,
                // etc.) almost always leave appIcon as the browser's own icon
                // (or empty) and carry the real per-site icon in the
                // image-path/image-data hint instead, which Quickshell
                // exposes separately as `image` — appIcon alone is why every
                // browser-origin notification rendered with the wrong logo.
                "iconPath":    n.image !== "" ? n.image : (n.appIcon !== "" ? n.appIcon : ""),
                // Base64-wrapped: `quickshell ipc call` expands any bare
                // "[...]"-shaped argument into several positional arguments
                // by splitting top-level commas, so a raw JSON array string
                // silently miscounts the argument list on the receiving end
                // (fails outright with >=2 actions, and "[]" itself is read
                // as zero arguments). Base64 never starts with "[".
                "actionsJson": Qt.btoa(JSON.stringify(extractedActions)),
                "uid":         currentUid,
                "timestamp":   Date.now(),
                "hasInlineReply": n.hasInlineReply,
                // Passed through as-is, empty included: the island substitutes
                // its own localized placeholder when the sender didn't supply
                // one. Defaulting here instead would hardcode one language in
                // a file that has no idea which one the island is running in.
                "inlineReplyPlaceholder": n.inlineReplyPlaceholder,
                "notif":       n
            };

            // Web notification bridges (Instagram/Facebook Messenger web,
            // WhatsApp Web, etc.) routinely resend the exact same summary and
            // body as a brand-new notification id instead of using the MPRIS
            // "replaces" mechanism, so nothing here ever recognizes them as
            // updates — left unchecked, the history grows forever no matter
            // how often it's cleared, and clearing looks like it "didn't
            // work" the next time the sender repeats itself seconds later.
            // Collapse an immediate repeat of the same app+text into the
            // existing top entry instead of stacking a new one.
            let isImmediateRepeat = globalNotificationHistory.count > 0
                && (() => {
                    let top = globalNotificationHistory.get(0);
                    return top.appName === notifData.appName
                        && top.summary === notifData.summary
                        && top.body === notifData.body
                        && (Date.now() - top.timestamp) < 60000;
                })();

            if (isImmediateRepeat) {
                let previousUid = globalNotificationHistory.get(0).uid;
                let previousNotification = globalNotificationHistory.get(0).notif;
                if (previousNotification && previousNotification !== notifData.notif) {
                    try { previousNotification.dismiss(); } catch (e) {}
                }
                if (previousUid !== undefined) delete masterWindow.liveNotifs[previousUid];
                globalNotificationHistory.setProperty(0, "timestamp", notifData.timestamp);
                globalNotificationHistory.setProperty(0, "uid", notifData.uid);
                globalNotificationHistory.setProperty(0, "notif", notifData.notif);
            } else {
                globalNotificationHistory.insert(0, notifData);
            }

            // Hand it to the dynamic island, which is what actually raises a
            // visible card. The island runs in this same process but under its
            // own Variants, with no QML path from here to it — the IPC surface
            // it exposes (notifyWithActions, which also routes calls to the
            // call screen) is the interface it publishes for exactly this, and
            // the same one its own inline replies come back through.
            //
            // Whether a card is shown at all, for how long, in which of its
            // five designs and with which entrance, is the island's own
            // setting: ~/.config/quickshell/dynamic-island/settings.json. This
            // side always offers the notification and never second-guesses it,
            // so there is only ever one place those preferences live.
            // shellRoot is the config *directory*, and `-p` on a directory
            // looks for a lowercase shell.qml that does not exist here — the
            // entry point has to be named outright.
            Quickshell.execDetached(["quickshell", "-p", Quickshell.shellDir + "/Shell.qml",
                "ipc", "call", "dynamicIsland", "notifyWithActions",
                notifData.appName, notifData.summary, notifData.body,
                notifData.iconPath, notifData.actionsJson, String(currentUid),
                n.hasInlineReply ? "true" : "false",
                notifData.inlineReplyPlaceholder]);
        }
    }

    property var notifModel: globalNotificationHistory

    onGlobalUiScaleChanged: { handleNativeScreenChange(); }

    // =========================================================
    // --- LAYOUT CACHE
    // =========================================================
    property var    _layoutCache:    ({})
    property string _layoutCacheKey: ""

    function getLayout(name) {
        let key = name + "|" + masterWindow.width + "|" + masterWindow.height + "|" + masterWindow.globalUiScale;
        if (_layoutCacheKey === key) return _layoutCache[key];
        let result = Registry.getLayout(name, 0, 0, masterWindow.width, masterWindow.height, masterWindow.globalUiScale);
        _layoutCache = {};
        _layoutCache[key] = result;
        _layoutCacheKey = key;
        return result;
    }

    Connections {
        target: masterWindow
        function onWidthChanged()  { _layoutCacheKey = ""; handleNativeScreenChange(); }
        function onHeightChanged() { _layoutCacheKey = ""; handleNativeScreenChange(); }
    }

    function handleNativeScreenChange() {
        if (masterWindow.currentActive === "hidden") return;

        let t = getLayout(masterWindow.currentActive);
        if (!t) return;

        let currentItem = widgetStack.currentItem;
        let finalW = (currentItem && currentItem.targetMasterWidth  !== undefined) ? currentItem.targetMasterWidth  : t.w;
        let finalH = (currentItem && currentItem.targetMasterHeight !== undefined) ? currentItem.targetMasterHeight : t.h;
        let finalX = t.rx;
        if (currentItem && currentItem.targetMasterWidth !== undefined && finalW !== t.w) {
            finalX = Math.floor((masterWindow.width / 2) - (finalW / 2));
        }

        masterWindow.animX = finalX;
        masterWindow.animY = t.ry;
        masterWindow.animW = finalW;
        masterWindow.animH = finalH;
        masterWindow.targetW = finalW;
        masterWindow.targetH = finalH;
    }

    onIsVisibleChanged: {
        if (isVisible) widgetStack.forceActiveFocus();
    }

    // =========================================================
    // --- ANIMATED BOUNDING BOX
    // =========================================================
    Item {
        x: masterWindow.animX
        y: masterWindow.animY
        width:  masterWindow.animW
        height: masterWindow.animH
        clip: true

        Behavior on x {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: masterWindow.isVisible ? Easing.OutCubic : Easing.InCubic
            }
        }

        MouseArea { anchors.fill: parent }

        Item {
            anchors.fill: parent

            StackView {
                id: widgetStack
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: {
                    switchWidget("hidden", "");
                    event.accepted = true;
                }

                onCurrentItemChanged: {
                    if (currentItem) currentItem.forceActiveFocus();
                }

                replaceEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 0.0; to: 1.0
                            duration: masterWindow.morphDurationSwitch
                            easing.type: Easing.OutQuint
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.98; to: 1.0
                            duration: masterWindow.morphDurationSwitch
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                replaceExit: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 1.0; to: 0.0
                            duration: masterWindow.morphDurationSwitch
                            easing.type: Easing.InQuint
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 1.0; to: 0.98
                            duration: masterWindow.morphDurationSwitch
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // --- WIDGET SWITCHING
    // =========================================================
    function switchWidget(newWidget, arg) {
        delayedClear.stop();

        if (newWidget === "hidden") {
            if (currentActive !== "hidden") {
                masterWindow.morphDuration = masterWindow.exitDuration;
                masterWindow.disableMorph = false;

                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.isVisible = false;

                delayedClear.start();
            }
        } else {
            if (currentActive === "hidden" || !masterWindow.isVisible) {
                masterWindow.morphDuration = newWidget === "sidebarcenter" ? 140 : 230;
                masterWindow.disableMorph = false;

                let t = getLayout(newWidget);
                masterWindow.animX = t.rx;
                masterWindow.animY = t.ry;
                masterWindow.animW = t.w;
                masterWindow.animH = t.h;
                masterWindow.targetW = t.w;
                masterWindow.targetH = t.h;
            } else {
                masterWindow.morphDuration = newWidget === "sidebarcenter" ? 120 : masterWindow.morphDurationSwitch;
                masterWindow.disableMorph = false;
            }

            Qt.callLater(() => executeSwitch(newWidget, arg, false));
        }
    }

    function executeSwitch(newWidget, arg, immediate) {
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;

        let t = getLayout(newWidget);
        masterWindow.animX = t.rx;
        masterWindow.animY = t.ry;
        masterWindow.animW = t.w;
        masterWindow.animH = t.h;
        masterWindow.targetW = t.w;
        masterWindow.targetH = t.h;

        let props = {};
        props["notifModel"]   = masterWindow.notifModel;
        props["liveNotifs"]   = masterWindow.liveNotifs;
        props["layoutWidth"]  = t.w;
        props["layoutHeight"] = t.h;
        if (newWidget === "wallpaper") props["widgetArg"] = arg;

        let cached = widgetCache[newWidget];
        if (cached) {
            if (cached.notifModel   !== undefined) cached.notifModel   = masterWindow.notifModel;
            if (cached.liveNotifs   !== undefined) cached.liveNotifs   = masterWindow.liveNotifs;
            if (cached.layoutWidth  !== undefined) cached.layoutWidth  = t.w;
            if (cached.layoutHeight !== undefined) cached.layoutHeight = t.h;
            if (newWidget === "wallpaper" && cached.widgetArg !== undefined) cached.widgetArg = arg;
            if (arg !== "" && cached.activeMode !== undefined) cached.activeMode = arg;

            cached.visible = true;
            if (immediate) {
                widgetStack.replace(cached, {}, StackView.Immediate);
            } else {
                widgetStack.replace(cached, {});
            }
        } else {
            if (immediate) {
                widgetStack.replace(t.comp, props, StackView.Immediate);
            } else {
                widgetStack.replace(t.comp, props);
            }
        }

        let currentItem = widgetStack.currentItem;
        if (currentItem) {
            if (currentItem.targetMasterWidth !== undefined) {
                let dynW = currentItem.targetMasterWidth;
                masterWindow.animW = dynW;
                masterWindow.targetW = dynW;
                masterWindow.animX = Math.floor((masterWindow.width / 2) - (dynW / 2));
            }
            if (currentItem.targetMasterHeight !== undefined) {
                masterWindow.animH = currentItem.targetMasterHeight;
                masterWindow.targetH = currentItem.targetMasterHeight;
            }
        }

        masterWindow.isVisible = true;
    }

    Timer {
        id: delayedClear
        interval: 200
        onTriggered: {
            masterWindow.currentActive = "hidden";
            widgetStack.clear();
            masterWindow.disableMorph = false;
        }
    }
}
