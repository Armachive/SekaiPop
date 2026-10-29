.pragma library

// Getting and updating plugins (services/PluginRepoService.qml, docs/PLUGIN-INSTALL.md): the
// reviewed list, where each installed plugin came from, the lockfile, and what the git side
// (scripts/state/plugin-repos.sh) prints. Pure functions on plain objects, tested with node:
// tests/plugin-test/repos_unit.js.
//
// A plugin repository holds one plugin or several (each a folder with a plugin.json). The
// shell clones a repository once into its repos folder (~/.local/share/sekaipop/plugin-repos/
// <owner>/<repo>) and links every plugin folder in it into the plugins folder. So updating,
// pinning, going back and removing are about a repository; settings, the bar entry and the
// widget are about a plugin.

// "owner/repo" on GitHub: what the list holds and what a short URL is.
var REPO_RE = /^[A-Za-z0-9][A-Za-z0-9-]{0,38}\/[A-Za-z0-9._-]{1,100}$/

function isObj(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function strings(v) {
    if (!Array.isArray(v))
        return []
    var out = []
    for (var i = 0; i < v.length; i++)
        if (typeof v[i] === "string" && v[i].trim() !== "" && out.indexOf(v[i].trim()) < 0)
            out.push(v[i].trim())
    return out
}

// ===== versions =====

// "1.2.0" -> [1, 2, 0]; anything after a "-" or "+" is ignored, missing parts are 0.
function versionParts(v) {
    var s = String(v || "").split(/[-+]/)[0]
    var p = s.split(".")
    var out = []
    for (var i = 0; i < 3; i++) {
        var n = parseInt(p[i], 10)
        out.push(isFinite(n) ? n : 0)
    }
    return out
}

// a >= b, as versions.
function versionAtLeast(a, b) {
    var x = versionParts(a), y = versionParts(b)
    for (var i = 0; i < 3; i++) {
        if (x[i] !== y[i])
            return x[i] > y[i]
    }
    return true
}

// ===== the reviewed list =====

// parseList(text) -> { ok, entries: [{ repo, description, tags, needs, sekaipop }], error }
// The list is plugins.json at the root of the SekaiPop repository, an array of entries (or
// { "plugins": [...] }). An entry that is not one is left out, never a reason to drop the list.
function parseList(text) {
    var data
    try {
        data = JSON.parse(text)
    } catch (e) {
        return { ok: false, entries: [], error: "the list is not valid JSON" }
    }
    var arr = Array.isArray(data) ? data : (isObj(data) && Array.isArray(data.plugins) ? data.plugins : null)
    if (!arr)
        return { ok: false, entries: [], error: "the list is not a list of plugins" }
    var out = []
    var seen = {}
    for (var i = 0; i < arr.length; i++) {
        var e = arr[i]
        if (!isObj(e) || typeof e.repo !== "string" || !REPO_RE.test(e.repo) || seen[e.repo.toLowerCase()])
            continue
        seen[e.repo.toLowerCase()] = true
        out.push({
            repo: e.repo,
            description: typeof e.description === "string" ? e.description.trim() : "",
            tags: strings(strings(e.tags).map(function (t) { return t.toLowerCase() })),
            needs: strings(e.needs),
            sekaipop: typeof e.sekaipop === "string" ? e.sekaipop : ""
        })
    }
    out.sort(function (a, b) { return a.repo.toLowerCase() < b.repo.toLowerCase() ? -1 : 1 })
    return { ok: true, entries: out, error: "" }
}

// The list searched: a name, a word of the description, or a tag. Every word of the query must
// match somewhere. Each result carries which tags matched (`hits`), to mark them.
function search(entries, query) {
    var words = String(query || "").toLowerCase().split(/\s+/).filter(function (w) { return w !== "" })
    var out = []
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i]
        var hay = (e.repo + " " + e.description).toLowerCase()
        var hits = []
        var all = true
        for (var j = 0; j < words.length; j++) {
            var w = words[j]
            var tagHit = e.tags.filter(function (t) { return t.indexOf(w) === 0 })
            if (tagHit.length > 0) {
                for (var k = 0; k < tagHit.length; k++)
                    if (hits.indexOf(tagHit[k]) < 0)
                        hits.push(tagHit[k])
            } else if (hay.indexOf(w) < 0) {
                all = false
                break
            }
        }
        if (all)
            out.push({ entry: e, hits: hits })
    }
    return out
}

