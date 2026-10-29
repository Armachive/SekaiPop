// node tests/idle-test/idle_test.js   (run from the sekaipop folder)
// scripts/system/idle-config.sh against a throwaway config folder, with stand-ins for
// pgrep / pkill / setsid / systemctl / busctl so nothing reaches the real hypridle: what
// it writes for each set of times, that an unchanged write leaves the file and hypridle
// alone, and that `link` comments out an old hypridle.conf's listeners, keeps the rest
// and a copy, and adds the source line once. Plus the QML wiring around it.
const fs = require("fs"), os = require("os"), path = require("path")
const { spawnSync } = require("child_process")
const locate = require("../lib/locate.js")
const script = locate("scripts/system/idle-config.sh")
const top = path.dirname(locate("shell.qml"))
const repo = path.dirname(top)

let fails = 0, n = 0
function ok(cond, msg) { n++; if (!cond) { fails++; console.log("FAIL " + msg) } }
function eq(a, b, msg) {
    n++
    const x = JSON.stringify(a), y = JSON.stringify(b)
    if (x !== y) { fails++; console.log("FAIL " + msg + "\n   got  " + x + "\n   want " + y) }
}

// The hypridle.conf every install had before the times moved to the Settings.
const OLD = `$lock_cmd = qs -c sekaipop ipc call lock lock || pidof hyprlock || hyprlock

general {
    lock_cmd = $lock_cmd
    before_sleep_cmd = loginctl lock-session
}

listener {
    timeout = 300 # 5mins
    on-timeout = loginctl lock-session
}

listener {
    timeout = 600
    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'
    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
}
# my own note
`

