// node tests/keybinds-test/keys_tap_unit.js   (run from the sekaipop folder)
// The Super tap that opens Apps is an ordinary action now: it is found in both config
// formats, can be turned off or moved to another modifier tap, and is written back as a
// `global` bind (not an `ipc call`).
const fs = require("fs")
const path = require("path")
const src = fs.readFileSync(path.join(__dirname, "../../modules/common/functions/KeyBinds.js"), "utf8").replace(".pragma library", "")
const KB = new Function(src + "; return { rows, edit, block, caps, showCombo, tapCombo, tapForMod, conflict, SUPER, ALT, CTRL, SHIFT }")()

let fails = 0
const eq = (a, b, msg) => { const x = JSON.stringify(a), y = JSON.stringify(b); if (x !== y) { fails++; console.log("FAIL " + msg + "\n   got  " + x + "\n   want " + y) } }
const has = (text, part, msg) => { if (!text.includes(part)) { fails++; console.log("FAIL " + msg + "\n   missing " + part + "\n   in\n" + text) } }

const lua = (key, modmask, description) => ({ dispatcher: "__lua", arg: "1", key, modmask, keycode: 0,
    has_description: true, description, submap: "", mouse: false, locked: false })
const luaBinds = [lua("SUPER_L", KB.SUPER, "Shell: Apps"), lua("SUPER_R", KB.SUPER, "Shell (more): Apps"), lua("A", KB.SUPER, "Shell: Toggle apps")]
const rs = KB.rows(luaBinds, {})
const tap = rs.find(r => r.id === "appstap")
eq(tap.tap, true, "the row knows it is a tap")
eq(tap.combos.map(c => c.key), ["SUPER_L", "SUPER_R"], "both Super keys (the shipped description says Apps)")
eq(rs.find(r => r.id === "launcherphone").combos.map(c => c.key), ["A"], "Toggle apps is not the tap")

const confBinds = [{ dispatcher: "global", arg: "quickshell:searchToggleRelease", key: "SUPER_L", modmask: KB.SUPER,
    keycode: 0, has_description: false, description: "", submap: "", mouse: false, locked: false }]
eq(KB.rows(confBinds, {}).find(r => r.id === "appstap").combos.length, 1, "a hyprland.conf global bind is found")

eq(KB.caps({ mods: KB.SUPER, key: "SUPER_L" }), [{ k: "SUPER tap", mod: true }], "one cap for a tap")
eq(KB.showCombo({ mods: KB.ALT, key: "ALT_L" }), "ALT tap", "text for a tap")
eq(KB.tapCombo(0x01000022), { mods: KB.SUPER, key: "SUPER_L" }, "Qt's Meta is the Super tap")
eq(KB.tapForMod(KB.CTRL), { mods: KB.CTRL, key: "CONTROL_L" }, "a Ctrl tap")
eq(KB.tapForMod(KB.SHIFT), null, "Shift cannot be tapped")
eq(KB.conflict(luaBinds, { mods: KB.SUPER, key: "SUPER_L" }, "appstap", rs), null, "its own keys are not a conflict")

// turned off
const off = KB.edit({}, rs, "appstap", null, null)
const offLua = KB.block(off, "lua")
has(offLua, "pcall(hl.unbind, [==[SUPER + SUPER_L]==])", "the Super tap is unbound")
has(offLua, "pcall(hl.unbind, [==[SUPER + SUPER_R]==])", "the right Super too")
eq(offLua.includes("hl.bind"), false, "nothing is bound in its place")

// moved to an Alt tap
const alt = KB.edit({}, rs, "appstap", KB.tapForMod(KB.ALT), null)
const altLua = KB.block(alt, "lua")
has(altLua, "hl.dsp.global([==[quickshell:searchToggleRelease]==])", "written as a global bind")
has(altLua, "[==[ALT + ALT_L]==]", "on the Alt tap")
has(altLua, "[==[Shell: Open apps]==]", "with the action's own description")
has(altLua, "{ release = true, description = [==[Shell: Open apps]==] }", "a release bind, so a chord with Alt does not open Apps (issue #99)")
eq(altLua.includes("exec_cmd"), false, "never as an ipc call")
const back = KB.rows([lua("ALT_L", KB.ALT, "Shell: Open apps")], alt).find(r => r.id === "appstap")
eq(back.combos, [{ mods: KB.ALT, key: "ALT_L" }], "the new description is found again")
const altConf = KB.block(alt, "conf")
has(altConf, "bindrd = ALT, ALT_L, Shell: Open apps, global, quickshell:searchToggleRelease", "the hyprland.conf line, a release bind")
has(altConf, "unbind = SUPER, SUPER_L", "the old tap is unbound in hyprland.conf")
eq(KB.edit(alt, KB.rows([lua("ALT_L", KB.ALT, "Shell: Open apps")], alt), "appstap", { mods: KB.SUPER, key: "SUPER_L" }, null).appstap !== undefined, true, "a different tap than the shipped pair is still a change")

// only a tap is a release bind
const plain = KB.block(KB.edit({}, rs, "launcherphone", { mods: KB.SUPER | KB.ALT, key: "A" }, null), "lua")
eq(plain.includes("release = true"), false, "an ordinary key fires on press, as before")
eq(KB.block(KB.edit({}, rs, "launcherphone", { mods: KB.SUPER | KB.ALT, key: "A" }, null), "conf").includes("bindrd"), false, "in hyprland.conf too")

console.log(fails === 0 ? "ok" : fails + " failed")
process.exit(fails === 0 ? 0 : 1)
