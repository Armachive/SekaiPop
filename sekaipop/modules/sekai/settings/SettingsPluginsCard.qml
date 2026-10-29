import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/PluginRepos.js" as PR

// Settings > Desktop > Plugins (docs/PLUGIN-SETTINGS.md): every desktop widget plugin that
// is installed, the folders that did not load and why, and each plugin's settings, edited
// with the shell's own controls. Changes apply at once: the widget is bound to its settings.
//
// A selected plugin widget's Settings key in Edit Desktop opens this card with that plugin
// already open (PluginService.settingsTarget).
SectionCard {
    id: card

    // The SettingsPage it is on (for scrolling to an open plugin, and its host's requests).
    property var settingsPage: null

    // The plugin whose settings are open, or "". One at a time.
    property string openId: ""

    readonly property bool empty: PluginService.scanned && PluginService.found.length === 0 && PluginService.skipped.length === 0

    title: "Plugins"
    icon: "extension"

    function toggle(id) {
        card.openId = card.openId === id ? "" : id
    }

    function skipAction(action, id) {
        if (action === "update")
            UpdateService.check(true)
        else
            PluginService.openFolder(id)
    }

    // About / Update, scrolled to its Plugins card (an update is there, not here).
    function goAbout() {
        const f = card.settingsPage ? card.settingsPage.host : null
        if (!f || !f.pages)
            return
        PluginRepoService.aboutTarget = "plugins"
        for (let i = 0; i < f.pages.length; i++)
            if (f.pages[i].id === "about")
                f.go(i)
    }

    function placeIt() {
        if (card.settingsPage && card.settingsPage.host)
            card.settingsPage.host.desktopEditRequested()
    }

    // Edit Desktop asked for a plugin: open it and bring it into view once this page shows.
    function takeTarget() {
        const id = PluginService.settingsTarget
        if (id === "" || !card.visible || !PluginService.stateFor(id))
            return
        PluginService.settingsTarget = ""
        card.openId = id
        Qt.callLater(() => {
            const it = rowsRepeater.itemAt(PluginService.found.findIndex(f => f.plugin.id === id))
            if (it && card.settingsPage)
                card.settingsPage.scrollToItem(it)
        })
    }

    Connections {
        target: PluginService
        function onSettingsTargetChanged() { card.takeTarget() }
    }
    onVisibleChanged: if (visible) Qt.callLater(card.takeTarget)
    Component.onCompleted: Qt.callLater(card.takeTarget)

    // ===== no plugins yet =====
    Column {
        visible: card.empty
        width: card.innerWidth
        spacing: 12

        Text {
            text: "No plugins yet"
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 24
            font.weight: Font.Black
        }

        Paragraph {
            text: "Get one from About › Update › Get plugins, which installs it for you. Or put a plugin's folder here yourself (one with a plugin.json), then press Reload:"
        }

        Rectangle {
            width: dirText.implicitWidth + 36
            height: 40
            radius: 20
            color: mt.pSurfaceDivider

            Text {
                id: dirText
                anchors.centerIn: parent
                text: "~/.config/sekaipop/plugins/"
                color: mt.pInk
                font.family: "monospace"
                font.pixelSize: 16
            }
        }

        Paragraph {
            sub: true
            text: "The folder's name is the plugin's id. A folder you put here yourself is never updated or removed by the shell, and no restart is needed."
        }
    }

    SettingAction {
        visible: card.empty
        icon: "refresh"
        label: "Reload"
        detail: "Look in the folder again"
        onActivated: PluginService.rescan()
    }

    SettingAction {
        visible: card.empty
        icon: "folder_open"
        label: "Open the folder"
        detail: "Makes it if missing"
        onActivated: PluginService.openFolder("")
    }

    SettingAction {
        visible: card.empty
        icon: "menu_book"
        label: "How plugins work"
        detail: "docs/PLUGINS.md"
        onActivated: Qt.openUrlExternally("https://github.com/Blapples/SekaiPop/blob/main/docs/PLUGINS.md")
    }

    // ===== the list =====
    Item {
        visible: !card.empty
        width: card.innerWidth
        height: Math.max(intro.implicitHeight, heads.height)

        Column {
            id: intro
            width: parent.width - heads.width - 24
            spacing: 4

            Paragraph {
                text: "Widgets that live in their own folder, written by someone else or by you. Open one to change its settings: the widget redraws as you go."
            }

            Paragraph {
                sub: true
                text: "Read from ~/.config/sekaipop/plugins/. Place them in Edit Desktop, like the widgets above. Getting, updating and removing them is in About › Update."
            }

            Row {
                visible: PluginRepoService.updates.length > 0
                topPadding: 6
                spacing: 12

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 19
                    name: "new_releases"
                    color: mt.pInk
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: PR.updatesTitle(PluginRepoService.updates.length)
                    color: mt.pInk
                    font.family: mt.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.ExtraBold
                }

                SettingChip {
                    capH: 36
                    fontSize: 14
                    label: "Update in About"
                    icon: "update"
                    onClicked: card.goAbout()
                }
            }
        }

        Row {
            id: heads
            x: parent.width - width
            spacing: 12

            SettingChip {
                label: "Reload"
                icon: "refresh"
                onClicked: PluginService.rescan()
            }

            SettingChip {
                label: "Open the folder"
                icon: "folder_open"
                onClicked: PluginService.openFolder("")
            }
        }
    }

    Column {
        visible: !card.empty
        width: card.innerWidth
        spacing: 10

        Repeater {
            id: rowsRepeater
            model: PluginService.found

            delegate: Loader {
                id: slot
                required property var modelData
                readonly property var pst: PluginService.states[modelData.plugin.id] ?? null
                readonly property bool open: card.openId === modelData.plugin.id && pst !== null

                width: card.innerWidth
                active: pst !== null
                sourceComponent: open ? editorC : rowC

                Component {
                    id: rowC

                    PluginRow {
                        width: card.innerWidth
                        pst: slot.pst
                        onOpenRequested: card.toggle(slot.modelData.plugin.id)
                        onAboutRequested: card.goAbout()
                    }
                }

                Component {
                    id: editorC

                    PluginEditor {
                        width: card.innerWidth
                        pst: slot.pst
                        onCloseRequested: card.openId = ""
                        onPlaceRequested: card.placeIt()
                    }
                }
            }
        }

        Repeater {
            model: PluginService.skipped

            delegate: PluginRow {
                required property var modelData
                width: card.innerWidth
                skip: modelData
                onActionRequested: action => card.skipAction(action, modelData.id)
            }
        }
    }

    // ===== said once, quietly =====
    Item {
        width: card.innerWidth
        height: 22 + 16 + trust.implicitHeight

        Row {
            y: 22
            spacing: 5
            Repeater {
                model: Math.max(0, Math.floor(card.innerWidth / 11))
                delegate: Rectangle { width: 6; height: 2.5; color: mt.pSurfaceDivider }
            }
        }

        Row {
            id: trustRow
            y: 22 + 16
            width: parent.width
            spacing: 10

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 18
                name: "shield"
                color: mt.pInkSub
            }

            Text {
                id: trust
                width: trustRow.width - 28
                text: "A plugin runs with the shell's full rights: it can run programs and read your files. Keep the ones you'd trust as a script of your own."
                wrapMode: Text.WordWrap
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }
    }

    component Paragraph: Text {
        readonly property var mt: Theme.of(QsWindow.window)
        property bool sub: false
        width: parent ? parent.width : 400
        wrapMode: Text.WordWrap
        lineHeight: 1.12
        color: sub ? mt.pInkSub : mt.pInk
        font.family: mt.fontFamily
        font.pixelSize: 17
        font.weight: Font.Bold
    }
}
