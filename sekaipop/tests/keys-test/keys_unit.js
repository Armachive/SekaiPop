// node tests/keys-test/keys_unit.js   (run from the sekaipop folder)
// The keybinds panel: reading `hyprctl -j binds` into rows (hyprland.conf binds by their
// ipc call, Lua binds by their description), conflicts, the saved state across
// repeated changes, the lines written for both config formats, and key capture.
const fs = require("fs")
const locate = require("../lib/locate.js")
const src = fs.readFileSync(locate("modules/sekai/settings/KeyBinds.js"), "utf8").replace(".pragma library", "")
const KB = new Function(src + `; return { rows, conflict, edit, reset, block, readState,
    pauseCalls, resumeCalls, comboFromKeyEvent, needsModifier, keyFromText, showCombo, caps, matches, changedCount, ACTIONS,
    SUPER, SHIFT, CTRL, ALT }`)()

let fails = 0
function eq(a, b, msg) {
    const x = JSON.stringify(a), y = JSON.stringify(b)
    if (x !== y) { fails++; console.log("FAIL " + msg + "\n   got  " + x + "\n   want " + y) }
}
function ok(v, msg) { if (!v) { fails++; console.log("FAIL " + msg) } }

const { SUPER, SHIFT, CTRL, ALT } = KB
const QS = "qs -c sekaipop ipc call "
let n = 0
// A hyprland.conf bind: no description, the command is visible.
const conf = (key, modmask, arg, extra) => Object.assign({ dispatcher: "exec", arg, key, modmask,
    keycode: 0, has_description: false, description: "", submap: "", mouse: false, locked: false }, extra || {})
// A Lua bind: every one reports "__lua", the description says what it is.
const lua = (key, modmask, description) => ({ dispatcher: "__lua", arg: String(++n), key, modmask,
    keycode: 0, has_description: true, description, submap: "", mouse: false, locked: false })
const row = (rs, id) => rs.find(r => r.id === id)

