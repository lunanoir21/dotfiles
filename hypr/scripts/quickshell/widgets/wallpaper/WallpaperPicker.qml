import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../core"

Item {
    id: window
    width: Screen.width
    height: parent ? parent.height : Screen.height
    focus: true

    Caching { id: paths }

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: theme }

    // Loader-shared properties from Main.qml
    property var notifModel
    property var liveNotifs
    property real layoutWidth: 0
    property real layoutHeight: 0
    property string widgetArg: ""

    // -------------------------------------------------------------------------
    // STATE & DATA
    // -------------------------------------------------------------------------
    readonly property string srcDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string appliedStateFile: paths.getStateDir("wallpaper_picker") + "/applied"

    property var allWallpapers: []
    property string appliedFile: ""
    property var selectedItem: null
    property int selectedIndex: 0

    readonly property var transitions: ["fade", "wipe", "grow", "wave", "outer"]

    function isVideoFile(name) {
        return /\\.(mp4|mkv|mov|webm)$/i.test(name || "");
    }

    Component.onCompleted: {
        appliedReader.running = true;
        refreshWallpapers();
    }

    onVisibleChanged: {
        if (visible) {
            appliedReader.running = true;
            refreshWallpapers();
            window.forceActiveFocus();
            topDownAnim.restart();
        }
    }

    // -------------------------------------------------------------------------
    // DATA FETCHERS & PROCESSES
    // -------------------------------------------------------------------------
    Process {
        id: appliedReader
        command: ["cat", window.appliedStateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = this.text.trim();
                if (name !== "") {
                    window.appliedFile = name;
                }
            }
        }
    }

    Process {
        id: wallpaperFetcher
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/widgets/wallpaper/wallpaper_fetcher.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim() !== "") {
                        window.allWallpapers = JSON.parse(this.text);
                        window.populateModel();

                        if (window.allWallpapers.length > 0) {
                            let matchIdx = window.allWallpapers.findIndex(w => w.fileName === window.appliedFile);
                            window.selectedIndex = matchIdx >= 0 ? matchIdx : 0;
                            window.selectedItem = window.allWallpapers[window.selectedIndex];
                        }
                    }
                } catch(e) {
                    console.log("Error parsing wallpaper list:", e);
                }
            }
        }
    }

    function refreshWallpapers() {
        wallpaperFetcher.running = true;
    }

    // -------------------------------------------------------------------------
    // MODEL
    // -------------------------------------------------------------------------
    ListModel {
        id: displayModel
    }

    function populateModel() {
        displayModel.clear();
        for (let i = 0; i < window.allWallpapers.length; i++) {
            let item = window.allWallpapers[i];
            displayModel.append({
                "fileName": item.fileName,
                "filePath": item.filePath,
                "fileType": item.fileType,
                "extension": item.extension,
                "size": item.size,
                "mtime": item.mtime
            });
        }

        if (displayModel.count > 0) {
            window.selectedIndex = Math.min(window.selectedIndex, displayModel.count - 1);
            if (window.selectedIndex < 0) window.selectedIndex = 0;
            window.selectedItem = displayModel.get(window.selectedIndex);
        } else {
            window.selectedItem = null;
        }
    }

    // -------------------------------------------------------------------------
    // WALLPAPER ENGINE
    // -------------------------------------------------------------------------
    function themeApplySnippet(wallpaperPathExpr) {
        return `
            THEME_JSON="$HOME/.config/hypr/theme.json"
            THEME_PRESET=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('preset',''))" "$THEME_JSON" 2>/dev/null)
            if [ "$THEME_PRESET" = "dynamic" ]; then
                THEME_BASE=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('base','') or 'dark')" "$THEME_JSON" 2>/dev/null)
                [ -z "$THEME_BASE" ] && THEME_BASE="dark"
                python3 "$HOME/.config/hypr/theme-engine/apply_theme.py" dynamic --wallpaper "${wallpaperPathExpr}" --base "$THEME_BASE" --push || true
            fi
        `;
    }

    function applyWallpaper(item) {
        if (!item || !item.fileName) return;
        window.appliedFile = item.fileName;
        window.selectedItem = item;

        const escapeBash = (str) => String(str).replace(/(["\\$`])/g, "\\$1");
        const filePath = item.filePath;
        const escPath = escapeBash(filePath);
        const randomTransition = window.transitions[Math.floor(Math.random() * window.transitions.length)];
        const logFile = paths.logDir + "/wallpaper_apply.log";

        const cacheImg = paths.getCacheDir("wallpaper_picker") + "/current_wallpaper.png";

        let setCmd;
        if (item.fileType === "video" || window.isVideoFile(item.fileName)) {
            setCmd = `
                pkill mpvpaper || true
                mpvpaper -o 'loop --no-audio --hwdec=auto --profile=high-quality --video-sync=display-resample' '*' "${escPath}" >> ${logFile} 2>&1 &
            `;
        } else {
            setCmd = `
                pkill mpvpaper || true
                awww img "${escPath}" --transition-type ${randomTransition} --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1 >> ${logFile} 2>&1 &
                cp "${escPath}" "${cacheImg}"
            `;
        }

        const fullScript = `
            mkdir -p "${paths.getStateDir("wallpaper_picker")}"
            echo -n "${escapeBash(item.fileName)}" > "${window.appliedStateFile}"
            ${setCmd}
            ( ${window.themeApplySnippet(escPath)} ) &
        `;
        Quickshell.execDetached(["bash", "-c", fullScript]);
    }

    function closePicker() {
        Quickshell.execDetached(["bash", "-c", "quickshell -p " + Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/Shell.qml ipc call main handleCommand 'close' '' '' >/dev/null 2>&1 || true"]);
    }

    // -------------------------------------------------------------------------
    // KEYBOARD NAVIGATION
    // -------------------------------------------------------------------------
    Keys.onEscapePressed: window.closePicker()

    Keys.onReturnPressed: {
        if (window.selectedItem) {
            window.applyWallpaper(window.selectedItem);
        }
    }

    Keys.onSpacePressed: {
        if (window.selectedItem) {
            window.applyWallpaper(window.selectedItem);
        }
    }

    Keys.onLeftPressed: {
        if (window.selectedIndex > 0) {
            window.selectedIndex--;
            window.selectedItem = displayModel.get(window.selectedIndex);
            wallGrid.positionViewAtIndex(window.selectedIndex, GridView.Contain);
        }
    }

    Keys.onRightPressed: {
        if (window.selectedIndex < displayModel.count - 1) {
            window.selectedIndex++;
            window.selectedItem = displayModel.get(window.selectedIndex);
            wallGrid.positionViewAtIndex(window.selectedIndex, GridView.Contain);
        }
    }

    Keys.onUpPressed: {
        let cols = wallGrid.columns;
        if (window.selectedIndex - cols >= 0) {
            window.selectedIndex -= cols;
            window.selectedItem = displayModel.get(window.selectedIndex);
            wallGrid.positionViewAtIndex(window.selectedIndex, GridView.Contain);
        }
    }

    Keys.onDownPressed: {
        let cols = wallGrid.columns;
        if (window.selectedIndex + cols < displayModel.count) {
            window.selectedIndex += cols;
            window.selectedItem = displayModel.get(window.selectedIndex);
            wallGrid.positionViewAtIndex(window.selectedIndex, GridView.Contain);
        }
    }

    // -------------------------------------------------------------------------
    // TOP-DOWN ENTRANCE ANIMATION
    // -------------------------------------------------------------------------
    ParallelAnimation {
        id: topDownAnim
        running: true

        NumberAnimation {
            target: modalHub
            property: "y"
            from: -s(40)
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: modalHub
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // -------------------------------------------------------------------------
    // PURE WALLPAPERS GRID (SIFIR FAZLALIK, SADECE RESİMLER)
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent

        // Click outside to close
        MouseArea {
            anchors.fill: parent
            onClicked: window.closePicker()
        }

        Rectangle {
            id: modalHub
            width: Math.min(s(920), parent.width - s(32))
            height: Math.min(s(600), parent.height - s(20))
            anchors.centerIn: parent
            radius: s(20)
            color: Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.95)
            border.width: Math.max(1, s(1))
            border.color: Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.35)
            clip: true

            // Stop click propagation
            MouseArea { anchors.fill: parent }

            // Empty State
            ColumnLayout {
                anchors.centerIn: parent
                spacing: s(10)
                visible: displayModel.count === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "🖼️"
                    font.pixelSize: s(40)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No wallpapers found in ~/Pictures/Wallpapers"
                    font.pixelSize: s(13)
                    font.weight: Font.Medium
                    color: theme.subtext0
                }
            }

            // The Wallpapers Grid
            GridView {
                id: wallGrid
                anchors.fill: parent
                anchors.margins: s(12)
                clip: true
                focus: true
                model: displayModel

                readonly property int columns: Math.max(3, Math.floor(width / s(260)))
                cellWidth: width / columns
                cellHeight: cellWidth * 0.65

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                delegate: Item {
                    id: cardDelegate
                    width: wallGrid.cellWidth
                    height: wallGrid.cellHeight

                    required property int index
                    required property string fileName
                    required property string filePath
                    required property string fileType
                    required property string extension
                    required property string size
                    required property int mtime

                    readonly property bool isApplied: window.appliedFile === cardDelegate.fileName
                    readonly property bool isSelected: window.selectedIndex === cardDelegate.index
                    property bool isHovered: cardMouse.containsMouse

                    Rectangle {
                        id: cardInner
                        anchors.fill: parent
                        anchors.margins: s(6)
                        radius: s(14)
                        color: theme.surface0
                        clip: true
                        scale: cardDelegate.isHovered ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

                        border.width: cardDelegate.isApplied ? Math.max(2, s(2.5)) : (cardDelegate.isSelected ? Math.max(2, s(2)) : (cardDelegate.isHovered ? 1.5 : 1))
                        border.color: cardDelegate.isApplied ? theme.mauve : (cardDelegate.isSelected ? theme.blue : (cardDelegate.isHovered ? Qt.rgba(theme.mauve.r, theme.mauve.g, theme.mauve.b, 0.6) : Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.2)))
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        // Wallpaper Image Thumbnail
                        Image {
                            anchors.fill: parent
                            source: "file://" + cardDelegate.filePath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: 440
                        }

                        // Gradient Scrim on Hover
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: cardDelegate.isHovered ? Qt.rgba(0, 0, 0, 0.3) : "transparent" }
                                GradientStop { position: 0.55; color: "transparent" }
                                GradientStop { position: 1.0; color: cardDelegate.isHovered ? Qt.rgba(0, 0, 0, 0.75) : "transparent" }
                            }
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        // Video Badge (Top Right)
                        Rectangle {
                            visible: cardDelegate.fileType === "video"
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: s(8)
                            height: s(20)
                            width: s(20)
                            radius: s(5)
                            color: Qt.rgba(0, 0, 0, 0.65)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: "▶"
                                font.pixelSize: s(8)
                                color: "#ffffff"
                            }
                        }

                        // Active Tag Badge
                        Rectangle {
                            visible: cardDelegate.isApplied
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: s(8)
                            height: s(22)
                            width: activeTagText.implicitWidth + s(12)
                            radius: s(6)
                            color: theme.mauve

                            Text {
                                id: activeTagText
                                anchors.centerIn: parent
                                text: "ACTIVE ✓"
                                font.pixelSize: s(9)
                                font.weight: Font.Bold
                                color: theme.crust
                            }
                        }

                        // Hover File Name Label
                        Text {
                            visible: cardDelegate.isHovered
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: s(8)
                            text: cardDelegate.fileName
                            font.pixelSize: s(11)
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                            elide: Text.ElideMiddle
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: cardInner
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            window.selectedIndex = cardDelegate.index;
                            window.selectedItem = {
                                "fileName": cardDelegate.fileName,
                                "filePath": cardDelegate.filePath,
                                "fileType": cardDelegate.fileType,
                                "extension": cardDelegate.extension,
                                "size": cardDelegate.size,
                                "mtime": cardDelegate.mtime
                            };
                            window.applyWallpaper(window.selectedItem);
                        }
                    }
                }
            }
        }
    }
}