// ===== a source the user typed =====

// "owner/repo", "https://github.com/owner/repo(.git)", "git@github.com:owner/repo.git", or any
// other git URL -> { ok, key, url, github } where `key` names the repository in the lockfile
// and the repos folder ("owner/repo" for GitHub, "host/path" otherwise).
function source(input) {
    var s = String(input || "").trim().replace(/\/+$/, "")
    if (s === "")
        return { ok: false, key: "", url: "", github: false, error: "type owner/repo, or a git URL" }
    var gh = s.match(/^(?:https?:\/\/)?(?:www\.)?github\.com\/([^\/\s]+\/[^\/\s]+?)(?:\.git)?$/i)
        || s.match(/^git@github\.com:([^\/\s]+\/[^\/\s]+?)(?:\.git)?$/i)
    if (gh)
        s = gh[1]
    if (REPO_RE.test(s))
        return { ok: true, key: s, url: "https://github.com/" + s + ".git", github: true, error: "" }
    var other = s.match(/^(?:https?:\/\/|ssh:\/\/|git@)([^\/:\s]+)[\/:](\S+?)(?:\.git)?$/)
    if (other && /^[\w.\/-]+$/.test(other[2]) && other[2].indexOf("..") < 0)
        return { ok: true, key: other[1] + "/" + other[2], url: s, github: false, error: "" }
    return { ok: false, key: "", url: "", github: false, error: "that isn't owner/repo or a git URL" }
}

// ===== what the scan says about each plugin folder =====

// Where each installed plugin came from. `target` is where its folder really is (the scan
// resolves links): inside the repos folder it came from a repository the shell installed;
// a link anywhere else is the user's own folder; no link is a folder copied in by hand.
//   -> { kind: "repo", repo, path } | { kind: "yours", path } | { kind: "copied" }
function origin(target, reposDir) {
    var t = String(target || "")
    var base = String(reposDir || "").replace(/\/+$/, "") + "/"
    if (t === "")
        return { kind: "copied" }
    if (base !== "/" && t.indexOf(base) === 0) {
        var rest = t.slice(base.length).split("/")
        // owner/repo, or host/a/b for a non-GitHub repository: the key is what the lockfile
        // names, so it is found by the longest key that is a prefix.
        return { kind: "repo", repo: rest.slice(0, 2).join("/"), path: rest.slice(2).join("/") }
    }
    return { kind: "yours", path: t }
}

// The repository a plugin's folder belongs to, by the lockfile's keys (one may be "host/a/b").
function repoOf(target, reposDir, lock) {
    var o = origin(target, reposDir)
    if (o.kind !== "repo")
        return o
    var base = String(reposDir || "").replace(/\/+$/, "") + "/"
    var rel = String(target).slice(base.length)
    var keys = Object.keys((lock && lock.repos) || {}).sort(function (a, b) { return b.length - a.length })
    for (var i = 0; i < keys.length; i++) {
        if (rel === keys[i] || rel.indexOf(keys[i] + "/") === 0)
            return { kind: "repo", repo: keys[i], path: rel.slice(keys[i].length + 1) }
    }
    return o
}

