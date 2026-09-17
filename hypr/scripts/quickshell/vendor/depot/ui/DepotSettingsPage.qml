import QtQuick
import "../core"

// Theme, language, and a read-out of what Depot detected on this system.
// Flathub remote management is a mock toggle until the C++ backend lands.
Column {
    id: root

    property bool flathubMock: true

    spacing: 30

    Column {
        width: parent.width
        spacing: 12

        Text {
            text: DepotStrings.t("settingsAppearance").toUpperCase()
            color: DepotTheme.overlay0
            font.family: DepotTheme.mono
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 1.4
        }

        Row {
            width: parent.width
            height: 32

            Text {
                width: 160
                anchors.verticalCenter: parent.verticalCenter
                text: DepotStrings.t("settingsTheme")
                color: DepotTheme.text
                font.family: DepotTheme.sans
                font.pixelSize: 14
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: DepotStore.themes

                    Rectangle {
                        id: themeOpt
                        required property string modelData
                        readonly property bool active: modelData === DepotStore.theme
                        readonly property var labels: ({ black: "themeBlack", white: "themeWhite", auto: "themeAuto" })
                        width: optLabel.implicitWidth + 20
                        height: 26
                        radius: 13
                        color: active ? DepotTheme.primary : "transparent"
                        border.width: 1
                        border.color: active ? DepotTheme.primary : DepotTheme.line

                        Text {
                            id: optLabel
                            anchors.centerIn: parent
                            text: DepotStrings.t(themeOpt.labels[themeOpt.modelData] || "themeAuto")
                            color: themeOpt.active ? DepotTheme.primaryInk : DepotTheme.subtext0
                            font.family: DepotTheme.sans
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DepotStore.setOption("appearance.theme", themeOpt.modelData)
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 32

            Text {
                width: 160
                anchors.verticalCenter: parent.verticalCenter
                text: DepotStrings.t("settingsLanguage")
                color: DepotTheme.text
                font.family: DepotTheme.sans
                font.pixelSize: 14
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: DepotStore.languages

                    Rectangle {
                        id: langOpt
                        required property string modelData
                        readonly property bool active: modelData === DepotStore.language
                        width: langLabel.implicitWidth + 20
                        height: 26
                        radius: 13
                        color: active ? DepotTheme.primary : "transparent"
                        border.width: 1
                        border.color: active ? DepotTheme.primary : DepotTheme.line

                        Text {
                            id: langLabel
                            anchors.centerIn: parent
                            text: langOpt.modelData === "auto" ? DepotStrings.t("settingsLanguageAuto") : langOpt.modelData.toUpperCase()
                            color: langOpt.active ? DepotTheme.primaryInk : DepotTheme.subtext0
                            font.family: DepotTheme.sans
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DepotStore.setOption("appearance.language", langOpt.modelData)
                        }
                    }
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 10

        Text {
            text: DepotStrings.t("settingsSystem").toUpperCase()
            color: DepotTheme.overlay0
            font.family: DepotTheme.mono
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 1.4
        }

        Repeater {
            model: [
                { label: "settingsPackageManager", value: DepotBackend.info.backend || "—", ok: DepotBackend.info.backend !== "" },
                { label: "settingsAurHelper", value: DepotBackend.info.aurHelper || "—", ok: DepotBackend.info.aurHelper !== "" },
                { label: "settingsPolkitAgent", value: DepotBackend.info.polkitAgent ? DepotStrings.t("statusOk") : DepotStrings.t("statusMissing"), ok: DepotBackend.info.polkitAgent === true }
            ]

            Row {
                id: statusRow
                required property var modelData
                width: parent.width
                height: 28
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: statusRow.modelData.ok ? DepotTheme.accent : DepotTheme.overlay0
                }

                Text {
                    width: 160
                    anchors.verticalCenter: parent.verticalCenter
                    text: DepotStrings.t(statusRow.modelData.label)
                    color: DepotTheme.text
                    font.family: DepotTheme.sans
                    font.pixelSize: 14
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: statusRow.modelData.value
                    color: DepotTheme.subtext0
                    font.family: DepotTheme.mono
                    font.pixelSize: 13
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 10

        Text {
            text: DepotStrings.t("settingsFlathub").toUpperCase()
            color: DepotTheme.overlay0
            font.family: DepotTheme.mono
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 1.4
        }

        Row {
            width: parent.width
            height: 32
            spacing: 12

            Rectangle {
                id: toggle
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 22
                radius: 11
                color: root.flathubMock ? DepotTheme.primary : DepotTheme.surface1
                border.width: 1
                border.color: DepotTheme.line

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.flathubMock ? parent.width - width - 3 : 3
                    color: root.flathubMock ? DepotTheme.primaryInk : DepotTheme.subtext0

                    Behavior on x { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.flathubMock = !root.flathubMock
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "flathub"
                color: DepotTheme.text
                font.family: DepotTheme.mono
                font.pixelSize: 13
            }
        }

        Text {
            width: parent.width
            text: DepotStrings.t("settingsFlathubHint")
            color: DepotTheme.overlay0
            font.family: DepotTheme.sans
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }
}