// ----- reading hyprland.conf binds (the shape of a real one, fallbacks and all) -----
const confBinds = [
    conf("A", SUPER, QS + "launcherphone toggle"),
    conf("comma", SUPER, QS + "settings toggle"),
    conf("I", SUPER, QS + "settings toggle"),
    conf("L", SUPER, QS + "lock lock || swaylock"),
    conf("V", SUPER, QS + "launcherphone toggleMode clip"),
    conf("XF86AudioMute", 0, QS + "osd toggleMute || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    conf("M", SUPER | SHIFT, QS + "osd toggleMute"),
    conf("R", SUPER | CTRL, "pkill -x qs; sleep 0.5; ~/.config/myconf/scripts/sekaipop-start"),
    conf("E", SUPER, "dolphin"),
    conf("Q", SUPER, "killactive", { dispatcher: "killactive", arg: "" }),
    conf("Escape", 0, "reset", { dispatcher: "submap", submap: "resize" })
]
const rs = KB.rows(confBinds, {})
eq(rs.length, KB.ACTIONS.length, "one row per action")
eq(row(rs, "settings").combos, [{ mods: SUPER, key: "comma" }, { mods: SUPER, key: "I" }], "an action on two keys keeps both")
eq(row(rs, "lock").cmd, QS + "lock lock || swaylock", "the existing command (with its fallback) is kept")
eq(row(rs, "mute").combos, [{ mods: SUPER | SHIFT, key: "M" }], "hardware keys are not the action's keys")
eq(row(rs, "restart").combos.length, 1, "restart is recognised without an ipc call")
eq(row(rs, "launcherphone").combos, [{ mods: SUPER, key: "A" }], "toggle is not confused with toggleMode")
ok(row(rs, "visualizer").none && row(rs, "visualizer").bare, "a key-less action reads as none")
eq(row(rs, "settings").before, row(rs, "settings").combos, "unchanged: a reset gives back what is there")
ok(!row(rs, "quickpanel").changed, "nothing is changed without a saved state")

// ----- reading Lua binds -----
const luaBinds = [
    lua("N", SUPER, "Shell: Toggle quick panel"),
    lua("Slash", SUPER | SHIFT | ALT, "Shell (more): Welcome tour"),
    lua("Q", SUPER, "Windows: Close window"),
    lua("S", SUPER | SHIFT, "Utilities: Screen snip")
]
const lr = KB.rows(luaBinds, {})
eq(row(lr, "quickpanel").combos, [{ mods: SUPER, key: "N" }], "Lua binds are matched by description")
eq(row(lr, "welcome").combos, [{ mods: SUPER | SHIFT | ALT, key: "Slash" }], "a (more) description matches too")
eq(row(lr, "snip").cmd, "", "a Lua bind has no command to copy")

// Power options ship on SUPER + Escape; Keep Awake ships without a key (it was on SUPER + A,
// on top of Toggle apps, so opening Apps flipped it too).
const pr = KB.rows([lua("Escape", SUPER, "Shell: Toggle power options"), lua("A", SUPER, "Shell: Toggle apps")], {})
eq(row(pr, "power").combos, [{ mods: SUPER, key: "Escape" }], "power options is an action")
ok(row(pr, "keepawake").none && row(pr, "keepawake").bare, "Keep Awake ships without a key")
eq(KB.conflict([], { mods: SUPER, key: "A" }, "keepawake", pr).id, "launcherphone", "giving Keep Awake SUPER + A asks first")

// ----- conflicts -----
eq(KB.conflict(confBinds, { mods: SUPER, key: "v" }, "eq", rs),
    { kind: "action", id: "clipboard", name: "Clipboard history", combo: { mods: SUPER, key: "V" } },
    "another action's keys, case aside")
eq(KB.conflict(confBinds, { mods: SUPER, key: "E" }, "eq", rs),
    { kind: "hyprland", name: "exec dolphin", combo: { mods: SUPER, key: "E" } },
    "a Hyprland bind without a description is named by what it runs")
eq(KB.conflict(luaBinds, { mods: SUPER, key: "Q" }, "eq", lr).name, "Close window", "a Lua bind is named by its sentence")
eq(KB.conflict(confBinds, { mods: SUPER, key: "comma" }, "settings", rs), null, "an action's own keys are no conflict")
eq(KB.conflict(confBinds, { mods: 0, key: "Escape" }, "eq", rs), null, "binds inside a submap don't count")
eq(KB.conflict(confBinds, { mods: SUPER | 2, key: "A" }, "eq", rs).id, "launcherphone", "Caps Lock in the mask is ignored")

// ----- changing, and changing again -----
const r1 = { state: KB.edit({}, rs, "settings", { mods: SUPER | ALT, key: "S" }, null) }
eq(r1.state.settings.unbind.map(u => u.key), ["comma", "I"], "the first change remembers both original keys")
eq(r1.state.settings.bind, [{ mods: SUPER | ALT, key: "S" }], "and binds the new one")
eq(r1.state.settings.cmd, QS + "settings toggle", "with the existing command")

// What Hyprland would report after that change.
const after1 = confBinds.filter(b => !(b.arg === QS + "settings toggle"))
    .concat([conf("S", SUPER | ALT, QS + "settings toggle", { description: "Shell: Toggle settings", has_description: true })])
const rs1 = KB.rows(after1, r1.state)
ok(row(rs1, "settings").changed, "the row reads as changed")
eq(row(rs1, "settings").before.map(c => c.key), ["comma", "I"], "Default: shows what a reset gives back")
const r2 = KB.edit(r1.state, rs1, "settings", { mods: SUPER, key: "O" }, null)
eq(r2.settings.unbind.map(u => u.key), ["comma", "I"], "a second change still unbinds the originals, not the first change")
eq(r2.settings.bind, [{ mods: SUPER, key: "O" }], "and binds only the newest key")

// Back to exactly what the config had: nothing left to save.
const one = KB.rows([conf("A", SUPER, QS + "launcherphone toggle")], {})
let back = KB.edit({}, one, "launcherphone", { mods: SUPER | SHIFT, key: "A" }, null)
const oneAfter = KB.rows([conf("A", SUPER | SHIFT, QS + "launcherphone toggle")], back)
back = KB.edit(back, oneAfter, "launcherphone", { mods: SUPER, key: "A" }, null)
eq(back, {}, "changing a key back to the original drops the entry")

// No key at all.
const cleared = KB.edit({}, rs, "lock", null, null)
eq(cleared.lock, { unbind: [{ mods: SUPER, key: "L", took: false }], bind: [], cmd: QS + "lock lock || swaylock", locked: false },
    "leave without a key: the old key stays unbound, nothing is bound")

// A key-less action gets one: nothing to unbind, the default command.
const given = KB.edit({}, rs, "visualizer", { mods: SUPER | ALT, key: "V" }, null)
eq(given.visualizer, { unbind: [], bind: [{ mods: SUPER | ALT, key: "V" }], cmd: QS + "visualizer toggle", locked: false },
    "a bare action is bound with its default command")
const luaGiven = KB.edit({}, lr, "snip", { mods: 0, key: "Print" }, null)
eq(luaGiven.snip.cmd, QS + "region screenshot || grim -g \"$(slurp)\" - | wl-copy",
    "a Lua bind's command comes from the list (Lua hides it)")

// ----- taking keys over -----
const takeAction = KB.conflict(confBinds, { mods: SUPER, key: "V" }, "eq", rs)
const t1 = { state: KB.edit({}, rs, "eq", { mods: SUPER, key: "V" }, takeAction) }
eq(t1.state.clipboard.bind, [], "taking another action's keys leaves it without a key")
eq(t1.state.clipboard.unbind.map(u => u.key), ["V"], "and saves that, so the config's V stays off")
eq(t1.state.eq.bind, [{ mods: SUPER, key: "V" }], "while the action takes them")
const takeHypr = KB.conflict(confBinds, { mods: SUPER, key: "E" }, "eq", rs)
const t2 = KB.edit({}, rs, "eq", { mods: SUPER, key: "E" }, takeHypr)
eq(t2.eq.unbind.find(u => u.key === "E").took, true, "a taken Hyprland bind is marked as taken")
ok(KB.block(t2, "conf").includes("unbind = SUPER, E"), "and is switched off by the saved block")
const rsT = KB.rows(confBinds.filter(b => b.key !== "E"), t2)
eq(row(rsT, "eq").before, [], "Default: does not claim the taken bind")
const t3 = KB.edit(t2, rsT, "eq", { mods: SUPER | ALT, key: "Q" }, null)
ok(!KB.block(t3, "conf").includes("unbind = SUPER, E"), "moving on to other keys gives the taken bind back")
eq(t3.eq.unbind, [], "and nothing else is left switched off (eq had no key of its own here)")

// ----- reset -----
eq(KB.reset(t1.state, "clipboard"), { eq: t1.state.eq }, "reset drops one entry")
eq(KB.changedCount(t1.state), 2, "changed count")

// ----- the saved block -----
const st = r1.state
const luaBlock = KB.block(st, "lua")
ok(luaBlock.startsWith("-- sekaipop:keys:begin"), "Lua block starts with its marker")
ok(luaBlock.includes('pcall(hl.unbind, [==[SUPER + comma]==])'), "Lua unbind keeps the key's spelling")
ok(luaBlock.includes('pcall(hl.bind, [==[SUPER + ALT + S]==], hl.dsp.exec_cmd([==[' + QS + 'settings toggle]==]), { description = [==[Shell: Toggle settings]==] })'),
    "Lua bind line")
ok(luaBlock.trim().endsWith("-- sekaipop:keys:end"), "Lua block ends with its marker")
const confBlock = KB.block(st, "conf")
ok(confBlock.includes("unbind = SUPER, I"), "conf unbind")
ok(confBlock.includes("bindd = SUPER ALT, S, Shell: Toggle settings, exec, " + QS + "settings toggle"), "conf bind with a description")
const lockedBlock = KB.block(KB.edit({}, rs, "mute", { mods: SUPER, key: "F9" }, null), "conf")
ok(lockedBlock.includes("bindld = SUPER, F9, Media: Toggle mute, exec,"), "a locked action stays locked")
const hashBlock = KB.block({ eq: { unbind: [], bind: [{ mods: SUPER, key: "H" }], cmd: "notify-send '#1'", locked: false } }, "conf")
ok(hashBlock.includes("exec, notify-send '##1'"), "a # in a command is escaped for hyprland.conf")
eq(KB.block({}, "lua"), "", "nothing changed writes no block")
eq(KB.readState(luaBlock), st, "the Lua block reads back to the same state")
eq(KB.readState("before\n" + confBlock + "after\n"), st, "the conf block reads back from inside a file")
eq(KB.readState("# sekaipop:keys {broken"), {}, "a damaged state line reads as nothing")
eq(KB.readState(""), {}, "no file, no state")

// ----- pausing shortcuts -----
eq(KB.resumeCalls("conf"), [["dispatch", "submap", "reset"]], "resume")
ok(KB.pauseCalls("conf").some(c => c.join(" ") === "keyword bind , Escape, submap, reset"), "pausing keeps Escape as a way out")
ok(KB.pauseCalls("lua")[0][1].includes('hl.bind("Escape", hl.dsp.submap("reset"))'), "in Lua too")

// ----- key capture -----
const QT_SHIFT = 0x02000000, QT_CTRL = 0x04000000, QT_META = 0x10000000
eq(KB.comboFromKeyEvent(0x41, QT_META, 38), { mods: SUPER, key: "A" }, "Super+A")
eq(KB.comboFromKeyEvent(0x3f, QT_META | QT_SHIFT, 61), { mods: SUPER | SHIFT, key: "slash" }, "Shift+/ comes back as slash")
eq(KB.comboFromKeyEvent(0x21, QT_SHIFT | QT_CTRL, 10), { mods: SHIFT | CTRL, key: "1" }, "Shift+1 comes back as 1")
eq(KB.comboFromKeyEvent(0x01000034, 0, 71), { mods: 0, key: "F5" }, "F5")
eq(KB.comboFromKeyEvent(0x01000022, QT_META, 133), { mods: SUPER, key: "" }, "Super on its own is a modifier")
eq(KB.comboFromKeyEvent(0x01000020, 0, 50), { mods: SHIFT, key: "" }, "Shift pressed counts before Qt reports it")
eq(KB.comboFromKeyEvent(0xe7, QT_META, 47), { mods: SUPER, key: "code:47" }, "an unknown key is bound by its keycode")

// ----- what may be a shortcut on its own -----
ok(KB.needsModifier({ mods: 0, key: "A" }), "a bare letter would stop typing")
ok(KB.needsModifier({ mods: 0, key: "space" }), "so would space")
ok(!KB.needsModifier({ mods: 0, key: "Print" }), "Print on its own is fine (the mock puts Screen snip there)")
ok(!KB.needsModifier({ mods: 0, key: "F5" }), "so is a function key")
ok(!KB.needsModifier({ mods: SHIFT, key: "A" }), "any modifier makes a letter fine")

// ----- typing a key by hand -----
eq(["y", "7", "f5", "F12", "enter", "Tab", "/", "?", "pgup", "Page Down", "f25", "ç", "banana"].map(KB.keyFromText),
    ["Y", "7", "F5", "F12", "Return", "Tab", "slash", "slash", "Prior", "Next", "", "", ""],
    "typed names become Hyprland's key names; unknown ones become nothing")

// ----- showing and finding -----
eq(KB.showCombo({ mods: SUPER | CTRL | SHIFT, key: "t" }), "CTRL + SUPER + SHIFT + T", "modifier order and letter case")
eq(KB.showCombo({ mods: SUPER, key: "period" }), "SUPER + .", "punctuation shows as itself")
eq(KB.caps({ mods: ALT, key: "Return" }), [{ k: "ALT", mod: true }, { k: "Enter", mod: false }], "keycaps")
ok(KB.matches(row(rs, "clipboard"), "super v"), "find by keys")
ok(KB.matches(row(rs, "clipboard"), "clip"), "find by name")
ok(!KB.matches(row(rs, "clipboard"), "super x"), "every word must match")

if (fails) { console.log(fails + " failed"); process.exit(1) }
console.log("keys: all passed")
