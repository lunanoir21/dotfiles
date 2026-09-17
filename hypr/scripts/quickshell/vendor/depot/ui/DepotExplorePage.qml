import QtQuick
import "../core"

// GNOME Software's "Explore": a hero strip of editor's picks, then a few
// horizontally scrolling carousels grouped by theme.
Column {
    id: root

    signal opened(var entry)

    property var byId: {
        let map = ({});
        for (let e of DepotBackend.featured) map[e.id] = e;
        return map;
    }

    function pick(ids) {
        return ids.map(id => root.byId[id]).filter(e => e !== undefined);
    }

    spacing: 30

    Column {
        width: parent.width
        spacing: 10
        visible: heroList.count > 0

        Text {
            leftPadding: 2
            text: DepotStrings.t("editorsChoice").toUpperCase()
            color: DepotTheme.overlay0
            font.family: DepotTheme.mono
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 1.4
        }

        ListView {
            id: heroList
            width: parent.width
            height: 220
            orientation: ListView.Horizontal
            spacing: 14
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.pick(DepotMock.editorsPicks)

            delegate: DepotHeroCard {
                required property var modelData
                required property int index
                width: 360
                height: 220
                entry: modelData
                entranceDelay: index * 45
                onOpened: entry => root.opened(entry)
            }
        }
    }

    DepotCarousel {
        width: parent.width
        title: DepotStrings.t("popularWeek")
        entries: root.pick(DepotMock.popularWeek)
        visible: entries.length > 0
        onOpened: entry => root.opened(entry)
    }

    DepotCarousel {
        width: parent.width
        title: DepotStrings.t("newAndUpdated")
        entries: root.pick(DepotMock.newAndUpdated)
        visible: entries.length > 0
        onOpened: entry => root.opened(entry)
    }

    Repeater {
        model: ["internet", "communication", "office", "development", "media", "system"]

        DepotCarousel {
            required property string modelData
            width: root.width
            title: DepotStrings.t(modelData)
            entries: DepotBackend.featured.filter(e => e.category === modelData)
            visible: entries.length > 0
            onOpened: entry => root.opened(entry)
        }
    }
}
