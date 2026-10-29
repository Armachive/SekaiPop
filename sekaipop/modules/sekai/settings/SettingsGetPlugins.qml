import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/PluginRepos.js" as PR

// About / Update > Get plugins (docs/PLUGIN-INSTALL.md): the reviewed list (plugins.json in the
// SekaiPop repository, read before an entry goes on it), searchable, one key to install; and
// From a URL, for any other repository, read first (Look) and installed only on Install it
// anyway, with one plain sentence that nobody has read its code.
//
// An install shows git's progress, then what's next (turn the bar entry on, place the widget,
// its settings), or what went wrong. Offline, the list is the last copy and installs wait.
SectionCard {
    id: card

    // The SettingsPage it is on (its host opens Edit Desktop).
    property var settingsPage: null

    // "list" or "url".
    property string mode: "list"

    title: "Get plugins"
    icon: "storefront"

    readonly property string version: UpdateService.version
    readonly property bool offline: PluginRepoService.listStatus === "offline" || PluginRepoService.listStatus === "error"
    readonly property var results: PR.search(PluginRepoService.entries, search.text)

    property double now: Date.now()
    Timer {
        interval: 60000
        running: card.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: card.now = Date.now()
    }

    // The list is fetched when the card is first shown (not at start-up: nothing here touches
    // the network until someone opens About / Update).
    onVisibleChanged: {
        if (visible && PluginRepoService.listStatus === "idle")
            PluginRepoService.fetchList()
    }

    function installedKey(repo) {
        return !!PluginRepoService.lock.repos[repo]
    }

    function placeIt() {
        if (card.settingsPage && card.settingsPage.host)
            card.settingsPage.host.desktopEditRequested()
    }

    function screenName() {
        return QsWindow.window && QsWindow.window.screen ? QsWindow.window.screen.name : ""
    }

    // ===== Reviewed list | From a URL =====
    Item {
        width: card.innerWidth
        height: 50

        SegmentSwitch {
            width: 380
            height: 46
            anchors.verticalCenter: parent.verticalCenter
            options: [{ id: "list", label: "Reviewed list" }, { id: "url", label: "From a URL" }]
            current: card.mode
            onPicked: id => card.mode = id
        }

        Row {
            visible: card.mode === "list"
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 17
                name: "verified"
                color: mt.pInkSub
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: PluginRepoService.listStatus === "fetching" && PluginRepoService.entries.length === 0
                    ? "Fetching the list…"
                    : (PluginRepoService.entries.length === 1 ? "1 plugin" : PluginRepoService.entries.length + " plugins")
                        + ", each read by a person before it went on the list"
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }
    }

    // ===== the reviewed list =====
    Column {
        visible: card.mode === "list"
        width: card.innerWidth
        spacing: 10

        PluginField {
            id: search
            width: parent.width
            icon: "search"
            placeholder: "Search " + PluginRepoService.entries.length + " reviewed plugins: a name, a word, a tag like “bar”"
        }

        PluginNote {
            visible: card.offline
            width: parent.width
            icon: "cloud_off"
            text: PluginRepoService.listAt > 0
                ? "Can't fetch the list: " + (PluginRepoService.listStatus === "offline" ? "you're offline" : PluginRepoService.listReason || "it didn't answer")
                    + ". This is the copy from " + PR.ageText(PluginRepoService.listAt, card.now) + "; installing waits until you're back."
                : "Can't fetch the list: " + (PluginRepoService.listStatus === "offline" ? "you're offline" : PluginRepoService.listReason || "it didn't answer") + ", and there is no copy of it yet."

            SettingChip {
                capH: 36
                fontSize: 14
                label: "Try again"
                icon: "refresh"
                onClicked: PluginRepoService.fetchList()
            }
        }

        Text {
            visible: PluginRepoService.entries.length > 0 && card.results.length === 0
            text: "Nothing on the list matches “" + search.text + "”."
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Repeater {
            model: card.results

            delegate: PluginListEntry {
                required property var modelData
                width: card.innerWidth
                entry: modelData.entry
                hits: modelData.hits
                shellVersion: card.version
                installed: card.installedKey(modelData.entry.repo)
                waiting: card.offline
                onPlaceRequested: card.placeIt()
                onSettingsRequested: id => PluginService.askSettings(id, card.screenName())
            }
        }
    }

    // ===== from a URL =====
    Column {
        visible: card.mode === "url"
        width: card.innerWidth
        spacing: 12

        Item {
            width: parent.width
            height: urlField.implicitHeight

            PluginField {
                id: urlField
                width: parent.width - lookKey.width - 14
                icon: "link"
                placeholder: "owner/repo, or a git URL"
                onAccepted: PluginRepoService.lookAt(urlField.text)
            }

            SettingChip {
                id: lookKey
                x: parent.width - width
                label: PluginRepoService.look.state === "looking" ? "Looking…" : "Look"
                icon: "travel_explore"
                onClicked: PluginRepoService.lookAt(urlField.text)
            }
        }

        readonly property var look: PluginRepoService.look
        readonly property var job: look.key !== "" ? PluginRepoService.jobs[look.key] ?? null : null

        Text {
            visible: parent.look.state === "idle" && parent.job === null
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Look reads the repository first and shows what's in it. Nothing is installed until you say so."
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        // read, and it is a plugin repository
        PluginNote {
            visible: parent.look.state === "ok" && !card.installedKey(parent.look.key)
            width: parent.width
            kind: "warn"
            icon: "gpp_maybe"
            text: "This one isn't on the reviewed list: nobody has read its code, and it will run with the shell's full rights."
        }

        PluginListEntry {
            visible: parent.look.state === "ok" || (parent.job !== null && parent.look.key !== "")
            width: parent.width
            fromUrl: true
            entry: ({ repo: parent.look.key, description: "", tags: [], needs: [], sekaipop: "" })
            looked: parent.look.plugins
            lookedBad: parent.look.bad
            shellVersion: card.version
            installed: card.installedKey(parent.look.key) && (parent.job === null || parent.job.state !== "running")
            onPlaceRequested: card.placeIt()
            onSettingsRequested: id => PluginService.askSettings(id, card.screenName())
        }

        // read, and it isn't (or it couldn't be read)
        PluginNote {
            visible: parent.look.state === "bad"
            width: parent.width
            icon: parent.look.reason === "noplugin" ? "do_not_disturb_on" : parent.look.reason === "offline" ? "cloud_off" : "error"
            text: parent.look.reason === "noplugin"
                ? "<b>" + parent.look.key + " isn't a SekaiPop plugin.</b> It has no plugin.json anywhere, so there's nothing in it to install. Nothing was kept."
                : parent.look.message
        }
    }
}