// The installed list, by where each plugin came from (the "Installed" part of the Plugins
// card). `plugins` is [{ id, name, target }] (loaded ones), `skipped` the same for folders
// that didn't load. Repositories first (by name), then the user's own, then the copied.
//   -> [{ kind: "repo", repo, plugins: [...], skipped: [...] }, { kind: "yours", plugins }, ...]
function groups(plugins, skipped, reposDir, lock) {
    var byRepo = {}
    var order = []
    var yours = [], copied = []
    var add = function (p, bad) {
        var o = repoOf(p.target, reposDir, lock)
        if (o.kind === "repo") {
            if (!byRepo[o.repo]) {
                byRepo[o.repo] = { kind: "repo", repo: o.repo, plugins: [], skipped: [] }
                order.push(o.repo)
            }
            byRepo[o.repo][bad ? "skipped" : "plugins"].push(p)
        } else if (!bad) {
            (o.kind === "yours" ? yours : copied).push(p)
        }
    }
    for (var i = 0; i < (plugins || []).length; i++)
        add(plugins[i], false)
    for (var j = 0; j < (skipped || []).length; j++)
        add(skipped[j], true)
    // A repository in the lockfile whose plugins all went missing still shows, so it can be removed.
    var locked = Object.keys((lock && lock.repos) || {})
    for (var k = 0; k < locked.length; k++) {
        if (!byRepo[locked[k]]) {
            byRepo[locked[k]] = { kind: "repo", repo: locked[k], plugins: [], skipped: [] }
            order.push(locked[k])
        }
    }
    order.sort(function (a, b) { return a.toLowerCase() < b.toLowerCase() ? -1 : 1 })
    var out = order.map(function (r) { return byRepo[r] })
    if (yours.length > 0)
        out.push({ kind: "yours", plugins: yours })
    if (copied.length > 0)
        out.push({ kind: "copied", plugins: copied })
    return out
}

// ===== the lockfile =====
// ~/.config/sekaipop/plugins-lock.json: every repository the shell installed, with the commit it
// is on, the commit before the last update (Go back), whether it is pinned, and when.
//   { "version": 1, "repos": { "owner/repo": { url, commit, previous, pinned, reviewed,
//                                              installed, updated, plugins: [ids] } } }

function emptyLock() {
    return { version: 1, repos: {} }
}

function readLock(text) {
    var d
    try {
        d = JSON.parse(text)
    } catch (e) {
        return emptyLock()
    }
    if (!isObj(d) || !isObj(d.repos))
        return emptyLock()
    var out = emptyLock()
    for (var k in d.repos) {
        var r = d.repos[k]
        if (!isObj(r) || typeof r.commit !== "string")
            continue
        out.repos[k] = {
            url: typeof r.url === "string" ? r.url : "",
            commit: r.commit,
            previous: typeof r.previous === "string" ? r.previous : "",
            pinned: r.pinned === true,
            reviewed: r.reviewed === true,
            installed: typeof r.installed === "number" ? r.installed : 0,
            updated: typeof r.updated === "number" ? r.updated : 0,
            plugins: strings(r.plugins)
        }
    }
    return out
}

function copyLock(lock) {
    return JSON.parse(JSON.stringify(lock || emptyLock()))
}

function withInstall(lock, key, info, now) {
    var l = copyLock(lock)
    l.repos[key] = {
        url: info.url || "",
        commit: info.commit || "",
        previous: "",
        pinned: false,
        reviewed: info.reviewed === true,
        installed: now,
        updated: now,
        plugins: strings(info.plugins)
    }
    return l
}

// An update (or a Go back) moves `commit`; the one it left is `previous`, which is what the
// next Go back returns to. Going back to `previous` swaps the two, so Go back twice is a no-op.
function withCommit(lock, key, commit, now) {
    var l = copyLock(lock)
    var r = l.repos[key]
    if (!r || r.commit === commit)
        return l
    r.previous = r.commit
    r.commit = commit
    r.updated = now
    return l
}

function withPin(lock, key, pinned) {
    var l = copyLock(lock)
    if (l.repos[key])
        l.repos[key].pinned = pinned === true
    return l
}

function withPlugins(lock, key, ids) {
    var l = copyLock(lock)
    if (l.repos[key])
        l.repos[key].plugins = strings(ids)
    return l
}

function withoutRepo(lock, key) {
    var l = copyLock(lock)
    delete l.repos[key]
    return l
}

