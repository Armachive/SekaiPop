// Getting and updating plugins (services/PluginRepoService.qml, docs/PLUGIN-INSTALL.md): the
// rules in modules/common/functions/PluginRepos.js, run in node, plus the reviewed list at the
// repository's root checked against the README's list.
// Run: node repos_unit.js
const fs = require("fs"), path = require("path"), assert = require("assert")
const PR = require("../lib/pluginrepos")
const PM = require("../lib/pluginmanifest")
const NOW = Date.parse("2026-10-29T22:00:00Z")

// ---------- the list ----------
let l = PR.parseList(JSON.stringify([
    { repo: "masshirodev/sekaipop-tailscale", description: " Tailscale. ", tags: ["Bar", "widget", "bar", 3], needs: ["tailscale", ""], sekaipop: "1.0.0" },
    { repo: "a/b" },
    { repo: "not a repo" },
    { repo: "A/B", description: "a duplicate, differently cased" },
    "junk"
]))
assert.strictEqual(l.ok, true)
assert.deepStrictEqual(l.entries.map(e => e.repo), ["a/b", "masshirodev/sekaipop-tailscale"], "sorted, bad and duplicate entries left out")
assert.deepStrictEqual(l.entries[1], { repo: "masshirodev/sekaipop-tailscale", description: "Tailscale.", tags: ["bar", "widget"], needs: ["tailscale"], sekaipop: "1.0.0" })
assert.deepStrictEqual(PR.parseList('{"plugins": [{"repo": "x/y"}]}').entries.map(e => e.repo), ["x/y"], "or an object with `plugins`")
assert.strictEqual(PR.parseList("nope").ok, false)
assert.strictEqual(PR.parseList("{}").ok, false)

// search: names, words, tags (tags are marked)
const entries = PR.parseList(JSON.stringify([
    { repo: "someone/sekaipop-pomodoro", description: "A focus timer in the bar", tags: ["bar", "focus"] },
    { repo: "someone/sekaipop-mpd", description: "Your MPD queue as a widget", tags: ["widget", "music"] },
    { repo: "masshirodev/sekaipop-tailscale", description: "Your tailnet", tags: ["bar", "widget", "network"] }
])).entries
const found = q => PR.search(entries, q).map(r => r.entry.repo)
assert.deepStrictEqual(found(""), entries.map(e => e.repo), "an empty search is the whole list")
assert.deepStrictEqual(found("bar"), ["masshirodev/sekaipop-tailscale", "someone/sekaipop-pomodoro"])
assert.deepStrictEqual(PR.search(entries, "bar").map(r => r.hits), [["bar"], ["bar"]], "the tag that matched is marked")
assert.deepStrictEqual(found("queue"), ["someone/sekaipop-mpd"], "a word of the description")
assert.deepStrictEqual(found("tail zzz"), [], "every word has to match")
assert.deepStrictEqual(found("MUS"), ["someone/sekaipop-mpd"], "a tag's start, any case")

// versions
assert.strictEqual(PR.versionAtLeast("1.2.0", "1.0.0"), true)
assert.strictEqual(PR.versionAtLeast("1.2.0", "1.4.0"), false)
assert.strictEqual(PR.versionAtLeast("1.10.0", "1.9.9"), true, "numbers, not text")
assert.strictEqual(PR.versionAtLeast("1.2", "1.2.0"), true)
assert.strictEqual(PR.versionAtLeast("2.0.0-beta", "2.0.0"), true)
assert.strictEqual(PR.versionAtLeast("1.0.0", ""), true, "no minimum")

