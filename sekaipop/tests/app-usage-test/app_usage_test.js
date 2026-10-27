// The Apps screen's "Most used" order: the rules (modules/common/functions/AppUsage.js,
// loaded for real) and the wiring around them (read from the source, since node cannot
// load QML).
//   node tests/app-usage-test/app_usage_test.js   (run from the sekaipop folder)
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const root = path.join(__dirname, "..", "..")
const read = f => fs.readFileSync(path.join(root, f), "utf8")
const src = read("modules/common/functions/AppUsage.js").replace(".pragma library", "")
const AU = new Function(src + "\nreturn { HALF_LIFE_DAYS, DAY_MS, MAX_APPS, FORGOTTEN, scoreAt, record, prune, parse, order }")()

const DAY = AU.DAY_MS
const T0 = Date.UTC(2026, 9, 1)
const entry = (key, idx) => ({ key, idx })
const az = [entry("alacritty.desktop", 0), entry("firefox.desktop", 1), entry("gimp.desktop", 2), entry("vesktop.desktop", 3)]
const keys = list => list.map(e => e.key)

// ----- scores -----
assert.strictEqual(AU.scoreAt(undefined, T0), 0, "an app never opened scores 0")
let u = AU.record({}, "firefox.desktop", T0)
assert.strictEqual(AU.scoreAt(u["firefox.desktop"], T0), 1, "one launch is 1")
assert.ok(Math.abs(AU.scoreAt(u["firefox.desktop"], T0 + AU.HALF_LIFE_DAYS * DAY) - 0.5) < 1e-9, "halves after the half-life")
u = AU.record(u, "firefox.desktop", T0)
assert.strictEqual(AU.scoreAt(u["firefox.desktop"], T0), 2, "launches add up")
const before = JSON.stringify(u)
AU.record(u, "gimp.desktop", T0)
assert.strictEqual(JSON.stringify(u), before, "record() leaves the store it was given alone")
assert.deepStrictEqual(AU.record(u, "", T0), u, "no id, nothing counted")

// ----- order -----
assert.deepStrictEqual(keys(AU.order(az, {}, T0)), keys(az), "nothing used: A to Z")
let use = {}
for (let i = 0; i < 3; i++) use = AU.record(use, "vesktop.desktop", T0)
use = AU.record(use, "gimp.desktop", T0)
assert.deepStrictEqual(keys(AU.order(az, use, T0)),
    ["vesktop.desktop", "gimp.desktop", "alacritty.desktop", "firefox.desktop"],
    "most used first, the unused after them A to Z")
const ordered = AU.order(az, use, T0)
assert.ok(ordered.every(e => az.includes(e)), "the same objects come back (the grid keeps its tiles)")
assert.deepStrictEqual(keys(az), ["alacritty.desktop", "firefox.desktop", "gimp.desktop", "vesktop.desktop"], "the A to Z list isn't sorted in place")

// An app opened daily for a month, then dropped, sinks below one opened daily this week.
let drift = {}
for (let d = 0; d < 30; d++) drift = AU.record(drift, "gimp.desktop", T0 + d * DAY)
for (let d = 60; d < 67; d++) drift = AU.record(drift, "firefox.desktop", T0 + d * DAY)
assert.strictEqual(AU.order(az, drift, T0 + 67 * DAY)[0].key, "firefox.desktop", "recent use beats old use")
// The order is the same whenever it is asked (every score decays alike), so it needs no timer.
assert.deepStrictEqual(keys(AU.order(az, drift, T0 + 67 * DAY)), keys(AU.order(az, drift, T0 + 400 * DAY)),
    "the order doesn't drift with time on its own")

// ----- pruning -----
const old = AU.record({}, "gimp.desktop", T0)
assert.ok(!("gimp.desktop" in AU.record(old, "firefox.desktop", T0 + 200 * DAY)), "a long-forgotten app is dropped")
let many = {}
for (let i = 0; i < AU.MAX_APPS + 20; i++) many = AU.record(many, "app" + i + ".desktop", T0 + i)
assert.strictEqual(Object.keys(many).length, AU.MAX_APPS, "the store is capped")
assert.ok("app" + (AU.MAX_APPS + 19) + ".desktop" in many, "the newest launch survives the cap")

// ----- reading the file -----
assert.deepStrictEqual(AU.parse(JSON.stringify(use)), use, "the saved store reads back")
assert.deepStrictEqual(AU.parse(""), {}, "no file: empty")
assert.deepStrictEqual(AU.parse("{not json"), {}, "a broken file: empty, not an error")
assert.deepStrictEqual(AU.parse("[1,2]"), {}, "not an object: empty")
assert.deepStrictEqual(AU.parse('{"a":{"s":"x","t":1},"b":{"s":2,"t":5},"c":null}'), { b: { s: 2, t: 5 } }, "bad records are skipped")

// ----- wiring -----
const appSource = read("services/AppSource.qml")
assert.ok(/function launch\(app\)[\s\S]*?app\.execute\(\)[\s\S]*?root\.recordLaunch\(app\)/.test(appSource), "a launch is counted")
assert.ok(/root\.byUse \? AU\.order\(/.test(appSource), "the order follows the setting")
assert.ok(/usageDirty[\s\S]*?_usageRev\+\+/.test(appSource.slice(appSource.indexOf("function sync()"))), "the order moves on when the Apps screen opens")
assert.ok(!/function recordLaunch[\s\S]*?_usageRev\+\+[\s\S]*?\n    }/.test(appSource), "a launch doesn't re-sort the grid there and then")
assert.ok(/face\.source\.ordered/.test(read("modules/sekai/launcher/LauncherFace.qml")), "the grid shows the ordered list")
assert.ok(/"launcher\.order": "az"/.test(read("services/SettingsService.qml")), "A to Z stays the default")
assert.ok(/SettingsService\.set\("launcher\.order", id\)/.test(read("modules/sekai/settings/SettingsPageGeneral.qml")), "Settings can change it")
assert.ok(fs.existsSync(path.join(root, "scripts/state/app-usage-state.sh")), "the state script is there")

console.log("app usage: all passed")