const dirs = []
function setup(hypr) {
    const cfg = fs.mkdtempSync(path.join(os.tmpdir(), "sekaipop-idle-"))
    dirs.push(cfg)
    fs.mkdirSync(path.join(cfg, "hypr"))
    for (const [name, text] of Object.entries(hypr))
        fs.writeFileSync(path.join(cfg, "hypr", name), text)
    // Stand-ins: hypridle "runs" while the file `running` exists; every call is logged.
    const bin = path.join(cfg, "bin")
    fs.mkdirSync(bin)
    const stub = (name, body) => fs.writeFileSync(path.join(bin, name),
        `#!/bin/sh\necho "${name} $*" >> "${cfg}/calls"\n${body}\n`, { mode: 0o755 })
    stub("pgrep", `[ -f "${cfg}/running" ]`)
    stub("pkill", `rm -f "${cfg}/running"`)
    stub("setsid", `touch "${cfg}/running"`)
    stub("systemctl", "exit 1")
    stub("busctl", `echo 's "yes"'`)
    return cfg
}
const run = (cfg, ...args) => {
    const r = spawnSync("sh", [script, ...args], {
        env: { HOME: cfg, XDG_CONFIG_HOME: cfg, PATH: path.join(cfg, "bin") + ":/usr/bin:/bin" }, encoding: "utf8" })
    return { code: r.status, out: r.stdout, err: r.stderr }
}
const read = (cfg, rel) => fs.readFileSync(path.join(cfg, rel), "utf8")
const exists = (cfg, rel) => fs.existsSync(path.join(cfg, rel))
const calls = cfg => exists(cfg, "calls") ? read(cfg, "calls") : ""
const clearCalls = cfg => fs.rmSync(path.join(cfg, "calls"), { force: true })
const listeners = text => (text.match(/^listener \{/gm) || []).length

try {
    // ---- write: the out-of-the-box times, Lua config ----
    let c = setup({ "hyprland.lua": "-- x\n" })
    let r = run(c, "write", "300", "600", "900", "suspend")
    eq([r.code, r.out], [0, "changed=yes\n"], "the first write writes")
    let f = read(c, "sekaipop/idle.conf")
    eq(listeners(f), 3, "three listeners")
    ok(/timeout = 300\n    on-timeout = loginctl lock-session/.test(f), "lock at 300 s through loginctl")
    ok(f.includes(`timeout = 600\n    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'`), "screen off at 600 s, Lua dispatcher")
    ok(f.includes(`on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'`), "screen back on at resume")
    ok(/timeout = 900\n    on-timeout = systemctl suspend \|\| loginctl suspend/.test(f), "suspend at 900 s")
    eq(calls(c), "", "unlinked (no hypridle.conf): hypridle isn't touched")

    r = run(c, "write", "300", "600", "900", "suspend")
    eq(r.out, "changed=no\n", "the same times again change nothing")

    // ---- write: Never, hibernate, hyprland.conf ----
    c = setup({ "hyprland.conf": "# x\n" })
    run(c, "write", "0", "120", "0", "hibernate")
    f = read(c, "sekaipop/idle.conf")
    eq(listeners(f), 1, "0 = never: only the screen-off listener")
    ok(!f.includes("lock-session") && !f.includes("hibernate ||"), "no lock, no sleep")
    ok(f.includes("on-timeout = hyprctl dispatch dpms off") && f.includes("on-resume = hyprctl dispatch dpms on"),
        "hyprland.conf: the old dpms words")
    run(c, "write", "0", "0", "1800", "hibernate")
    f = read(c, "sekaipop/idle.conf")
    ok(/timeout = 1800\n    on-timeout = systemctl hibernate \|\| loginctl hibernate/.test(f), "hibernate at 1800 s")
    run(c, "write", "0", "0", "0", "suspend")
    eq(listeners(read(c, "sekaipop/idle.conf")), 0, "all never: no listeners at all")

    eq(run(c, "write", "5", "x", "0", "suspend").code, 2, "a time that isn't a number is refused")
    eq(run(c, "write", "5", "0", "0", "doze").code, 2, "an unknown sleep action is refused")
    eq(run(c, "write", "5", "0").code, 2, "missing times are refused")

    // ---- status ----
    c = setup({})
    eq(run(c, "status").out, `linked=missing\nrunning=no\nhibernate=yes\nfile=${c}/sekaipop/idle.conf\n`, "status with no hypridle.conf")
    fs.writeFileSync(path.join(c, "hypr", "hypridle.conf"), OLD)
    fs.writeFileSync(path.join(c, "running"), "")
    eq(run(c, "status").out.split("\n").slice(0, 2), ["linked=no", "running=yes"], "an old hypridle.conf isn't linked")

    // ---- link: an old hypridle.conf ----
    run(c, "write", "300", "600", "900", "suspend")
    eq(calls(c).includes("pkill"), false, "writing while unlinked doesn't restart hypridle")
    clearCalls(c)
    r = run(c, "link")
    eq(r.code, 0, "link works")
    let h = read(c, "hypr/hypridle.conf")
    eq(h.match(/^listener \{/gm), null, "no listener block is left live")
    eq((h.match(/^# sekaipop-idle: /gm) || []).length, 9, "both listener blocks, every line, commented out")
    ok(h.includes("general {\n    lock_cmd = $lock_cmd") && h.includes("# my own note"), "the general block and other lines stay")
    ok(h.includes(`\nsource = ${c}/sekaipop/idle.conf\n`), "the source line is added")
    eq(read(c, "hypr/hypridle.conf.sekaipop-bak"), OLD, "the old file is kept as it was")
    eq(run(c, "status").out.split("\n")[0], "linked=yes", "linked afterwards")
    ok(/pkill -x hypridle[\s\S]*setsid -f hypridle/.test(calls(c)), "hypridle is restarted, old one first")

    fs.writeFileSync(path.join(c, "hypr", "hypridle.conf.sekaipop-bak"), "kept\n")
    run(c, "link")
    eq((read(c, "hypr/hypridle.conf").match(/^source = /gm) || []).length, 1, "a second link doesn't add a second source line")
    eq(read(c, "hypr/hypridle.conf.sekaipop-bak"), "kept\n", "nor replace the copy")

    // Linked: a change restarts hypridle, the same times don't.
    clearCalls(c)
    run(c, "write", "300", "600", "900", "suspend")
    eq(calls(c), "", "unchanged times leave hypridle alone")
    run(c, "write", "600", "600", "900", "suspend")
    ok(/setsid -f hypridle/.test(calls(c)), "changed times restart hypridle")
    clearCalls(c)
    fs.rmSync(path.join(c, "running"))
    run(c, "write", "900", "600", "900", "suspend")
    ok(!calls(c).includes("setsid"), "a hypridle that isn't running isn't started")

    // ---- link: no hypridle.conf, a symlinked one ----
    c = setup({})
    eq(run(c, "link").code, 0, "link with no hypridle.conf")
    h = read(c, "hypr/hypridle.conf")
    ok(h.includes("lock_cmd = qs -c sekaipop ipc call lock lock") && h.includes("before_sleep_cmd = loginctl lock-session"),
        "it makes the general block")
    eq(run(c, "status").out.split("\n")[0], "linked=yes", "and links it")
    ok(!exists(c, "hypr/hypridle.conf.sekaipop-bak"), "nothing to keep a copy of")

    c = setup({ "mine.conf": OLD })
    fs.symlinkSync(path.join(c, "hypr", "mine.conf"), path.join(c, "hypr", "hypridle.conf"))
    r = run(c, "link")
    eq(r.code, 1, "a symlinked hypridle.conf is refused")
    ok(r.err.includes("source = "), "and says what to add")
    eq(read(c, "hypr/mine.conf"), OLD, "and left alone")

    // ---- the shipped hypridle.conf reads the file and has no times of its own ----
    const shipped = fs.readFileSync(path.join(repo, "hypr", "hypridle.conf"), "utf8")
    c = setup({ "hypridle.conf": shipped })
    eq(run(c, "status").out.split("\n")[0], "linked=yes", "the shipped hypridle.conf is linked")
    eq(shipped.match(/^\s*listener/gm), null, "the shipped hypridle.conf has no listeners")
    ok(/^source = ~\/\.config\/sekaipop\/idle\.conf$/m.test(shipped), "it sources ~/.config/sekaipop/idle.conf")

    // ---- the QML around it ----
    const settings = fs.readFileSync(path.join(top, "services", "SettingsService.qml"), "utf8")
    for (const [k, v] of [["idle.lock", "5"], ["idle.screenOff", "10"], ["idle.sleep", "15"], ["idle.sleepAction", '"suspend"']])
        ok(new RegExp(`"${k.replace(".", "\\.")}": ${v},`).test(settings), k + " defaults to " + v + " (the old hypridle.conf's times)")
    const presets = fs.readFileSync(path.join(top, "services", "DesktopPresetService.qml"), "utf8")
    ok(/keepPrefix: \[[^\]]*"idle\."/.test(presets), "presets never carry the idle times")
    ok(/IdleService\.ready/.test(fs.readFileSync(path.join(top, "shell.qml"), "utf8")), "shell.qml starts IdleService")
    const svc = fs.readFileSync(path.join(top, "services", "IdleService.qml"), "utf8")
    const m = /function args\(\) \{([\s\S]*?)\n    \}/.exec(svc)
    ok(m, "IdleService.args is there")
    const args = new Function("root", m[1])({ lockMinutes: 5, screenOffMinutes: 0, sleepMinutes: 15.4, sleepAction: "hibernate" })
    eq(args, ["300", "0", "900", "hibernate"], "minutes go to the script as whole seconds")
    const install = fs.readFileSync(path.join(repo, "install.sh"), "utf8")
    ok(/IDLE_SH=.*idle-config\.sh"/.test(install) && /"\$IDLE_SH" write 300 600 900 suspend/.test(install), "install.sh writes the default times when there are none")
} finally {
    for (const d of dirs) fs.rmSync(d, { recursive: true, force: true })
}

console.log(fails ? `${fails} of ${n} failed` : `all ${n} passed`)
process.exit(fails ? 1 : 0)
