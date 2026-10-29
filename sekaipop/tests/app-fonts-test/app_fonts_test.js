// node tests/app-fonts-test/app_fonts_test.js   (run from the sekaipop folder)
// scripts/theming/app-fonts.sh against a throwaway config folder, on a PATH of its own: a
// file-backed dconf, an fc-list that knows a few fonts and a dbus-send that only logs, so
// nothing reaches this machine's settings. What `set` writes where (GTK's settings and
// settings.ini, kdeglobals, qt5ct / qt6ct), that the other lines of those files stay, which
// signals go out, what it refuses; and the font search the Settings use.
const fs = require("fs"), os = require("os"), path = require("path")
const { spawnSync, execFileSync } = require("child_process")
const locate = require("../lib/locate.js")
const script = locate("scripts/theming/app-fonts.sh")
const top = path.dirname(locate("shell.qml"))

let fails = 0, n = 0
function ok(cond, msg) { n++; if (!cond) { fails++; console.log("FAIL " + msg) } }
function eq(a, b, msg) {
    n++
    const x = JSON.stringify(a), y = JSON.stringify(b)
    if (x !== y) { fails++; console.log("FAIL " + msg + "\n   got  " + x + "\n   want " + y) }
}

const FONTS = { "Noto Sans": 0, "Cantarell": 0, "Inter Display": 0, "JetBrains Mono": 100, "Iosevka Term": 110, "Fira Code": 90 }

const dirs = []
function setup(files, tools) {
    const cfg = fs.mkdtempSync(path.join(os.tmpdir(), "sekaipop-fonts-"))
    dirs.push(cfg)
    for (const [name, text] of Object.entries(files)) {
        fs.mkdirSync(path.dirname(path.join(cfg, name)), { recursive: true })
        fs.writeFileSync(path.join(cfg, name), text)
    }
    // Only these programs exist, so a qt5ct or dconf installed on this machine can't change
    // what the script decides.
    const bin = path.join(cfg, "bin")
    fs.mkdirSync(bin)
    for (const t of ["awk", "sed", "grep", "sort", "mkdir", "mv", "cat", "head", "wc", "tr", "dirname", "rm"]) {
        const real = execFileSync("sh", ["-c", "command -v " + t], { encoding: "utf8" }).trim()
        fs.symlinkSync(real, path.join(bin, t))
    }
    const stub = (name, body) => fs.writeFileSync(path.join(bin, name), "#!/bin/sh\n" + body + "\n", { mode: 0o755 })
    // dconf: one file per key under db/.
    stub("dconf", `db="${cfg}/db"; mkdir -p "$db"
k=$(printf '%s' "$2" | tr / _)
case "$1" in
  read) [ -f "$db/$k" ] && cat "$db/$k" ;;
  write) printf '%s\\n' "$3" > "$db/$k" ;;
esac`)
    const fcl = Object.entries(FONTS).map(([f, s]) => `${s}\t${f}`).join("\\n")
    stub("fc-list", `want=""
case "$1" in :spacing=*) want="\${1#:spacing=}" ;; esac
printf '${fcl}\\n' | while IFS="$(printf '\\t')" read -r s f; do
  if [ -z "$want" ] || [ "$s" = "$want" ]; then printf '%s\\n' "$f"; fi
done`)
    stub("dbus-send", `echo "$*" >> "${cfg}/signals"`)
    for (const t of tools || []) stub(t, "exit 0")
    return cfg
}
const run = (cfg, env, ...args) => {
    const r = spawnSync("/bin/sh", [script, ...args], {
        env: Object.assign({ HOME: cfg, XDG_CONFIG_HOME: cfg, PATH: path.join(cfg, "bin") }, env), encoding: "utf8" })
    return { code: r.status, out: r.stdout, err: r.stderr }
}
const read = (cfg, rel) => fs.readFileSync(path.join(cfg, rel), "utf8")
const exists = (cfg, rel) => fs.existsSync(path.join(cfg, rel))
const dconf = (cfg, key) => exists(cfg, "db/_org_gnome_desktop_interface_" + key)
    ? read(cfg, "db/_org_gnome_desktop_interface_" + key).trim() : null
const KDE = { QT_QPA_PLATFORMTHEME: "kde" }