// ===== what the git side prints =====

function parseKv(text) {
    var out = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var j = lines[i].indexOf("=")
        if (j > 0)
            out[lines[i].slice(0, j)] = lines[i].slice(j + 1).trim()
    }
    return out
}

// A commit line: "<hash>|<subject>|<age>" (the subject may hold "|").
function parseCommit(line) {
    var p = String(line).split("|")
    if (p.length < 3)
        return null
    return { hash: p[0], subject: p.slice(1, -1).join("|"), age: p[p.length - 1] }
}

// `plugin-repos.sh check`: per repository a line "\x1e<key>", then key=value lines and
// "log=<commit line>" lines. -> { key: { status, behind, head, upstream, log: [...], reason } }
function parseCheck(text) {
    var out = {}
    var parts = String(text || "").split("\x1e")
    for (var i = 1; i < parts.length; i++) {
        var lines = parts[i].split("\n")
        var key = lines[0].trim()
        if (key === "")
            continue
        var r = { status: "error", behind: 0, head: "", upstream: "", log: [], reason: "" }
        for (var j = 1; j < lines.length; j++) {
            var l = lines[j]
            var k = l.indexOf("=")
            if (k <= 0)
                continue
            var name = l.slice(0, k), val = l.slice(k + 1)
            if (name === "log") {
                var c = parseCommit(val)
                if (c)
                    r.log.push(c)
            } else if (name === "behind") {
                r.behind = parseInt(val, 10) || 0
            } else if (name in r) {
                r[name] = val.trim()
            }
        }
        out[key] = r
    }
    return out
}

// git's progress on stderr ("Receiving objects:  62% (31/50)") as a whole percentage over the
// whole clone: counting, then receiving (most of it), then resolving. null for any other line.
function cloneProgress(line) {
    var m = String(line).match(/(Counting|Compressing|Receiving|Resolving) (?:objects|deltas):\s+(\d+)%/)
    if (!m)
        return null
    var pct = parseInt(m[2], 10)
    switch (m[1]) {
    case "Counting": return Math.round(pct * 0.05)
    case "Compressing": return 5 + Math.round(pct * 0.05)
    case "Receiving": return 10 + Math.round(pct * 0.8)
    default: return 90 + Math.round(pct * 0.1)
    }
}

// `plugin-repos.sh look` / `install`: what went wrong, in the user's words (the handoff's
// "Failed" board).
function failure(reason, key) {
    switch (reason) {
    case "offline": return "Couldn't reach " + (REPO_RE.test(key) ? "github.com" : key.split("/")[0]) + ": you're offline. Nothing changed."
    case "norepo": return "There's no repository at " + (REPO_RE.test(key) ? "github.com/" + key : key) + ", or it's private. Check the spelling."
    case "noplugin": return key + " isn't a SekaiPop plugin. It has no plugin.json anywhere, so there's nothing in it to install. Nothing was kept."
    case "exists": return "Something is already installed under one of its plugins' names. Remove it first."
    case "nogit": return "Installing a plugin needs git, which isn't installed."
    default: return reason ? reason : "It didn't install. Nothing changed."
    }
}

// The plugins found in a repository (records like the plugins scan: "\x1e<path>\x1f<files>"
// then its plugin.json), checked with PluginManifest's parse (`parse(text, folder, files)`).
// The folder's own name may not be the plugin's id (`tailscale/` holds "tailscale", but a
// repository's root holds one too), so each is checked against the id its manifest gives.
//   -> { good: [{ path, plugin }], bad: [{ path, id, error, code }] }
function checkFound(records, parse) {
    var good = [], bad = []
    for (var i = 0; i < records.length; i++) {
        var r = records[i]
        var id = ""
        try {
            var m = JSON.parse(r.text)
            id = m && typeof m.id === "string" ? m.id : ""
        } catch (e) {
            id = ""
        }
        var folder = id !== "" ? id : (r.folder.split("/").pop() || r.folder)
        var p = parse(r.text, folder, r.files)
        if (p.ok)
            good.push({ path: r.folder, plugin: p.plugin })
        else
            bad.push({ path: r.folder, id: folder, error: p.error, code: p.code })
    }
    return { good: good, bad: bad }
}

