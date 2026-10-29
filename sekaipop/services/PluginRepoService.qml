pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/PluginManifest.js" as PM
import "../modules/common/functions/PluginRepos.js" as PR

// Getting and updating plugins (docs/PLUGIN-INSTALL.md): the reviewed list, installing a
// plugin repository from it or from a URL, checking for updates, updating, going back,
// pinning and removing. Settings > About / Update draws it (SettingsPluginsUpdate.qml,
// SettingsGetPlugins.qml); `ipc call plugins install | update | remove | check | restore`
// drives it from a script (PluginService's handler forwards here).
//
// The git work is scripts/state/plugin-repos.sh, one job at a time (a queue), so two clicks
// can never run git on one folder at once. What it prints is read by PluginRepos.js. Every
// install and every move of a repository's commit is written to the lockfile
// (~/.config/sekaipop/plugins-lock.json).
//
// Plugins the shell did not install (linked to a folder of the user's own, or copied in by
// hand) are never pulled, pinned or removed here: only repositories in the lockfile are.
//
// It looks for updates by itself on the shell's own update rules (UpdateService.qml): only
// while "updates.shellNotify" is on, a little after the start and then every
// "updates.shellHours" hours; ONE notification per batch of new commits, never twice for the
// same batch (`seen`, kept in ~/.cache/sekaipop/plugin-updates-seen), never for a look somebody
// asked for, and not in Game Mode (it waits for the next look).
Singleton {
    id: root

    readonly property string script: Directories.script("state/plugin-repos.sh")

    // ===== where things are (plugin-repos.sh paths) =====
    property string reposDir: ""
    property string lockPath: ""
    property string listPath: ""

    // What About / Update should scroll to when it next shows ("plugins", "get" or ""): Desktop ›
    // Plugins' "Update in About" sets it, the About page takes it.
    property string aboutTarget: ""

    // Settings on About / Update, scrolled to the Plugins card ("plugins") or Get plugins ("get").
    // The Quick Panel owns Settings; its `settings page` ipc opens a page on the focused monitor.
    function openAbout(target) {
        root.aboutTarget = target === "get" ? "get" : "plugins"
        Quickshell.execDetached(["qs", "-p", Quickshell.shellDir, "ipc", "call", "settings", "page", "about"])
    }

    // ===== the lockfile =====
    property var lock: PR.emptyLock()
    property bool lockLoaded: false

    function saveLock(next) {
        root.lock = next
        root.run(["lock-save", JSON.stringify(next, null, 2)])
    }

    // ===== the reviewed list =====
    property var entries: []
    // "idle" | "fetching" | "ok" | "offline" | "error"
    property string listStatus: "idle"
    property string listReason: ""
    // When the copy on screen was fetched (ms); 0 when there is none.
    property double listAt: 0
    // { program: true | false }: the list's needs, checked against PATH.
    property var needsFound: ({})

    function fetchList() {
        if (root.listStatus === "fetching")
            return
        root.listStatus = "fetching"
        root.run(["fetch-list"], null, out => {
            const kv = PR.parseKv(out)
            root.listStatus = kv.status || "error"
            root.listReason = kv.reason || ""
            root.readList()
        })
    }

    // The cached copy: "at=<when it was fetched>" and then the list itself.
    function readList() {
        root.run(["list"], null, out => {
            const nl = out.indexOf("\n")
            const first = nl < 0 ? out : out.slice(0, nl)
            root.listAt = first.indexOf("at=") === 0 ? Number(first.slice(3)) * 1000 : 0
            const l = PR.parseList(first.indexOf("at=") === 0 ? out.slice(nl + 1) : out)
            root.entries = l.entries
            const all = []
            for (const e of l.entries)
                for (const n of e.needs)
                    if (all.indexOf(n) < 0)
                        all.push(n)
            if (all.length > 0)
                root.run(["needs"].concat(all), null, o => {
                    const kv = PR.parseKv(o)
                    const found = {}
                    for (const n of all)
                        found[n] = kv[n] === "yes"
                    root.needsFound = found
                })
        })
    }

    // ===== updates =====
    // "idle" | "checking" | "ok" | "offline" | "error"
    property string checkStatus: "idle"
    property double checkedAt: 0
    // PR.parseCheck(): { key: { status, behind, head, upstream, log } }
    property var checkResult: ({})
    readonly property var pending: PR.updates(root.checkResult, root.lock)
    // The repositories with updates: [{ key, behind, log, from, to }]
    readonly property var updates: root.pending.list
    readonly property int pinnedSkipped: root.pending.pinnedSkipped
    // The batch last announced or looked at (PR.batchId).
    property string seen: ""
    property bool byUser: false
    readonly property bool watching: SettingsService.flag("updates.shellNotify")

    function check(byUser) {
        const keys = Object.keys(root.lock.repos)
        if (root.checkStatus === "checking") {
            if (byUser === true)
                root.byUser = true
            return
        }
        root.byUser = byUser === true
        if (keys.length === 0) {
            root.checkResult = ({})
            root.checkStatus = "ok"
            root.checkedAt = Date.now()
            return
        }
        root.checkStatus = "checking"
        root.run(["check"].concat(keys), null, out => {
            const res = PR.parseCheck(out)
            root.checkResult = res
            const st = keys.map(k => res[k] ? res[k].status : "error")
            root.checkStatus = st.every(s => s === "offline") ? "offline" : "ok"
            root.checkedAt = Date.now()
            root.announce()
        })
    }

    // One notification per batch, and only for a look nobody asked for (UpdateService's rules).
    function announce() {
        const list = root.updates
        if (list.length === 0)
            return
        const id = PR.batchId(list)
        if (id === root.seen)
            return
        if (!root.byUser && root.watching && GameModeService.enabled)
            return
        root.seen = id
        root.run(["seen", id])
        if (root.byUser || !root.watching)
            return
        notice.title = list.length === 1 ? "1 plugin has an update" : list.length + " plugins have updates"
        notice.body = PR.noticeBody(list, k => root.repoName(k))
        notice.running = true
    }

    // A repository's name in a sentence: its one plugin's name, else the repository.
    function repoName(key) {
        const r = root.lock.repos[key]
        if (r && r.plugins.length === 1) {
            const st = PluginService.stateFor(r.plugins[0])
            if (st)
                return st.plugin.name
        }
        return key
    }

    // The notification. A click on it (its default action) opens About / Update; the shell's
    // notifications draw no action buttons, so the handoff's "Show me" / "Later" are a click
    // and a dismissal.
    property Process notice: Process {
        property string title: ""
        property string body: ""
        command: ["notify-send", "-a", "sekaipop", "-i", "material:extension", "--action=default=Show me", notice.title, notice.body]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "default")
                    root.openAbout("plugins")
            }
        }
    }

    // A first look a little after the start, then every few hours; only while the setting is on.
    property Timer firstLook: Timer {
        interval: 50 * 1000
        running: root.watching && root.lockLoaded
        onTriggered: root.check(false)
    }

    property Timer regularLook: Timer {
        interval: Math.max(1, SettingsService.get("updates.shellHours")) * 3600 * 1000
        running: root.watching
        repeat: true
        onTriggered: root.check(false)
    }

    // ===== jobs on a repository =====
    // { key: { kind: "install" | "update" | "goback" | "remove", state: "running" | "done" |
    //          "partial" | "failed", pct, step, message, badge, names: [installed names],
    //          plugins: [installed plugins], bad: [{ id, error }] } }
    property var jobs: ({})

    function setJob(key, fields) {
        const j = Object.assign({}, root.jobs)
        j[key] = Object.assign({}, j[key] || {}, fields)
        root.jobs = j
    }

    function clearJob(key) {
        const j = Object.assign({}, root.jobs)
        delete j[key]
        root.jobs = j
    }

    readonly property bool busy: root.queue.length > 0 || runner.running

    // Install a repository: from the list (`reviewed`) or a URL the user typed.
    function install(input, reviewed) {
        const s = PR.source(input)
        if (!s.ok)
            return s.error
        if (root.lock.repos[s.key])
            return s.key + " is installed already"
        // On the reviewed list is reviewed, however it was asked for (a URL, the ipc).
        if (root.entries.some(e => e.repo.toLowerCase() === s.key.toLowerCase()))
            reviewed = true
        root.setJob(s.key, { kind: "install", state: "running", pct: 0, step: "Cloning", message: "", badge: "", names: [], plugins: [], bad: [] })
        root.run(["install", s.url, s.key], line => {
            if (line.indexOf("progress=") === 0) {
                const p = PR.cloneProgress(line.slice(9))
                if (p !== null)
                    root.setJob(s.key, { pct: p })
            }
        }, out => root.installed(s, reviewed === true, out))
        return "installing " + s.key
    }

    function installed(s, reviewed, out) {
        const head = out.split("\x1e")[0]
        const kv = PR.parseKv(head)
        if (kv.status !== "ok") {
            root.setJob(s.key, { state: "failed", badge: "NOT INSTALLED", message: PR.failure(kv.status, s.key), reason: kv.status })
            return
        }
        const recs = PM.splitScan(out.slice(head.length), true)
        const found = PR.checkFound(recs, PM.parse)
        const sum = PR.installSummary(found.good, found.bad)
        root.setJob(s.key, { step: "Linking", pct: 100 })
        // Every plugin folder is linked, a broken one too: the scan then lists it under Didn't
        // load with its reason, as for any plugin, rather than it vanishing.
        const links = found.good.map(g => ({ path: g.path, id: g.plugin.id }))
            .concat(found.bad.filter(b => /^[a-z0-9][a-z0-9-]{0,39}$/.test(b.id)).map(b => ({ path: b.path, id: b.id })))
        const ids = links.map(l => l.id)
        let refused = 0
        for (const l of links)
            root.run(["link", s.key, l.path, l.id], null, o => {
                if (PR.parseKv(o).status !== "ok")
                    refused++
            })
        root.run(["--noop"], null, () => {
            root.saveLock(PR.withInstall(root.lock, s.key, { url: s.url, commit: kv.commit || "", reviewed: reviewed, plugins: ids }, Date.now()))
            PluginService.rescan()
            root.setJob(s.key, {
                state: refused > 0 && found.good.length <= refused ? "failed" : sum.state,
                badge: sum.badge,
                message: refused > 0 ? PR.failure("exists", s.key) : "",
                names: found.good.map(g => g.plugin.name),
                plugins: found.good.map(g => g.plugin),
                bad: found.bad
            })
        })
    }

    // What a URL holds, before installing it (From a URL's Look).
    // { state: "idle" | "looking" | "ok" | "bad", key, input, plugins: [plugin], bad, message }
    property var look: ({ state: "idle", key: "", input: "", plugins: [], bad: [], message: "" })

    function lookAt(input) {
        const s = PR.source(input)
        if (!s.ok) {
            root.look = { state: "bad", key: "", input: input, plugins: [], bad: [], message: s.error }
            return
        }
        root.look = { state: "looking", key: s.key, input: input, plugins: [], bad: [], message: "" }
        root.run(["look", s.url, s.key], null, out => {
            const head = out.split("\x1e")[0]
            const kv = PR.parseKv(head)
            if (kv.status !== "ok") {
                root.look = { state: "bad", key: s.key, input: input, plugins: [], bad: [], message: PR.failure(kv.status, s.key), reason: kv.status }
                return
            }
            const found = PR.checkFound(PM.splitScan(out.slice(head.length), true), PM.parse)
            root.look = { state: "ok", key: s.key, input: input, plugins: found.good.map(g => g.plugin), bad: found.bad, message: "" }
        })
    }

    function update(key) {
        const r = root.lock.repos[key]
        if (!r || r.pinned)
            return key + (r ? " is pinned" : " was not installed from here")
        root.setJob(key, { kind: "update", state: "running", step: "Pulling", pct: 50, message: "" })
        root.run(["update", key], null, out => {
            const kv = PR.parseKv(out)
            if (kv.status !== "ok") {
                root.setJob(key, { state: "failed", message: kv.reason || "it didn't update" })
                return
            }
            root.saveLock(PR.withCommit(root.lock, key, kv.commit, Date.now(), kv.previous))
            root.forgetCheck(key)
            PluginService.rescan()
            root.setJob(key, { state: "done", pct: 100, from: (kv.previous || "").slice(0, 7) })
        })
        return "updating " + key
    }

    function updateAll() {
        for (const u of root.updates)
            if (!(root.jobs[u.key] && root.jobs[u.key].state === "running"))
                root.update(u.key)
    }

    // Back to the commit before the last update (the lockfile's `previous`).
    function goBack(key) {
        const r = root.lock.repos[key]
        if (!r || r.previous === "")
            return key + " has nothing to go back to"
        root.setJob(key, { kind: "goback", state: "running", step: "Going back", pct: 50, message: "" })
        root.run(["goback", key, r.previous], null, out => {
            const kv = PR.parseKv(out)
            if (kv.status !== "ok") {
                root.setJob(key, { state: "failed", message: kv.reason || "it couldn't go back" })
                return
            }
            root.saveLock(PR.withCommit(root.lock, key, kv.commit, Date.now(), kv.previous))
            PluginService.rescan()
            root.clearJob(key)
            root.check(true)
        })
        return "going back on " + key
    }

    function pin(key, on) {
        if (!root.lock.repos[key])
            return key + " was not installed from here"
        root.saveLock(PR.withPin(root.lock, key, on))
        return key + (on ? " pinned" : " unpinned")
    }

    // Remove a repository: its plugins come off the desktop and the bar and are unlinked, its
    // clone is deleted. Their saved settings stay unless `deleteSettings`.
    function remove(key, deleteSettings) {
        const r = root.lock.repos[key]
        if (!r)
            return key + " was not installed from here"
        const ids = r.plugins.slice()
        for (const id of ids) {
            const st = PluginService.stateFor(id)
            if (st) {
                st.setShown(false)
                st.setBarShown(false)
            }
        }
        root.setJob(key, { kind: "remove", state: "running", step: "Removing", pct: 50 })
        root.run(["remove", key], null, () => {
            if (deleteSettings === true)
                for (const id of ids)
                    root.run(["forget", id])
            root.saveLock(PR.withoutRepo(root.lock, key))
            root.forgetCheck(key)
            root.clearJob(key)
            PluginService.rescan()
        })
        return "removing " + key
    }

    // Put every repository of the lockfile back where it says (a new machine, a restored home):
    // clone the missing ones and move each to its commit.
    function restore() {
        const keys = Object.keys(root.lock.repos)
        for (const key of keys) {
            const r = root.lock.repos[key]
            root.run(["install", r.url, key], null, out => {
                const kv = PR.parseKv(out.split("\x1e")[0])
                if (kv.status === "ok") {
                    const recs = PM.splitScan(out.slice(out.split("\x1e")[0].length), true)
                    for (const g of PR.checkFound(recs, PM.parse).good)
                        root.run(["link", key, g.path, g.plugin.id])
                }
                if (kv.status === "ok" || kv.status === "exists")
                    root.run(["goback", key, r.commit], null, () => PluginService.rescan())
            })
        }
        return keys.length === 0 ? "nothing in the lockfile" : "restoring " + keys.join(", ")
    }

    function forgetCheck(key) {
        const c = Object.assign({}, root.checkResult)
        delete c[key]
        root.checkResult = c
    }

    // ===== the one runner =====
    // run(args, onLine, onDone): plugin-repos.sh with these arguments, after every job before
    // it. "--noop" runs nothing and only keeps its place in the queue (a step that must come
    // after the ones queued before it).
    property var queue: []

    function run(args, onLine, onDone) {
        root.queue = root.queue.concat([{ args: args, onLine: onLine || null, onDone: onDone || null }])
        root.next()
    }

    function next() {
        if (runner.running || root.queue.length === 0)
            return
        const job = root.queue[0]
        root.queue = root.queue.slice(1)
        runner.job = job
        runner.lines = []
        if (job.args[0] === "--noop") {
            runner.job = null
            if (job.onDone)
                job.onDone("")
            Qt.callLater(root.next)
            return
        }
        runner.command = ["sh", root.script].concat(job.args)
        runner.running = true
    }

    Process {
        id: runner
        property var job: null
        property var lines: []

        stdout: SplitParser {
            onRead: line => {
                runner.lines.push(line)
                if (runner.job && runner.job.onLine)
                    runner.job.onLine(line)
            }
        }

        onExited: code => {
            const job = runner.job
            runner.job = null
            if (job && job.onDone)
                job.onDone(runner.lines.join("\n"))
            Qt.callLater(root.next)
        }
    }

    // ===== at the start =====
    property Process starter: Process {
        running: true
        command: ["sh", root.script, "paths"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = PR.parseKv(text)
                root.reposDir = kv.repos || ""
                root.lockPath = kv.lock || ""
                root.listPath = kv.list || ""
                root.run(["lock"], null, out => {
                    root.lock = PR.readLock(out)
                    root.lockLoaded = true
                })
                root.run(["seen"], null, out => root.seen = out.trim())
                // The cached copy of the list, so Get plugins has something before a fetch.
                root.readList()
            }
        }
    }
}