try {
    // ---- list ----
    let c = setup({})
    eq(run(c, {}, "list", "ui").out.trim().split("\n"),
        ["Cantarell", "Fira Code", "Inter Display", "Iosevka Term", "JetBrains Mono", "Noto Sans"], "every family, sorted")
    eq(run(c, {}, "list", "mono").out.trim().split("\n"), ["Fira Code", "Iosevka Term", "JetBrains Mono"],
        "monospaced: fontconfig's mono, dual-width and char-cell")
    eq(run(c, {}, "list", "serif").code, 2, "an unknown list is refused")

    // ---- set ui: every place, other lines kept ----
    c = setup({
        "gtk-3.0/settings.ini": "[Settings]\ngtk-theme-name=Adwaita\ngtk-font-name=Old 9\n",
        "qt6ct/qt6ct.conf": "[Appearance]\nstyle=Fusion\n\n[Fonts]\nfixed=\"Old Mono,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\"\ngeneral=\"Old,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\"\n",
        "kdeglobals": "[General]\nColorScheme=SekaipopA\n\n[Colors:View]\nBackgroundNormal=1,2,3\n"
    })
    let r = run(c, KDE, "set", "ui", "Inter Display", "11")
    eq([r.code, r.err], [0, ""], "set ui works")
    eq(dconf(c, "font-name"), "'Inter Display 11'", "GTK: GNOME's font-name")
    eq(dconf(c, "document-font-name"), "'Inter Display 11'", "GTK: the document font follows")
    let ini = read(c, "gtk-3.0/settings.ini")
    ok(ini.includes("gtk-font-name=Inter Display 11") && !ini.includes("Old 9"), "gtk-3.0 settings.ini: the key is replaced")
    ok(ini.includes("gtk-theme-name=Adwaita"), "gtk-3.0 settings.ini: other keys stay")
    ok(read(c, "gtk-4.0/settings.ini").includes("[Settings]\ngtk-font-name=Inter Display 11"), "gtk-4.0 settings.ini is made")
    const kg = read(c, "kdeglobals")
    const q6 = s => `Inter Display,${s},-1,5,400,0,0,0,0,0,0,0,0,0,0,1`
    for (const k of ["font", "menuFont", "toolBarFont"])
        ok(kg.includes(`\n${k}=${q6(11)}\n`), "kdeglobals [General] " + k)
    ok(kg.includes(`smallestReadableFont=${q6(9)}`), "kdeglobals smallestReadableFont is two points smaller")
    ok(/\[WM\]\nactiveFont=Inter Display,11,/.test(kg), "kdeglobals [WM] activeFont")
    ok(kg.includes("ColorScheme=SekaipopA") && kg.includes("[Colors:View]\nBackgroundNormal=1,2,3"), "kdeglobals: the colours stay")
    let qt6 = read(c, "qt6ct/qt6ct.conf")
    ok(qt6.includes(`general="${q6(11)}"`), "qt6ct general, quoted, Qt 6 format")
    ok(qt6.includes('fixed="Old Mono,9,') && qt6.includes("style=Fusion"), "qt6ct: the monospace font and the style stay")
    ok(!exists(c, "qt5ct/qt5ct.conf"), "no qt5ct.conf made when qt5ct isn't installed")
    const sig = read(c, "signals")
    ok(sig.includes("/KDEPlatformTheme org.kde.KDEPlatformTheme.refreshFonts"), "KDE's platform theme is told to reload its fonts")
    ok(sig.includes("/KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:1 int32:0"), "and KDE Frameworks 5 apps (FontChanged)")

    eq(run(c, KDE, "get").out, "ui=Inter Display\nuisize=11\nmono=\nmonosize=\n", "get reads it back")

    // ---- set mono ----
    r = run(c, KDE, "set", "mono", "JetBrains Mono", "10")
    eq(r.code, 0, "set mono works")
    eq(dconf(c, "monospace-font-name"), "'JetBrains Mono 10'", "GTK: monospace-font-name")
    ok(read(c, "kdeglobals").includes("\nfixed=JetBrains Mono,10,-1,5,400,"), "kdeglobals fixed")
    qt6 = read(c, "qt6ct/qt6ct.conf")
    ok(qt6.includes('fixed="JetBrains Mono,10,-1,5,400,') && qt6.includes(`general="${q6(11)}"`), "qt6ct fixed, general kept")
    ok(!read(c, "gtk-3.0/settings.ini").includes("JetBrains"), "settings.ini has no monospace key, nothing is added")
    eq(run(c, KDE, "get").out, "ui=Inter Display\nuisize=11\nmono=JetBrains Mono\nmonosize=10\n", "get: both")

    // ---- qt5ct: its own format, only when it is there ----
    c = setup({}, ["qt5ct"])
    run(c, {}, "set", "ui", "Noto Sans", "10")
    ok(read(c, "qt5ct/qt5ct.conf").includes('[Fonts]\ngeneral="Noto Sans,10,-1,5,50,0,0,0,0,0"'), "qt5ct: Qt 5 format")
    ok(!exists(c, "kdeglobals"), "no KDE and no kde platform theme: kdeglobals isn't made")
    ok(!exists(c, "signals"), "and no KDE signals")

    // ---- refusals ----
    c = setup({})
    for (const [args, what] of [
        [["set", "ui", "Comic Sans", "10"], "a font that isn't installed"],
        [["set", "ui", "Noto Sans,Bold", "10"], "a name with a comma"],
        [["set", "ui", "Noto\"Sans", "10"], "a name with a quote"],
        [["set", "ui", "Noto Sans", "5"], "a size under 6"],
        [["set", "ui", "Noto Sans", "73"], "a size over 72"],
        [["set", "ui", "Noto Sans", "ten"], "a size that isn't a number"],
        [["set", "serif", "Noto Sans", "10"], "an unknown kind"]
    ]) {
        r = run(c, KDE, ...args)
        eq(r.code, 2, what + " is refused")
    }
    eq(dconf(c, "font-name"), null, "nothing was written by a refused set")
    ok(!exists(c, "kdeglobals") && !exists(c, "gtk-3.0"), "no file was made by a refused set")

    // ---- get without dconf values: settings.ini; a symlinked file is left alone ----
    c = setup({ "gtk-3.0/settings.ini": "[Settings]\ngtk-font-name=Cantarell 12\n" })
    eq(run(c, {}, "get").out.split("\n").slice(0, 2), ["ui=Cantarell", "uisize=12"], "get falls back to settings.ini")
    c = setup({ "mine.ini": "[Settings]\ngtk-font-name=Mine 9\n" })
    fs.mkdirSync(path.join(c, "gtk-3.0"))
    fs.symlinkSync(path.join(c, "mine.ini"), path.join(c, "gtk-3.0", "settings.ini"))
    r = run(c, {}, "set", "ui", "Cantarell", "10")
    eq(r.code, 0, "a symlinked settings.ini doesn't stop the rest")
    eq(read(c, "mine.ini"), "[Settings]\ngtk-font-name=Mine 9\n", "it is left alone")
    ok(r.err.includes("is a symlink") && r.err.includes("gtk-font-name=Cantarell 10"), "and the key to set is named")
    eq(dconf(c, "font-name"), "'Cantarell 10'", "GTK's own setting is still written")

    // ---- the search the Settings use (AppFontService.matches / exact) ----
    const svc = fs.readFileSync(path.join(top, "services", "AppFontService.qml"), "utf8")
    const fn = name => {
        const m = new RegExp(`function ${name}\\(([^)]*)\\) \\{([\\s\\S]*?)\\n    \\}`).exec(svc)
        ok(m, "AppFontService." + name + " is there")
        return new Function("root", ...m[1].split(",").map(s => s.trim()), m[2])
    }
    const root = { families: ["Cantarell", "Fira Code", "Inter", "Inter Display", "JetBrains Mono", "Noto Sans", "Noto Sans Mono"],
                   monoFamilies: ["Fira Code", "JetBrains Mono", "Noto Sans Mono"] }
    const matches = fn("matches"), exact = fn("exact")
    eq(matches(root, "noto", false, 8), ["Noto Sans", "Noto Sans Mono"], "matches: case ignored")
    eq(matches(root, "mono", false, 8), ["JetBrains Mono", "Noto Sans Mono"], "matches: anywhere in the name")
    eq(matches(root, "in", false, 8), ["Inter", "Inter Display", "JetBrains Mono"], "matches: names that start with it first")
    eq(matches(root, "noto", true, 8), ["Noto Sans Mono"], "matches: monospaced only for the monospace field")
    eq(matches(root, "  ", false, 8), [], "matches: nothing typed, nothing shown")
    eq(matches(root, "n", false, 2).length, 2, "matches: at most the limit")
    eq(exact(root, "inter display", false), "Inter Display", "exact: the installed spelling")
    eq(exact(root, "Inter Disp", false), "", "exact: part of a name isn't a font")
    eq(exact(root, "cantarell", true), "Cantarell", "exact: a full name works in the monospace field too")

    // ---- the QML around it ----
    const settings = fs.readFileSync(path.join(top, "services", "SettingsService.qml"), "utf8")
    for (const [k, v] of [["appFonts.ui", '""'], ["appFonts.uiSize", "0"], ["appFonts.mono", '""'], ["appFonts.monoSize", "0"]])
        ok(settings.includes(`"${k}": ${v},`), k + " defaults to " + v + " (the system's font stays)")
    const presets = fs.readFileSync(path.join(top, "services", "DesktopPresetService.qml"), "utf8")
    ok(/keepPrefix: \[[^\]]*"appFonts\."/.test(presets), "presets never carry the app fonts")
    ok(/AppFontService\.ready/.test(fs.readFileSync(path.join(top, "shell.qml"), "utf8")), "shell.qml starts AppFontService")
    const text = fs.readFileSync(path.join(top, "modules", "sekai", "settings", "SettingText.qml"), "utf8")
    ok(/signal edited\(string text\)/.test(text) && /onTextEdited: root\.edited\(input\.text\)/.test(text), "SettingText sends edited")
    ok(/function reset\(\) \{\s*input\.text = root\.value\s*input\.focus = false/.test(text), "SettingText.reset puts the value back first")
    const page = fs.readFileSync(path.join(top, "modules", "sekai", "settings", "SettingsPageDesktop.qml"), "utf8")
    ok(/title: "App fonts"/.test(page) && /AppFontService\.setUi\(id\)/.test(page) && /AppFontService\.setMono\(id\)/.test(page),
        "Settings > Desktop has the App fonts section")
} finally {
    for (const d of dirs) fs.rmSync(d, { recursive: true, force: true })
}

console.log(fails ? `${fails} of ${n} failed` : `all ${n} passed`)
process.exit(fails ? 1 : 0)