// "Tailscale", "Services and Backups", "Services, Disks and Backups".
function namesText(names) {
    var n = names.filter(function (x) { return x !== "" })
    if (n.length <= 1)
        return n.join("")
    return n.slice(0, -1).join(", ") + " and " + n[n.length - 1]
}

// The install's outcome: "installed", "2 OF 3 INSTALLED", or not installed.
function installSummary(good, bad) {
    var total = good.length + bad.length
    if (good.length === 0)
        return { state: "failed", badge: "NOT INSTALLED", text: total === 0 ? "noplugin" : "none passed" }
    if (bad.length === 0)
        return { state: "done", badge: "", text: "" }
    return { state: "partial", badge: good.length + " OF " + total + " INSTALLED", text: "" }
}

// What a freshly installed plugin can do next (the "Installed" note): its bar entry and its
// widget are both off until the user puts them somewhere.
function nextSteps(plugin) {
    var out = []
    if (plugin.bar)
        out.push("bar")
    if (plugin.files && plugin.files.widget)
        out.push("widget")
    out.push("settings")
    return out
}

function kindText(plugin) {
    var b = !!plugin.bar, w = !!(plugin.files && plugin.files.widget)
    return b && w ? "a bar entry and a desktop widget" : b ? "a bar entry" : "a desktop widget"
}

// ===== updates =====

// The repositories with updates, the pinned ones left out (and counted), in name order.
//   -> { list: [{ key, behind, log, from, to }], pinnedSkipped }
function updates(check, lock) {
    var list = [], pinned = 0
    var keys = Object.keys(check || {}).sort()
    for (var i = 0; i < keys.length; i++) {
        var c = check[keys[i]]
        var r = lock && lock.repos ? lock.repos[keys[i]] : null
        if (!c || c.status !== "ok" || c.behind <= 0)
            continue
        if (r && r.pinned) {
            pinned++
            continue
        }
        list.push({ key: keys[i], behind: c.behind, log: c.log, from: c.head, to: c.upstream })
    }
    return { list: list, pinnedSkipped: pinned }
}

// The notice's id for a batch: the same commits never announce twice, new ones do.
function batchId(list) {
    return list.map(function (u) { return u.key + "@" + u.to }).sort().join(",")
}

// "2 repositories have updates", "1 repository has an update".
function updatesTitle(n) {
    if (n === 0)
        return "Everything is up to date"
    return n === 1 ? "1 repository has an update" : n + " repositories have updates"
}

// The notification's body: "Tailscale (3 commits) and someone/sekaipop-homelab (1)."
function noticeBody(list, nameOf) {
    var parts = list.map(function (u, i) {
        var n = nameOf ? nameOf(u.key) : u.key
        return n + " (" + u.behind + (i === 0 ? (u.behind === 1 ? " commit" : " commits") : "") + ")"
    })
    return namesText(parts) + ". Nothing changes until you update."
}

// ===== needs =====

// The programs an entry needs, checked: `found` is { name: true|false } from the shell
// (`plugin-repos.sh needs a b c`). -> [{ name, ok }], and whether any is missing.
function needsChecked(needs, found) {
    var out = (needs || []).map(function (n) { return { name: n, ok: !!(found && found[n]) } })
    return { list: out, missing: out.filter(function (n) { return !n.ok }).map(function (n) { return n.name }) }
}

// "2 days ago" for the cached list's age.
function ageText(then, now) {
    var s = Math.max(0, Math.floor((now - then) / 1000))
    if (s < 60)
        return "just now"
    if (s < 3600)
        return Math.floor(s / 60) + " min ago"
    if (s < 86400)
        return Math.floor(s / 3600) + " h ago"
    var d = Math.floor(s / 86400)
    return d === 1 ? "yesterday" : d + " days ago"
}
