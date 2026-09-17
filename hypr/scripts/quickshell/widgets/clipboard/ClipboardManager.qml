import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../core"

Item {
    id: window
    focus: true

    Caching { id: paths }

    FileView {
        id: pinStoreFile
        path: paths.getCacheDir("clipboard") + "/pins.json"
        watchChanges: true
        onAdapterUpdated: pinWriteTimer.restart()
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                pinWriteTimer.restart();
            }
        }
        adapter: JsonAdapter {
            id: pinAdapter
            property list<string> pinnedIds: []
        }
    }

    Timer {
        id: pinWriteTimer
        interval: 150
        repeat: false
        onTriggered: pinStoreFile.writeAdapter()
    }

    // Watches cliphist's db so external copies show up live while the window is open.
    // The db can be huge (embedded images), so never actually read its content - only mtime.
    FileView {
        id: cliphistDbWatcher
        path: Quickshell.env("HOME") + "/.cache/cliphist/db"
        watchChanges: true
        preload: false
        blockAllReads: true
        onFileChanged: liveRefreshTimer.restart()
        onLoadFailed: error => {}
    }

    Timer {
        id: liveRefreshTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!window.visible || window.isLoading) return;
            window.currentOffset = 0;
            window.hasMore = true;
            window.isLoading = true;
            clipFetcher.command = ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/widgets/clipboard/clip_fetcher.py", 0, window.fetchLimit, paths.getCacheDir("clipboard")];
            clipFetcher.running = true;
        }
    }

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    function s(val) {
        return scaler.s(val);
    }

    MatugenColors { id: _theme }

    readonly property color base: _theme.base
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color blue: _theme.blue

    property var allClips: []

    // Pagination properties
    property int currentOffset: 0
    property int fetchLimit: 24
    property bool isLoading: false
    property bool hasMore: true

    // Global state
    property int navDuration: 0
    property bool previewMode: false
    property bool previewAnimationDone: false
    property bool previewEditMode: false
    property string fullTextPreview: ""
    property int pendingIndex: -1

    // Filtering / selection state
    property string typeFilter: "all"
    property var selectedIds: []

    property real layoutWidth: width
    property real layoutHeight: height

    // Startup state to prevent accordion layout shifts
    property bool isInitialLoad: true

    onPreviewModeChanged: {
        if (!previewMode) {
            fullTextPreview = "";
            previewAnimationDone = false;
            previewEditMode = false;
            searchInput.forceActiveFocus();
        }
    }

    Process {
        id: fullTextFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                window.fullTextPreview = this.text;
            }
        }
    }

    function updatePreviewText() {
        window.fullTextPreview = "";
        let item = clipModel.get(clipList.currentIndex);
        if (item && item.type === "text") {
            fullTextFetcher.command = ["cliphist", "decode", item.id.toString()];
            fullTextFetcher.running = true;
        }
    }

    Process {
        id: clipFetcher
        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/widgets/clipboard/clip_fetcher.py", window.currentOffset, window.fetchLimit, paths.getCacheDir("clipboard")]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        let newItems = JSON.parse(this.text);

                        if (newItems.length < window.fetchLimit) {
                            window.hasMore = false;
                        }

                        if (window.currentOffset === 0) {
                            let isDifferent = window.allClips.length !== newItems.length;
                            if (!isDifferent) {
                                for (let i = 0; i < newItems.length; i++) {
                                    if (window.allClips[i].id !== newItems[i].id) {
                                        isDifferent = true;
                                        break;
                                    }
                                }
                            }

                            if (isDifferent || window.allClips.length === 0) {
                                window.allClips = newItems;
                                window.filterClips(searchInput.text);
                            }
                        } else {
                            window.appendClips(newItems);
                        }
                    }
                } catch(e) {
                    console.log("Error parsing clipboard list: ", e);
                } finally {
                    window.isLoading = false;
                    window.isInitialLoad = false;
                }
            }
        }
    }

    ListModel {
        id: clipModel
    }

    function loadMore() {
        if (isLoading || !hasMore) return;
        isLoading = true;
        currentOffset += fetchLimit;
        clipFetcher.command = ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/widgets/clipboard/clip_fetcher.py", window.currentOffset, window.fetchLimit, paths.getCacheDir("clipboard")];
        clipFetcher.running = true;
    }

    function appendClips(newItems) {
        let q = searchInput.text.toLowerCase();
        for (let i = 0; i < newItems.length; i++) {
            allClips.push(newItems[i]);
            if (window.typeFilter !== "all" && newItems[i].type !== window.typeFilter) continue;
            if (q === "" || newItems[i].type === "image" || newItems[i].content.toLowerCase().includes(q)) {
                clipModel.append(newItems[i]);
            }
        }

        if (window.pendingIndex !== -1) {
            if (window.pendingIndex < clipModel.count) {
                clipList.currentIndex = window.pendingIndex;
            } else {
                clipList.currentIndex = clipModel.count - 1;
            }
            window.pendingIndex = -1;
        }
    }

    function isPinned(id) {
        return pinAdapter.pinnedIds.indexOf(id.toString()) !== -1;
    }

    function togglePin(id) {
        let sid = id.toString();
        let list = pinAdapter.pinnedIds.slice();
        let idx = list.indexOf(sid);
        if (idx === -1) {
            list.unshift(sid);
        } else {
            list.splice(idx, 1);
        }
        pinAdapter.pinnedIds = list;
        window.filterClips(searchInput.text);
    }

    function sortPinnedFirst(arr) {
        let pinned = [];
        let rest = [];
        for (let i = 0; i < arr.length; i++) {
            if (window.isPinned(arr[i].id)) pinned.push(arr[i]);
            else rest.push(arr[i]);
        }
        return pinned.concat(rest);
    }

    function isSelected(id) {
        return window.selectedIds.indexOf(id.toString()) !== -1;
    }

    function toggleSelect(id) {
        let sid = id.toString();
        let list = window.selectedIds.slice();
        let idx = list.indexOf(sid);
        if (idx === -1) list.push(sid); else list.splice(idx, 1);
        window.selectedIds = list;
    }

    function clearSelection() {
        window.selectedIds = [];
    }

    function deleteIds(ids) {
        let validIds = ids.filter(id => /^[0-9]+$/.test(id.toString()));
        if (validIds.length === 0) return;

        let cmd = "";
        for (let i = 0; i < validIds.length; i++) {
            cmd += "printf '%s\\t\\n' " + validIds[i] + " | cliphist delete; ";
        }
        Quickshell.execDetached(["bash", "-c", cmd]);

        let idSet = {};
        for (let i = 0; i < validIds.length; i++) idSet[validIds[i].toString()] = true;

        window.allClips = window.allClips.filter(c => !idSet[c.id.toString()]);
        window.selectedIds = window.selectedIds.filter(id => !idSet[id]);

        let prevIndex = clipList.currentIndex;
        window.filterClips(searchInput.text);
        if (clipModel.count > 0) {
            clipList.currentIndex = Math.min(prevIndex, clipModel.count - 1);
        }
    }

    function deleteSelectionOrCurrent() {
        if (window.selectedIds.length > 0) {
            window.deleteIds(window.selectedIds.slice());
        } else if (clipList.currentIndex >= 0 && clipList.currentIndex < clipModel.count) {
            window.deleteIds([clipModel.get(clipList.currentIndex).id]);
        }
    }

    function filterClips(query) {
        clipList.currentIndex = -1;
        clipList.positionViewAtBeginning();

        let q = query.toLowerCase();
        clipModel.clear();

        let matched = [];
        for (let i = 0; i < allClips.length; i++) {
            let item = allClips[i];
            if (window.typeFilter !== "all" && item.type !== window.typeFilter) continue;
            if (item.type === "image" || item.content.toLowerCase().includes(q)) {
                matched.push(item);
            }
        }

        matched = window.sortPinnedFirst(matched);
        for (let i = 0; i < matched.length; i++) {
            clipModel.append(matched[i]);
        }

        if (clipModel.count > 0) {
            clipList.currentIndex = 0;
        }
    }

    function copyToClipboard(id) {
        Quickshell.execDetached(["bash", "-c", "cliphist decode " + id + " | wl-copy"]);
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    Process {
        id: editCopyProcess
        property string pendingText: ""
        command: ["wl-copy"]
        onRunningChanged: {
            if (editCopyProcess.running) {
                editCopyProcess.write(editCopyProcess.pendingText);
                editCopyProcess.stdinEnabled = false;
            }
        }
    }

    function copyEditedText(text) {
        editCopyProcess.pendingText = text;
        editCopyProcess.stdinEnabled = true;
        editCopyProcess.running = true;
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    Timer {
        id: focusTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    Connections {
        target: window
        function onVisibleChanged() {
            if (window.visible) {
                if (window.allClips.length === 0) {
                    window.isInitialLoad = true;
                }

                focusTimer.restart();
                introPhaseAnim.restart();
                window.navDuration = 0;
                window.previewMode = false;
                window.previewAnimationDone = false;
                window.fullTextPreview = "";
                window.pendingIndex = -1;
                window.selectedIds = [];

                window.currentOffset = 0;
                window.hasMore = true;
                window.isLoading = true;
                clipFetcher.command = ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/widgets/clipboard/clip_fetcher.py", 0, window.fetchLimit, paths.getCacheDir("clipboard")];
                clipFetcher.running = true;
            } else {
                searchInput.text = "";
                window.pendingIndex = -1;

                window.filterClips("");
                if (clipModel.count > 0) {
                    clipList.currentIndex = 0;
                    clipList.positionViewAtBeginning();
                }
            }
        }
    }

    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0; to: 1; duration: 420; easing.type: Easing.OutExpo; running: true
    }

    function currentHints() {
        if (window.previewEditMode) {
            return [
                { k: "⌃↵", l: "Kopyala" },
                { k: "Esc", l: "Vazgeç" }
            ];
        }
        if (window.selectedIds.length > 0) {
            return [
                { k: "⌫", l: window.selectedIds.length + " öğeyi sil" },
                { k: "Esc", l: "Seçimi temizle" }
            ];
        }
        if (window.previewMode) {
            return [
                { k: "↵", l: "Kopyala" },
                { k: "⌃E", l: "Düzenle" },
                { k: "⌃P", l: "Pinle" },
                { k: "Esc", l: "Kapat" }
            ];
        }
        return [
            { k: "↵", l: "Kopyala" },
            { k: "⇥", l: "Önizle" },
            { k: "⌃P", l: "Pinle" },
            { k: "⌫", l: "Sil" },
            { k: "Esc", l: "Kapat" }
        ];
    }

    Rectangle {
        id: mainBg
        width: layoutWidth

        property real searchHeight: window.s(60)
        property real separatorHeight: 1
        property real hintBarH: window.s(32)

        property int cols: 3
        property real cellH: window.s(142)

        property real maxVisibleRows: 4
        property real visibleRows: maxVisibleRows
        property real animatedListHeight: visibleRows * cellH
        property real animatedMargins: window.s(18)

        height: searchHeight + separatorHeight + animatedMargins + animatedListHeight + hintBarH

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        radius: window.s(18)
        color: Qt.rgba(window.base.r, window.base.g, window.base.b, 1.0)
        border.color: window.surface1
        border.width: 1
        clip: true

        transform: Translate { y: (window.introPhase - 1) * window.s(50) }
        opacity: window.introPhase

        // ---------------------------------------------------------------
        // HEADER
        // ---------------------------------------------------------------
        Rectangle {
            id: headerArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: mainBg.searchHeight
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: window.s(20)
                anchors.rightMargin: window.s(20)
                spacing: window.s(12)

                Item {
                    width: window.s(18)
                    height: window.s(18)

                    Text {
                        anchors.centerIn: parent
                        text: "󰅌"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(17)
                        font.weight: Font.DemiBold
                        color: searchInput.activeFocus ? window.mauve : window.subtext0

                        opacity: !window.previewMode ? 1 : 0
                        scale: !window.previewMode ? 1 : 0.5
                        rotation: !window.previewMode ? 0 : -90

                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰈈"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(17)
                        font.weight: Font.DemiBold
                        color: window.mauve

                        opacity: window.previewMode ? 1 : 0
                        scale: window.previewMode ? 1 : 0.5
                        rotation: window.previewMode ? 0 : 90

                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    }
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: Item {}
                    color: window.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(15)

                    placeholderText: "Ara..."
                    placeholderTextColor: window.subtext0

                    verticalAlignment: TextInput.AlignVCenter
                    focus: true

                    onTextChanged: {
                        if (window.previewMode) { window.previewMode = false; }
                        window.pendingIndex = -1;
                        filterClips(text);
                    }

                    Keys.onTabPressed: {
                        if (clipModel.count > 0) {
                            window.previewMode = !window.previewMode;
                            if (window.previewMode) {
                                window.updatePreviewText();
                            }
                        }
                        event.accepted = true;
                    }

                    Keys.onRightPressed: {
                        window.previewMode = false;
                        window.navDuration = 250;
                        window.pendingIndex = -1;

                        let targetIdx = clipList.currentIndex + 1;
                        if (targetIdx < clipModel.count) {
                            clipList.currentIndex = targetIdx;
                        } else if (window.hasMore) {
                            window.pendingIndex = targetIdx;
                            window.loadMore();
                        }
                        event.accepted = true;
                    }

                    Keys.onLeftPressed: {
                        window.previewMode = false;
                        window.navDuration = 250;
                        window.pendingIndex = -1;

                        if (clipList.currentIndex > 0) { clipList.currentIndex--; }
                        event.accepted = true;
                    }

                    Keys.onDownPressed: {
                        if (window.previewMode && textPreviewFlickable.visible) {
                            textPreviewFlickable.contentY = Math.min(textPreviewFlickable.contentY + window.s(60), Math.max(0, textPreviewFlickable.contentHeight - textPreviewFlickable.height));
                        } else {
                            window.previewMode = false;
                            window.navDuration = 250;
                            window.pendingIndex = -1;

                            let targetIdx = clipList.currentIndex + mainBg.cols;
                            if (targetIdx < clipModel.count) {
                                clipList.currentIndex = targetIdx;
                            } else if (window.hasMore) {
                                window.pendingIndex = targetIdx;
                                window.loadMore();
                            } else {
                                clipList.currentIndex = clipModel.count - 1;
                            }
                        }
                        event.accepted = true;
                    }

                    Keys.onUpPressed: {
                        if (window.previewMode && textPreviewFlickable.visible) {
                            textPreviewFlickable.contentY = Math.max(textPreviewFlickable.contentY - window.s(60), 0);
                        } else {
                            window.previewMode = false;
                            window.navDuration = 250;
                            window.pendingIndex = -1;

                            if (clipList.currentIndex - mainBg.cols >= 0) { clipList.currentIndex -= mainBg.cols; }
                        }
                        event.accepted = true;
                    }

                    Keys.onReturnPressed: {
                        if (clipList.currentIndex >= 0 && clipList.currentIndex < clipModel.count) {
                            copyToClipboard(clipModel.get(clipList.currentIndex).id);
                        }
                        event.accepted = true;
                    }

                    Keys.onEscapePressed: {
                        if (window.previewEditMode) {
                            window.previewEditMode = false;
                        } else if (window.previewMode) {
                            window.previewMode = false;
                        } else if (window.selectedIds.length > 0) {
                            window.clearSelection();
                        } else {
                            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
                        }
                        event.accepted = true;
                    }

                    Keys.onDeletePressed: {
                        window.deleteSelectionOrCurrent();
                        event.accepted = true;
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                            if (clipList.currentIndex >= 0 && clipList.currentIndex < clipModel.count) {
                                window.togglePin(clipModel.get(clipList.currentIndex).id);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_E && (event.modifiers & Qt.ControlModifier)) {
                            if (window.previewMode && previewMorph.curItem && previewMorph.curItem.type === "text") {
                                window.previewEditMode = !window.previewEditMode;
                            }
                            event.accepted = true;
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.topMargin: window.s(12)
                    Layout.bottomMargin: window.s(12)
                    color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.6)
                }

                Row {
                    spacing: window.s(4)

                    Repeater {
                        model: [
                            { key: "all", icon: "󰅌" },
                            { key: "text", icon: "󰗧" },
                            { key: "image", icon: "󰋩" }
                        ]
                        delegate: Rectangle {
                            width: window.s(28)
                            height: window.s(28)
                            radius: window.s(8)
                            color: window.typeFilter === modelData.key
                                ? window.mauve
                                : (filterMa.containsMouse ? window.surface0 : "transparent")
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.s(14)
                                color: window.typeFilter === modelData.key ? window.base : window.subtext0
                            }

                            MouseArea {
                                id: filterMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    window.typeFilter = modelData.key;
                                    window.filterClips(searchInput.text);
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: separatorLine
            anchors.top: headerArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: mainBg.separatorHeight
            color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.6)
        }

        // ---------------------------------------------------------------
        // GRID
        // ---------------------------------------------------------------
        Column {
            anchors.centerIn: gridArea
            spacing: window.s(8)
            visible: clipModel.count === 0 && !window.isLoading
            opacity: visible ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰅌"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: window.s(28)
                color: window.subtext0
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: searchInput.text !== "" || window.typeFilter !== "all" ? "Sonuç yok" : "Pano geçmişi boş"
                font.family: "JetBrains Mono"
                font.pixelSize: window.s(13)
                color: window.subtext0
            }
        }

        Item {
            id: gridArea
            anchors.top: separatorLine.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: mainBg.animatedMargins / 2
            anchors.bottomMargin: mainBg.animatedMargins / 2
            height: mainBg.animatedListHeight

            GridView {
                id: clipList
                anchors.fill: parent
                anchors.leftMargin: window.s(12)
                anchors.rightMargin: window.s(12)

                clip: true
                model: clipModel

                cellWidth: Math.floor((gridArea.width - window.s(24)) / mainBg.cols)
                cellHeight: mainBg.cellH

                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                highlightFollowsCurrentItem: false

                populate: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 1; duration: 0 }
                }

                add: Transition {
                    SequentialAnimation {
                        PropertyAction { property: "opacity"; value: 0 }
                        PropertyAction { property: "scale"; value: 0.85 }
                        PauseAnimation { duration: 10 }
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "scale"; to: 1; duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                        }
                    }
                }

                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 350; easing.type: Easing.OutExpo }
                }

                onContentYChanged: {
                    if (contentY + height >= contentHeight - window.s(80)) {
                        window.loadMore();
                    }
                }

                Behavior on contentY {
                    enabled: window.navDuration > 0
                    NumberAnimation { duration: 250; easing.type: Easing.OutExpo }
                }

                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && clipList.model !== null) {
                        if (currentIndex >= clipModel.count - (mainBg.cols * 2)) {
                            window.loadMore();
                        }

                        let row = Math.floor(currentIndex / mainBg.cols);
                        let targetTop = row * mainBg.cellH;
                        let targetBottom = targetTop + mainBg.cellH;

                        if (window.navDuration > 0) {
                            if (targetTop < contentY) {
                                contentY = targetTop;
                            } else if (targetBottom > contentY + height) {
                                contentY = targetBottom - height;
                            }
                        } else {
                            positionViewAtIndex(currentIndex, GridView.Contain);
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: window.s(4)
                        radius: window.s(2)
                        color: window.surface2
                        opacity: 0.5
                    }
                }

                highlight: Item {
                    z: 0
                    Rectangle {
                        id: activeHighlight
                        width: clipList.cellWidth - window.s(12)
                        height: clipList.cellHeight - window.s(12)
                        radius: window.s(10)
                        color: window.mauve

                        property int curIdx: clipList.currentIndex
                        property real targetX: curIdx === -1 || clipList.model === null ? 0 : (curIdx % mainBg.cols) * clipList.cellWidth
                        property real targetY: curIdx === -1 || clipList.model === null ? 0 : Math.floor(curIdx / mainBg.cols) * clipList.cellHeight

                        Behavior on x { NumberAnimation { duration: window.navDuration > 0 ? window.navDuration : 350; easing.type: Easing.OutExpo } }
                        Behavior on y { NumberAnimation { duration: window.navDuration > 0 ? window.navDuration : 350; easing.type: Easing.OutExpo } }

                        x: targetX + window.s(6)
                        y: targetY + window.s(6)
                        opacity: clipList.count > 0 && clipList.currentIndex >= 0 && clipList.model !== null ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                }

                delegate: Item {
                    id: delegateRoot
                    width: clipList.cellWidth
                    height: clipList.cellHeight

                    z: index === clipList.currentIndex ? 50 : 1

                    readonly property bool isCurrent: index === clipList.currentIndex

                    Rectangle {
                        id: cardBg
                        x: window.s(6)
                        y: window.s(6)
                        width: parent.width - window.s(12)
                        height: parent.height - window.s(12)

                        radius: window.s(10)

                        color: delegateRoot.isCurrent
                            ? window.mauve
                            : (ma.containsMouse
                                ? Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.65)
                                : Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.32))
                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutSine } }

                        border.width: 1
                        border.color: delegateRoot.isCurrent ? "transparent" : Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.5)

                        Rectangle {
                            z: 3
                            anchors.fill: parent
                            radius: window.s(10)
                            color: "transparent"
                            border.color: window.mauve
                            border.width: window.s(2)
                            visible: window.isSelected(model.id)
                        }

                        Rectangle {
                            z: 2
                            x: window.s(8)
                            y: window.s(8)
                            width: window.s(20)
                            height: window.s(20)
                            radius: window.s(6)

                            color: delegateRoot.isCurrent ? Qt.rgba(window.base.r, window.base.g, window.base.b, 0.75) : Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.9)

                            Text {
                                anchors.centerIn: parent
                                text: (index + 1)
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(10)
                                font.weight: Font.Bold
                                color: delegateRoot.isCurrent ? window.mauve : window.subtext0
                            }
                        }

                        Row {
                            z: 4
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: window.s(6)
                            spacing: window.s(4)
                            opacity: (ma.containsMouse || window.isPinned(model.id)) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Rectangle {
                                width: window.s(20)
                                height: window.s(20)
                                radius: window.s(6)
                                color: window.isPinned(model.id) ? Qt.rgba(window.base.r, window.base.g, window.base.b, 0.75) : Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.9)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐃"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(11)
                                    color: window.isPinned(model.id) ? window.mauve : window.subtext0
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: window.togglePin(model.id)
                                }
                            }

                            Rectangle {
                                width: window.s(20)
                                height: window.s(20)
                                radius: window.s(6)
                                color: Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.9)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(11)
                                    color: window.subtext0
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: window.deleteIds([model.id])
                                }
                            }
                        }

                        Text {
                            z: 2
                            visible: model.type === "text" && model.subtype === "url"
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: window.s(8)
                            text: "󰌷"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: window.s(13)
                            color: delegateRoot.isCurrent ? window.base : window.blue
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: window.s(5)
                            visible: model.type === "image"
                            color: "transparent"
                            radius: window.s(7)
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: model.type === "image" ? "file://" + model.content : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: true
                                smooth: true
                                mipmap: true
                            }
                        }

                        Item {
                            anchors.fill: parent
                            anchors.margins: window.s(12)
                            anchors.topMargin: window.s(36)
                            visible: model.type === "text"
                            clip: true

                            Rectangle {
                                id: colorSwatch
                                visible: model.subtype === "color"
                                width: window.s(24)
                                height: window.s(24)
                                radius: window.s(6)
                                border.color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.2)
                                border.width: 1
                                color: model.subtype === "color" ? model.content : "transparent"
                            }

                            Text {
                                id: cardText
                                anchors.top: model.subtype === "color" ? colorSwatch.bottom : parent.top
                                anchors.topMargin: model.subtype === "color" ? window.s(6) : 0
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                text: model.content
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(13)
                                font.weight: delegateRoot.isCurrent ? Font.DemiBold : Font.Medium
                                color: delegateRoot.isCurrent ? window.base : window.text
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignTop
                                maximumLineCount: model.subtype === "color" ? 2 : 4

                                property real textShift: delegateRoot.isCurrent ? window.s(4) : 0
                                transform: Translate { x: cardText.textShift }
                                Behavior on textShift { NumberAnimation { duration: 450; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: !window.previewMode
                            enabled: !window.previewMode
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                window.navDuration = 250;
                                clipList.currentIndex = index;

                                if (mouse.modifiers & Qt.ControlModifier) {
                                    window.toggleSelect(model.id);
                                } else if (mouse.button === Qt.RightButton) {
                                    window.previewMode = true;
                                    window.updatePreviewText();
                                } else {
                                    copyToClipboard(model.id);
                                }
                            }
                        }
                    }
                }
            }

            // FULL SCREEN PREVIEW OVERLAY
            Rectangle {
                id: previewMorph
                z: 100

                property var curItem: clipList.currentIndex >= 0 && clipModel.count > 0 ? clipModel.get(clipList.currentIndex) : null
                property int curIdx: clipList.currentIndex !== -1 ? clipList.currentIndex : 0

                property real gridX: window.s(12)
                property real gridY: 0
                property real gridW: gridArea.width - window.s(24)
                property real gridH: gridArea.height

                property real startX: gridX + (curIdx % mainBg.cols) * clipList.cellWidth + window.s(6)
                property real startY: gridY + Math.floor(curIdx / mainBg.cols) * clipList.cellHeight - clipList.contentY + window.s(6)
                property real startW: clipList.cellWidth - window.s(12)
                property real startH: clipList.cellHeight - window.s(12)

                color: window.crust
                border.color: window.mauve
                border.width: window.previewMode ? window.s(2) : 0
                Behavior on border.width { NumberAnimation { duration: 150 } }
                clip: true

                Image {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: window.s(20)

                    source: (previewMorph.curItem && previewMorph.curItem.type === "image") ? "file://" + previewMorph.curItem.content : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: previewMorph.curItem && previewMorph.curItem.type === "image"

                    opacity: window.previewMode ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Column {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: window.s(24)
                    spacing: window.s(14)
                    visible: previewMorph.curItem && previewMorph.curItem.type === "text" && previewMorph.curItem.subtype === "color"
                    opacity: window.previewMode ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        width: parent.width
                        height: window.s(90)
                        radius: window.s(12)
                        border.color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.15)
                        border.width: 1
                        color: previewMorph.curItem ? previewMorph.curItem.content : "transparent"
                    }

                    Text {
                        text: previewMorph.curItem ? previewMorph.curItem.content : ""
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(20)
                        font.weight: Font.Bold
                        color: window.text
                    }
                }

                Flickable {
                    id: textPreviewFlickable
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: window.s(20)

                    contentWidth: width
                    contentHeight: textPreviewContent.paintedHeight
                    clip: true

                    Behavior on contentY { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    visible: previewMorph.curItem && previewMorph.curItem.type === "text" && previewMorph.curItem.subtype !== "color"
                    opacity: window.previewMode ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    TextEdit {
                        id: textPreviewContent
                        width: parent.width

                        text: {
                            if (!window.previewMode || !previewMorph.curItem || previewMorph.curItem.type !== "text") return "";

                            if (window.fullTextPreview !== "") {
                                if (!window.previewAnimationDone && window.fullTextPreview.length > 3000) {
                                    return window.fullTextPreview.substring(0, 3000);
                                }
                                return window.fullTextPreview;
                            }

                            return previewMorph.curItem.content;
                        }

                        color: window.text
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(14)
                        wrapMode: TextEdit.Wrap
                        readOnly: true
                        selectByMouse: true
                        selectionColor: window.surface2
                        selectedTextColor: window.mauve
                        visible: !window.previewEditMode
                    }

                    // Editable overlay: recreated fresh each time edit mode is entered,
                    // discarded (edits lost) when toggled off without committing.
                    Loader {
                        id: editLoader
                        width: parent.width
                        active: window.previewEditMode
                        visible: active

                        sourceComponent: TextEdit {
                            width: editLoader.width
                            color: window.text
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(14)
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            selectionColor: window.surface2
                            selectedTextColor: window.mauve

                            Component.onCompleted: {
                                text = textPreviewContent.text;
                                forceActiveFocus();
                                cursorPosition = text.length;
                            }

                            Keys.onEscapePressed: {
                                window.previewEditMode = false;
                                searchInput.forceActiveFocus();
                                event.accepted = true;
                            }

                            Keys.onPressed: (event) => {
                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                                    window.copyEditedText(text);
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }

                Row {
                    z: 10
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: window.s(10)
                    spacing: window.s(6)
                    visible: window.previewMode && previewMorph.curItem && previewMorph.curItem.type === "text"
                    opacity: window.previewAnimationDone ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        width: window.s(28)
                        height: window.s(28)
                        radius: window.s(8)
                        color: window.previewEditMode ? window.mauve : Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.85)

                        Text {
                            anchors.centerIn: parent
                            text: "󰏫"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: window.s(14)
                            color: window.previewEditMode ? window.base : window.subtext0
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                window.previewEditMode = !window.previewEditMode;
                                if (!window.previewEditMode) {
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                states: [
                    State {
                        name: "hidden"
                        when: !window.previewMode
                        PropertyChanges {
                            target: previewMorph
                            opacity: 0
                            x: previewMorph.startX
                            y: previewMorph.startY
                            width: previewMorph.startW
                            height: previewMorph.startH
                            radius: window.s(10)
                        }
                    },
                    State {
                        name: "visible"
                        when: window.previewMode
                        PropertyChanges {
                            target: previewMorph
                            opacity: 1
                            x: previewMorph.gridX
                            y: previewMorph.gridY
                            width: previewMorph.gridW
                            height: previewMorph.gridH
                            radius: window.s(14)
                        }
                    }
                ]

                transitions: [
                    Transition {
                        from: "hidden"; to: "visible"
                        SequentialAnimation {
                            ParallelAnimation {
                                NumberAnimation { target: previewMorph; property: "opacity"; duration: 50 }
                                NumberAnimation { properties: "x,y,width,height,radius"; duration: 300; easing.type: Easing.OutExpo }
                            }
                            ScriptAction { script: { window.previewAnimationDone = true; } }
                        }
                    },
                    Transition {
                        from: "visible"; to: "hidden"
                        ParallelAnimation {
                            NumberAnimation { properties: "x,y,width,height,radius"; duration: 250; easing.type: Easing.OutExpo }
                            SequentialAnimation {
                                PauseAnimation { duration: 150 }
                                NumberAnimation { target: previewMorph; property: "opacity"; to: 0; duration: 100 }
                            }
                        }
                    }
                ]
            }
        }

        // ---------------------------------------------------------------
        // HINT BAR: keycap legend, contextual
        // ---------------------------------------------------------------
        Rectangle {
            id: hintBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: mainBg.hintBarH
            color: Qt.rgba(window.crust.r, window.crust.g, window.crust.b, 0.5)

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.6)
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: window.s(18)
                spacing: window.s(14)

                Repeater {
                    model: window.currentHints()

                    Row {
                        spacing: window.s(6)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: keycapText.implicitWidth + window.s(10)
                            height: window.s(18)
                            radius: window.s(5)
                            color: window.surface0
                            border.color: window.surface2
                            border.width: 1

                            Text {
                                id: keycapText
                                anchors.centerIn: parent
                                text: modelData.k
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(10)
                                font.weight: Font.Bold
                                color: window.text
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.l
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: window.s(11)
                            color: window.subtext0
                        }
                    }
                }
            }
        }
    }
}
