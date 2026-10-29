import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/PluginRepos.js" as PR

// About / Update > Plugins (docs/PLUGIN-INSTALL.md): the plugins' own update, under the shell's.
//
//   status       how many repositories have updates, or that it's checking, or offline
//   Updates      each repository with commits to bring, the commits, Update (or all of them)
//   Installed    every installed plugin by where it came from: repositories the shell
//                installed (a row of their own when they hold several plugins), then the
//                folders of the user's own ("Managed by you") and those copied in by hand.
//                Source opens a repository: its commit, Go back, Pin, Remove.
//   Didn't load  the folders that were skipped, with where they came from
//
// Editing a plugin's settings stays in Desktop › Plugins (Settings opens it there). Folders
// the shell did not install are never pulled, pinned or removed from here.
SectionCard {
    id: card

    // The SettingsPage it is on.
    property var settingsPage: null

    // The repository whose Source is open, and the one being removed ("" = none).
    property string sourceOpen: ""
    property string removing: ""
    // Repositories whose commits are shown, in Updates.
    property var openCommits: ({})

    title: "Plugins"
    icon: "extension"

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property var lock: PluginRepoService.lock
    readonly property var groups: {
        const _ = [PluginService.found, PluginService.skipped, PluginRepoService.reposDir]
        return PR.groups(PluginService.found.map(f => ({ id: f.plugin.id, name: f.plugin.name, target: f.plugin.target || "" })),
            PluginService.skipped.map(s => ({ id: s.id, name: s.id, target: s.target || "" })),
            PluginRepoService.reposDir, card.lock)
    }

    // A clock for "checked 2 min ago".
    property double now: Date.now()
    Timer {
        interval: 30000
        running: card.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: card.now = Date.now()
    }

    // Opening About / Update looks for plugin updates too, when nothing has looked yet.
    onVisibleChanged: {
        if (visible && PluginRepoService.lockLoaded && PluginRepoService.checkStatus === "idle")
            PluginRepoService.check(true)
    }
    Connections {
        target: PluginRepoService
        function onLockLoadedChanged() {
            if (card.visible && PluginRepoService.checkStatus === "idle")
                PluginRepoService.check(true)
        }
    }

    function stateOf(id) {
        return PluginService.stateFor(id)
    }

    function namesOf(group) {
        return group.plugins.map(p => p.name)
    }

    function behindOf(repo) {
        const c = PluginRepoService.checkResult[repo]
        return c && c.status === "ok" ? c.behind : 0
    }

    function repoBadges(repo) {
        const out = []
        const r = card.lock.repos[repo]
        const b = card.behindOf(repo)
        if (r && r.pinned)
            out.push({ kind: "mute", text: b > 0 ? "Pinned · " + b + " skipped" : "Pinned", icon: "push_pin" })
        else if (b > 0)
            out.push({ kind: "on", text: b + (b === 1 ? " commit behind" : " commits behind") })
        return out
    }

    readonly property var updatingNow: Object.keys(PluginRepoService.jobs).filter(k => PluginRepoService.jobs[k].kind === "update" && PluginRepoService.jobs[k].state === "running")
    // What Updates lists: the repositories with updates, and those updated this time round (so
    // Updated and Go back stay where they were).
    readonly property var updateRows: {
        const rows = PluginRepoService.updates.slice()
        for (const k of Object.keys(PluginRepoService.jobs)) {
            const j = PluginRepoService.jobs[k]
            if (j.kind === "update" && (j.state === "done" || j.state === "failed") && !rows.some(u => u.key === k))
                rows.push({ key: k, behind: 0, log: [], from: "", to: "" })
        }
        return rows
    }

    readonly property int installedRepos: Object.keys(card.lock.repos).length
    readonly property bool anyMoved: Object.keys(PluginRepoService.jobs).some(k => PluginRepoService.jobs[k].kind === "update" && PluginRepoService.jobs[k].state === "done")

    // ===== the status line and its keys =====
    Item {
        width: card.innerWidth
        height: Math.max(statusRow.implicitHeight, heads.height)

        Row {
            id: statusRow
            width: parent.width - heads.width - 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 20
                name: PluginRepoService.checkStatus === "offline" ? "cloud_off"
                    : PluginRepoService.updates.length > 0 ? "new_releases" : "check_circle"
                color: mt.pInk
                visible: PluginRepoService.checkStatus !== "checking" && card.updatingNow.length === 0

            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                text: {
                    if (card.updatingNow.length > 0)
                        return "<b>Updating " + card.updatingNow.length + " of " + (card.updatingNow.length + PluginRepoService.updates.filter(u => card.updatingNow.indexOf(u.key) < 0).length)
                            + "</b> · the rest keep working"
                    switch (PluginRepoService.checkStatus) {
                    case "checking": return "<b>Checking for updates…</b>"
                    case "offline": return "<b>Couldn't check for updates: you're offline.</b> Your plugins work as they are."
                    case "idle": return card.installedRepos === 0 ? "<b>Nothing installed from a repository yet.</b> Get plugins is just below." : "<b>Not checked yet</b>"
                    }
                    if (card.installedRepos === 0)
                        return "<b>Nothing installed from a repository yet.</b> Get plugins is just below."
                    const t = "<b>" + PR.updatesTitle(PluginRepoService.updates.length) + "</b> · checked " + PR.ageText(PluginRepoService.checkedAt, card.now)
                    const p = PluginRepoService.pinnedSkipped
                    return t + (p > 0 ? " · " + p + " pinned, skipped" : "")
                }
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 15
                font.weight: Font.Bold
            }
        }

        Row {
            id: heads
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            SettingChip {
                capH: 36
                fontSize: 14
                label: PluginRepoService.checkStatus === "checking" ? "Checking…" : "Check for updates"
                icon: "update"
                onClicked: PluginRepoService.check(true)
            }

            SettingChip {
                capH: 36
                fontSize: 14
                label: "Open the folder"
                icon: "folder_open"
                onClicked: PluginService.openFolder("")
            }
        }
    }

    // ===== Updates =====
    Column {
        visible: card.updateRows.length > 0
        width: card.innerWidth
        spacing: 6

        PluginRepoHead {
            width: parent.width
            title: "Updates"
            // A plugin's QML is loaded once, when the shell starts: an update (or a Go back) is on
            // disk at once, and on screen from the next start.
            note: card.anyMoved ? "Done. Updated plugins run their new code from the next start of the shell."
                : "Each shows the commits it brings first."

            SettingChip {
                visible: card.anyMoved
                capH: 36
                fontSize: 14
                label: "Restart the shell"
                icon: "restart_alt"
                onClicked: Quickshell.execDetached(["setsid", "sh", Directories.script("system/restart-shell.sh"), Quickshell.shellDir])
            }

            SettingChip {
                visible: PluginRepoService.updates.length > 1
                capH: 36
                fontSize: 14
                selected: true
                label: PluginRepoService.updates.length === 2 ? "Update both" : "Update all " + PluginRepoService.updates.length
                icon: "download"
                onClicked: PluginRepoService.updateAll()
            }
        }

        Repeater {
            model: card.updateRows

            delegate: PluginUpdateBox {
                required property var modelData
                width: card.innerWidth
                update: modelData
                pluginsText: {
                    const r = card.lock.repos[modelData.key]
                    const names = r ? r.plugins.map(id => { const st = card.stateOf(id); return st ? st.plugin.name : id }) : []
                    return PR.namesText(names)
                }
                open: !!card.openCommits[modelData.key]
                onOpenChanged: {
                    const o = Object.assign({}, card.openCommits)
                    o[modelData.key] = open
                    card.openCommits = o
                }
            }
        }
    }

    // ===== Remove, second step =====
    PluginRemoveAsk {
        visible: card.removing !== ""
        width: card.innerWidth
        repo: card.removing
        names: {
            const r = card.lock.repos[card.removing]
            return r ? r.plugins.map(id => { const st = card.stateOf(id); return st ? st.plugin.name : id }) : []
        }
        onDone: {
            if (card.sourceOpen === card.removing)
                card.sourceOpen = ""
            card.removing = ""
        }
    }

    // ===== Installed =====
    Column {
        visible: card.groups.some(g => g.plugins.length > 0) || card.installedRepos > 0
        width: card.innerWidth
        spacing: 6

        PluginRepoHead {
            width: parent.width
            title: "Installed"
            note: "By where each came from. Settings opens a plugin in Desktop › Plugins."
        }

        Repeater {
            model: card.groups

            delegate: Column {
                id: grp
                required property var modelData
                readonly property bool isRepo: modelData.kind === "repo"
                readonly property bool several: isRepo && modelData.plugins.length > 1
                readonly property var info: isRepo ? card.lock.repos[modelData.repo] ?? null : null
                readonly property var states: modelData.plugins.map(p => card.stateOf(p.id)).filter(s => !!s)

                width: card.innerWidth
                spacing: 6

                // a repository opened: its Source
                PluginSourcePanel {
                    visible: grp.isRepo && card.sourceOpen === grp.modelData.repo
                    width: card.innerWidth
                    repo: grp.isRepo ? grp.modelData.repo : ""
                    states: grp.states
                    onCloseRequested: card.sourceOpen = ""
                    onRemoveRequested: card.removing = grp.modelData.repo
                }

                // a repository with several plugins: its own row, its plugins under it
                Item {
                    visible: grp.several && card.sourceOpen !== grp.modelData.repo
                    width: card.innerWidth
                    height: 52

                    Row {
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        PluginDiamond {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 28
                            icon: "inventory_2"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: grp.isRepo ? grp.modelData.repo : ""
                            color: mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.ExtraBold
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: grp.modelData.plugins.length + " plugins · "
                                + (grp.info && grp.info.reviewed ? "from the reviewed list" : "added from a URL · not reviewed")
                            color: mt.pInkSub
                            font.family: mt.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: grp.isRepo ? card.repoBadges(grp.modelData.repo) : []
                            delegate: PluginBadge {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                kind: modelData.kind
                                icon: modelData.icon || ""
                                text: modelData.text
                            }
                        }
                    }

                    SettingChip {
                        x: parent.width - width - 14
                        anchors.verticalCenter: parent.verticalCenter
                        capH: 36
                        fontSize: 14
                        label: "Source"
                        icon: "commit"
                        onClicked: card.sourceOpen = grp.modelData.repo
                    }
                }

                Repeater {
                    // One plugin of a repository whose Source is open is in the panel's header.
                    model: grp.isRepo && card.sourceOpen === grp.modelData.repo && !grp.several ? [] : grp.modelData.plugins

                    delegate: PluginInstalledRow {
                        required property var modelData
                        width: card.innerWidth
                        pst: card.stateOf(modelData.id)
                        visible: pst !== null
                        indent: grp.several
                        source: grp.several ? null
                            : PR.sourceLine(grp.modelData.kind, grp.modelData.repo || "", !!grp.info && grp.info.reviewed,
                                (pst && pst.plugin.target) || "", card.home)
                        badges: grp.isRepo && !grp.several ? card.repoBadges(grp.modelData.repo) : []
                        keyLabel: grp.several ? "" : grp.isRepo ? "Source" : "Open the folder"
                        keyIcon: grp.isRepo ? "commit" : "folder_open"
                        onKeyClicked: {
                            if (grp.isRepo)
                                card.sourceOpen = grp.modelData.repo
                            else
                                PluginService.openFolder(modelData.id)
                        }
                    }
                }

                // a repository in the lockfile whose plugins are all gone: it can still be removed
                PluginNote {
                    visible: grp.isRepo && grp.modelData.plugins.length === 0 && grp.modelData.skipped.length === 0
                    width: card.innerWidth
                    icon: "inventory_2"
                    text: "<b>" + (grp.isRepo ? grp.modelData.repo : "") + "</b> is installed, but none of its plugins is in the plugins folder any more."

                    SettingChip {
                        capH: 36
                        fontSize: 14
                        label: "Remove…"
                        onClicked: card.removing = grp.modelData.repo
                    }
                }
            }
        }
    }

    // ===== Didn't load =====
    Column {
        visible: PluginService.skipped.length > 0
        width: card.innerWidth
        spacing: 6

        PluginRepoHead {
            width: parent.width
            title: "Didn't load"
            note: "Skipped, never loaded half-broken."
        }

        Repeater {
            model: PluginService.skipped

            delegate: Item {
                id: sk
                required property var modelData
                readonly property var where: PR.repoOf(modelData.target || "", PluginRepoService.reposDir, card.lock)
                readonly property var info: where.kind === "repo" ? card.lock.repos[where.repo] ?? null : null
                width: card.innerWidth
                height: skRow.implicitHeight + (srcFlow.visible ? srcFlow.height + 6 : 0)

                PluginRow {
                    id: skRow
                    width: parent.width - (repoKeys.visible ? repoKeys.width + 16 : 0)
                    skip: sk.modelData
                    onActionRequested: action => {
                        if (action === "update")
                            UpdateService.check(true)
                        else
                            PluginService.openFolder(sk.modelData.id)
                    }
                }

                Row {
                    id: repoKeys
                    visible: sk.where.kind === "repo"
                    x: parent.width - width - 4
                    y: 16
                    spacing: 12

                    SettingChip {
                        capH: 36
                        fontSize: 14
                        label: "Check for updates"
                        onClicked: PluginRepoService.check(true)
                    }

                    SettingChip {
                        capH: 36
                        fontSize: 14
                        label: "Remove…"
                        onClicked: card.removing = sk.where.repo
                    }
                }

                Flow {
                    id: srcFlow
                    readonly property var line: PR.sourceLine(sk.where.kind, sk.where.repo || "", !!sk.info && sk.info.reviewed, sk.modelData.target || "", card.home)
                    visible: sk.where.kind !== "copied"
                    x: 22 + 4 + 46 + 4 + 20
                    y: skRow.implicitHeight - 8
                    width: parent.width - x - 20
                    spacing: 8

                    MaterialIcon {
                        y: 1
                        size: 15
                        name: srcFlow.line.icon
                        color: mt.pInkSub
                    }

                    Text {
                        text: srcFlow.line.text
                        color: mt.pInkSub
                        font.family: mt.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: srcFlow.line.code
                        color: mt.pInk
                        font.family: "monospace"
                        font.pixelSize: 13
                    }

                    Text {
                        visible: srcFlow.line.note !== ""
                        text: "· " + srcFlow.line.note
                        color: mt.pInkSub
                        font.family: mt.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }
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
            y: 22 + 16
            width: parent.width
            spacing: 10

            MaterialIcon {
                size: 18
                name: "shield"
                color: mt.pInkSub
            }

            Text {
                id: trust
                width: parent.width - 28
                wrapMode: Text.WordWrap
                text: "A plugin runs with the shell's full rights: it can run programs and read your files. Keep the ones you'd trust as a script of your own."
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }
    }
}
