import QtQuick
import "../core"

// One app, full page: icon/name/developer, a source tab switcher, screenshots,
// description, version history and license — the GNOME Software detail layout.
Item {
    id: root

    property var entry: ({})
    property string armedPackage: ""

    signal installRequested(string packageName, string source, string name)
    signal removeRequested(string packageName, string name)
    signal back()

    readonly property var detail: DepotMock.detailFor(root.entry.id || "")
    readonly property var sources: DepotMock.sourcesFor(root.entry)
    property int sourceIndex: 0
    readonly property var activeSource: root.sources.length > 0 ? root.sources[root.sourceIndex] : null
    readonly property bool activeSourceIsMock: root.activeSource !== null && root.activeSource.id === "flathub"
    readonly property string packageName: root.activeSource ? root.activeSource.packageName : ""
    readonly property bool installed: root.entry.installed === true && !root.activeSourceIsMock
    readonly property bool rowBusy: DepotBackend.busyPackage !== "" && DepotBackend.busyPackage === root.packageName
    readonly property bool armed: root.armedPackage !== "" && root.armedPackage === root.packageName

    onEntryChanged: root.sourceIndex = 0
    onInstalledChanged: if (root.installed) stamp.play()

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: root.width
        spacing: 26

        Row {
            spacing: 6

            Text {
                text: "‹ " + DepotStrings.t("back")
                color: backMouse.containsMouse ? DepotTheme.text : DepotTheme.subtext0
                font.family: DepotTheme.sans
                font.pixelSize: 13
                font.weight: Font.Medium

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }
        }

        Row {
            width: parent.width
            spacing: 20

            Item {
                width: 84
                height: 84

                DepotAppIcon {
                    size: 84
                    iconName: root.entry.icon || root.packageName
                    label: root.entry.name || ""
                }

                DepotSealStamp {
                    id: stamp
                    size: 34
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -4
                }
            }

            Column {
                width: parent.width - 84 - 20
                spacing: 6

                Text {
                    text: root.entry.name || ""
                    color: DepotTheme.text
                    font.family: DepotTheme.display
                    font.pixelSize: 26
                    font.weight: Font.ExtraBold
                }

                Text {
                    visible: root.detail.developer !== ""
                    text: root.detail.developer
                    color: DepotTheme.subtext0
                    font.family: DepotTheme.sans
                    font.pixelSize: 13
                }

                Row {
                    spacing: 6
                    topPadding: 4

                    Repeater {
                        model: root.sources

                        Rectangle {
                            id: sourceTab
                            required property var modelData
                            required property int index
                            readonly property bool active: index === root.sourceIndex
                            width: sourceLabel.implicitWidth + 22
                            height: 26
                            radius: 13
                            color: active ? DepotTheme.primary : "transparent"
                            border.width: 1
                            border.color: active ? DepotTheme.primary : DepotTheme.line

                            Text {
                                id: sourceLabel
                                anchors.centerIn: parent
                                text: sourceTab.modelData.label
                                color: sourceTab.active ? DepotTheme.primaryInk : DepotTheme.subtext0
                                font.family: DepotTheme.sans
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sourceIndex = sourceTab.index
                            }
                        }
                    }
                }
            }

            Item {
                width: 140
                height: 32
                anchors.top: parent.top
                anchors.topMargin: 4

                DepotButton {
                    anchors.fill: parent
                    enabled: root.packageName !== "" && !root.activeSourceIsMock && (!DepotBackend.busy || root.rowBusy)
                    busy: root.rowBusy
                    variant: root.armed ? "danger" : (root.installed ? "outline" : "filled")
                    text: {
                        if (root.activeSourceIsMock) return DepotStrings.t("install");
                        if (root.rowBusy) return DepotStrings.t(DepotBackend.busyAction === "remove" ? "removing" : "installing");
                        if (root.armed) return DepotStrings.t("confirmRemove");
                        return DepotStrings.t(root.installed ? "remove" : "install");
                    }
                    onClicked: {
                        if (root.installed) root.removeRequested(root.packageName, root.entry.name);
                        else root.installRequested(root.packageName, root.activeSource.id === "aur" ? "aur" : "repo", root.entry.name);
                    }
                }
            }
        }

        DepotNotice {
            width: parent.width
            visible: root.activeSourceIsMock
            tone: "info"
            text: DepotStrings.t("mockNotice")
        }

        Column {
            width: parent.width
            spacing: 10
            visible: root.detail.shots > 0

            Text {
                text: DepotStrings.t("screenshots").toUpperCase()
                color: DepotTheme.overlay0
                font.family: DepotTheme.mono
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 1.4
            }

            ListView {
                width: parent.width
                height: 200
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.detail.shots

                delegate: Rectangle {
                    required property int index
                    width: 320
                    height: 200
                    radius: DepotTheme.radiusMedium
                    color: DepotTheme.surface0
                    border.width: 1
                    border.color: DepotTheme.line

                    Text {
                        anchors.centerIn: parent
                        text: DepotStrings.t("screenshotPlaceholder").arg(index + 1)
                        color: DepotTheme.overlay0
                        font.family: DepotTheme.sans
                        font.pixelSize: 13
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 8

            Text {
                text: DepotStrings.t("description").toUpperCase()
                color: DepotTheme.overlay0
                font.family: DepotTheme.mono
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 1.4
            }

            Text {
                width: parent.width
                text: DepotStrings.pick(root.entry.description)
                color: DepotTheme.text
                font.family: DepotTheme.sans
                font.pixelSize: 14
                wrapMode: Text.Wrap
            }

            Row {
                topPadding: 4
                spacing: 6

                Repeater {
                    model: root.detail.tags || []

                    DepotSourceBadge {
                        required property string modelData
                        label: modelData
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 8
            visible: root.activeSourceIsMock || root.activeSource && root.activeSource.id !== "aur"

            Text {
                text: DepotStrings.t("versionHistory").toUpperCase()
                color: DepotTheme.overlay0
                font.family: DepotTheme.mono
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 1.4
            }

            Repeater {
                model: DepotMock.historyFor(root.entry.id || "")

                Row {
                    required property var modelData
                    width: parent.width
                    spacing: 12

                    Text {
                        width: 70
                        text: modelData.version
                        color: DepotTheme.text
                        font.family: DepotTheme.mono
                        font.pixelSize: 12
                    }
                    Text {
                        width: 90
                        text: modelData.date
                        color: DepotTheme.subtext0
                        font.family: DepotTheme.mono
                        font.pixelSize: 12
                    }
                    Text {
                        text: modelData.sha
                        color: DepotTheme.overlay0
                        font.family: DepotTheme.mono
                        font.pixelSize: 12
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 24

            Column {
                spacing: 2
                Text {
                    text: DepotStrings.t("license").toUpperCase()
                    color: DepotTheme.overlay0
                    font.family: DepotTheme.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                }
                Text {
                    text: root.detail.license || "—"
                    color: DepotTheme.text
                    font.family: DepotTheme.sans
                    font.pixelSize: 13
                }
            }
        }
    }
}