// ---------- a source the user typed ----------
const src = s => { const r = PR.source(s); return r.ok ? [r.key, r.url, r.github] : r.error }
assert.deepStrictEqual(src("someone/sekaipop-mpd"), ["someone/sekaipop-mpd", "https://github.com/someone/sekaipop-mpd.git", true])
assert.deepStrictEqual(src(" https://github.com/someone/sekaipop-mpd.git/ "), ["someone/sekaipop-mpd", "https://github.com/someone/sekaipop-mpd.git", true])
assert.deepStrictEqual(src("github.com/someone/x"), ["someone/x", "https://github.com/someone/x.git", true])
assert.deepStrictEqual(src("git@github.com:someone/x.git"), ["someone/x", "https://github.com/someone/x.git", true])
assert.deepStrictEqual(src("https://codeberg.org/me/thing.git"), ["codeberg.org/me/thing", "https://codeberg.org/me/thing.git", false])
assert.match(src(""), /owner\/repo/)
assert.match(src("just words"), /isn't owner\/repo/)
assert.match(src("https://evil.example/../../etc"), /isn't owner\/repo/, "nothing that climbs out of the repos folder")

// ---------- where a plugin came from ----------
const R = "/home/u/.local/share/sekaipop/plugin-repos"
assert.deepStrictEqual(PR.origin(R + "/o/r/tailscale", R), { kind: "repo", repo: "o/r", path: "tailscale" })
assert.deepStrictEqual(PR.origin(R + "/o/r", R + "/"), { kind: "repo", repo: "o/r", path: "" }, "a plugin at the root of its repository")
assert.deepStrictEqual(PR.origin("/home/u/projects/x/y", R), { kind: "yours", path: "/home/u/projects/x/y" })
assert.deepStrictEqual(PR.origin("", R), { kind: "copied" })
let lock = PR.withInstall(PR.emptyLock(), "codeberg.org/me/thing", { url: "u", commit: "c1", plugins: ["thing"] }, NOW)
assert.deepStrictEqual(PR.repoOf(R + "/codeberg.org/me/thing/sub", R, lock), { kind: "repo", repo: "codeberg.org/me/thing", path: "sub" }, "a longer key, found by the lockfile")

const g = PR.groups([
    { id: "services", target: R + "/someone/homelab/services" },
    { id: "backups", target: R + "/someone/homelab/backups" },
    { id: "tailscale", target: "/home/u/projects/sekaipop-tailscale/tailscale" },
    { id: "hello", target: "" },
    { id: "alpha", target: R + "/a/alpha" }
], [{ id: "disks", target: R + "/someone/homelab/disks" }, { id: "stray", target: "" }], R,
    PR.withInstall(PR.emptyLock(), "gone/away", { commit: "c" }, NOW))
assert.deepStrictEqual(g.map(x => [x.kind, x.repo || "", (x.plugins || []).map(p => p.id), (x.skipped || []).map(p => p.id)]), [
    ["repo", "a/alpha", ["alpha"], []],
    ["repo", "gone/away", [], []],
    ["repo", "someone/homelab", ["services", "backups"], ["disks"]],
    ["yours", "", ["tailscale"], []],
    ["copied", "", ["hello"], []]
], "repositories by name (one whose plugins went missing still shows), then yours, then copied; a skipped plugin stays with its repository")

// ---------- the lockfile ----------
assert.deepStrictEqual(PR.readLock("garbage"), PR.emptyLock())
assert.deepStrictEqual(PR.readLock('{"repos": {"a/b": {"nocommit": 1}, "c/d": {"commit": "x", "pinned": "yes", "plugins": ["p", 2]}}}'),
    { version: 1, repos: { "c/d": { url: "", commit: "x", previous: "", pinned: false, reviewed: false, installed: 0, updated: 0, plugins: ["p"] } } })
lock = PR.withInstall(PR.emptyLock(), "o/r", { url: "https://github.com/o/r.git", commit: "aaa", reviewed: true, plugins: ["p"] }, NOW)
assert.deepStrictEqual(lock.repos["o/r"], { url: "https://github.com/o/r.git", commit: "aaa", previous: "", pinned: false, reviewed: true, installed: NOW, updated: NOW, plugins: ["p"] })
let l2 = PR.withCommit(lock, "o/r", "bbb", NOW + 1)
assert.deepStrictEqual([l2.repos["o/r"].commit, l2.repos["o/r"].previous, l2.repos["o/r"].updated], ["bbb", "aaa", NOW + 1])
assert.strictEqual(lock.repos["o/r"].commit, "aaa", "a change makes a new lock, the old one is left alone")
let l3 = PR.withCommit(l2, "o/r", "aaa", NOW + 2)
assert.deepStrictEqual([l3.repos["o/r"].commit, l3.repos["o/r"].previous], ["aaa", "bbb"], "going back swaps the two, so Go back twice undoes itself")
assert.deepStrictEqual(PR.withCommit(l3, "o/r", "aaa", NOW + 3), l3, "the same commit changes nothing")
assert.deepStrictEqual(PR.withCommit(l3, "x/y", "c", NOW), l3, "an unknown repository changes nothing")
assert.strictEqual(PR.withPin(lock, "o/r", true).repos["o/r"].pinned, true)
assert.deepStrictEqual(PR.withPin(lock, "x/y", true), lock)
assert.deepStrictEqual(PR.withPlugins(lock, "o/r", ["p", "q"]).repos["o/r"].plugins, ["p", "q"])
assert.deepStrictEqual(PR.withoutRepo(lock, "o/r"), PR.emptyLock())

// ---------- what the git side prints ----------
assert.deepStrictEqual(PR.parseKv("status=ok\ncommit=abc\nnoise\n=x"), { status: "ok", commit: "abc" })
assert.deepStrictEqual(PR.parseCommit("4f2c1ab|Bar: a|b subject|2 days ago"), { hash: "4f2c1ab", subject: "Bar: a|b subject", age: "2 days ago" })
assert.strictEqual(PR.parseCommit("short"), null)
const chk = PR.parseCheck("\x1eo/r\nstatus=ok\nhead=aaa\nupstream=ccc\nbehind=2\nlog=ccc|Two|1 hour ago\nlog=bbb|One|2 hours ago\nlog=bad\n"
    + "\x1ex/y\nstatus=offline\n\x1e\nstatus=ok\n")
assert.deepStrictEqual(chk["o/r"], { status: "ok", behind: 2, head: "aaa", upstream: "ccc", reason: "",
    log: [{ hash: "ccc", subject: "Two", age: "1 hour ago" }, { hash: "bbb", subject: "One", age: "2 hours ago" }] })
assert.strictEqual(chk["x/y"].status, "offline")
assert.deepStrictEqual(Object.keys(chk), ["o/r", "x/y"], "a record with no key is dropped")
assert.deepStrictEqual(["Counting objects: 100% (5/5)", "Compressing objects:  40% (2/5)", "Receiving objects:  62% (31/50)",
    "Resolving deltas: 100% (3/3)", "Cloning into 'x'..."].map(PR.cloneProgress), [5, 7, 60, 100, null])
assert.match(PR.failure("offline", "someone/sekaipop-mpd"), /Couldn't reach github.com: you're offline/)
assert.match(PR.failure("offline", "codeberg.org/me/x"), /Couldn't reach codeberg.org/)
assert.match(PR.failure("norepo", "someone/sekaipop-mdp"), /no repository at github.com\/someone\/sekaipop-mdp, or it's private/)
assert.match(PR.failure("noplugin", "someone/dotfiles"), /someone\/dotfiles isn't a SekaiPop plugin/)
assert.match(PR.failure("exists", "a/b"), /already installed/)
assert.match(PR.failure("nogit", "a/b"), /needs git/)
assert.strictEqual(PR.failure("fatal: weird", "a/b"), "fatal: weird")
assert.match(PR.failure("", "a/b"), /didn't install/)

// checking what a repository holds, with the manifest's own rules
const man = (id, extra) => JSON.stringify(Object.assign({ id: id, name: id[0].toUpperCase() + id.slice(1), version: "1.0.0", api: 1 }, extra || {}))
const recs = PM.splitScan("\x1eservices\x1fWidget.qml\n" + man("services") + "\x1edisks\x1fWidget.qml\n{broken"
    + "\x1e\x1fBar.qml\n" + man("rootplug", { bar: { label: "R" } }), true)
assert.strictEqual(PM.splitScan("\x1e\x1fBar.qml\n{}").length, 0, "the plugins scan has no root record")
const checked = PR.checkFound(recs, PM.parse)
assert.deepStrictEqual(checked.good.map(x => [x.path, x.plugin.id]), [["services", "services"], ["", "rootplug"]], "a plugin at the repository's root is named by its manifest")
assert.deepStrictEqual(checked.bad.map(x => [x.path, x.id, x.code]), [["disks", "disks", "json"]])
assert.deepStrictEqual(PR.installSummary(checked.good, checked.bad), { state: "partial", badge: "2 OF 3 INSTALLED", text: "" })
assert.strictEqual(PR.installSummary(checked.good, []).state, "done")
assert.deepStrictEqual(PR.installSummary([], checked.bad), { state: "failed", badge: "NOT INSTALLED", text: "none passed" })
assert.strictEqual(PR.installSummary([], []).text, "noplugin")
assert.strictEqual(PR.namesText(["Services", "Disks", "Backups"]), "Services, Disks and Backups")
assert.strictEqual(PR.namesText(["Services", "Backups"]), "Services and Backups")
assert.strictEqual(PR.namesText(["Tailscale", ""]), "Tailscale")
const both = { bar: { label: "x" }, files: { widget: true } }
assert.deepStrictEqual(PR.nextSteps(both), ["bar", "widget", "settings"])
assert.deepStrictEqual(PR.nextSteps({ bar: null, files: { widget: true } }), ["widget", "settings"])
assert.deepStrictEqual([PR.kindText(both), PR.kindText({ bar: {}, files: {} }), PR.kindText({ files: { widget: true } })],
    ["a bar entry and a desktop widget", "a bar entry", "a desktop widget"])

// ---------- updates and the notice ----------
const ul = PR.withPin(PR.withInstall(PR.withInstall(PR.emptyLock(), "o/r", { commit: "a" }, NOW), "p/q", { commit: "b" }, NOW), "p/q", true)
const up = PR.updates(Object.assign({}, chk, { "p/q": { status: "ok", behind: 4, head: "b", upstream: "d", log: [] }, "z/z": { status: "ok", behind: 0, log: [] } }), ul)
assert.deepStrictEqual(up.list.map(u => [u.key, u.behind, u.from, u.to]), [["o/r", 2, "aaa", "ccc"]], "pinned and current ones are not updates")
assert.strictEqual(up.pinnedSkipped, 1, "a pinned one is counted, so the screen can say updates skip it")
assert.strictEqual(PR.batchId([{ key: "b", to: "2" }, { key: "a", to: "1" }]), "a@1,b@2", "the same commits are the same batch, in any order")
assert.deepStrictEqual([0, 1, 2].map(PR.updatesTitle), ["Everything is up to date", "1 repository has an update", "2 repositories have updates"])
assert.strictEqual(PR.noticeBody([{ key: "masshirodev/sekaipop-tailscale", behind: 3 }, { key: "someone/sekaipop-homelab", behind: 1 }],
    k => k === "masshirodev/sekaipop-tailscale" ? "Tailscale" : k),
    "Tailscale (3 commits) and someone/sekaipop-homelab (1). Nothing changes until you update.", "the handoff's notice")
assert.strictEqual(PR.noticeBody([{ key: "a/b", behind: 1 }]), "a/b (1 commit). Nothing changes until you update.")

// ---------- needs, ages ----------
assert.deepStrictEqual(PR.needsChecked(["tailscale", "wl-copy"], { tailscale: true }), { list: [{ name: "tailscale", ok: true }, { name: "wl-copy", ok: false }], missing: ["wl-copy"] })
assert.deepStrictEqual(PR.needsChecked(undefined, {}), { list: [], missing: [] })
assert.deepStrictEqual([NOW - 5000, NOW - 600000, NOW - 7200000, NOW - 86400000, NOW - 2 * 86400000].map(t => PR.ageText(t, NOW)),
    ["just now", "10 min ago", "2 h ago", "yesterday", "2 days ago"])

// ---------- the reviewed list at the repository's root ----------
const root = path.join(__dirname, "..", "..", "..")
const list = PR.parseList(fs.readFileSync(path.join(root, "plugins.json"), "utf8"))
assert.strictEqual(list.ok, true, "plugins.json is a list of plugins")
const raw = JSON.parse(fs.readFileSync(path.join(root, "plugins.json"), "utf8"))
assert.strictEqual(list.entries.length, raw.length, "every entry in plugins.json is a good one")
assert.deepStrictEqual(raw.map(e => e.repo), list.entries.map(e => e.repo), "plugins.json is in order by repository")
for (const e of list.entries) {
    assert.ok(e.description.length > 0 && e.tags.length > 0, e.repo + " has a description and tags")
    assert.ok(/^\d+\.\d+\.\d+$/.test(e.sekaipop), e.repo + " says the oldest SekaiPop it works with")
}
// the README's list (between the plugin-list markers) names the same repositories
const readme = fs.readFileSync(path.join(root, "README.md"), "utf8")
const block = (readme.match(/<!-- plugin-list -->([\s\S]*?)<!-- \/plugin-list -->/) || [, ""])[1]
const named = [...block.matchAll(/https:\/\/github\.com\/([\w.-]+\/[\w.-]+)\)/g)].map(m => m[1]).sort()
assert.deepStrictEqual(named, list.entries.map(e => e.repo).sort(), "the README lists the same plugins as plugins.json")

console.log("repos_unit: all checks passed")
