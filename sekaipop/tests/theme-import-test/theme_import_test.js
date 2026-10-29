// node tests/theme-import-test/theme_import_test.js   (run from the sekaipop folder)
// A QML file that reads `Theme.` without importing qs.modules.common (where the Theme
// singleton lives) still loads, but every binding that reads it fails at run time with
// "ReferenceError: Theme is not defined" and quietly falls back: text with no colour and
// the default font. qmllint can't say so here, since it doesn't resolve the `qs.` imports.
// This reads every .qml file for the use and the import. (The App fonts section shipped
// with exactly that, in SettingsPageDesktop.qml.)
const fs = require("fs"), path = require("path")

const top = path.join(__dirname, "..", "..")
const files = []
const walk = dir => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name)
        if (e.isDirectory()) walk(p)
        else if (e.name.endsWith(".qml")) files.push(p)
    }
}
for (const d of ["modules", "services"]) walk(path.join(top, d))
files.push(path.join(top, "shell.qml"))

const common = path.join(top, "modules", "common")
let fails = 0, n = 0
for (const f of files) {
    // Files in modules/common itself see Theme without an import.
    if (path.dirname(f) === common)
        continue
    const src = fs.readFileSync(f, "utf8")
    // Code only: comments mention Theme.foo often enough.
    const code = src.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'])\/\/.*$/gm, "$1")
    if (!/(^|[^A-Za-z0-9_.])Theme\./m.test(code))
        continue
    n++
    if (!/^import\s+qs\.modules\.common\s*$/m.test(src)) {
        fails++
        console.log("FAIL " + path.relative(top, f) + " reads Theme. without `import qs.modules.common`")
    }
}

console.log(fails ? `${fails} of ${n} failed` : `all ${n} passed`)
process.exit(fails ? 1 : 0)
