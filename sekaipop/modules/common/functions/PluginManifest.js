.pragma library

// Desktop widget plugins (services/PluginService.qml, docs/PLUGINS.md): reading a plugin's
// plugin.json and its saved state. Pure functions on plain objects, so they are unit-tested
// with node: tests/plugin-test/manifest_unit.js.
//
// A plugin is a folder, ${XDG_CONFIG_HOME:-~/.config}/sekaipop/plugins/<id>/, holding
// plugin.json and Widget.qml. The manifest is the half of the plugin interface that is
// data; the `host` object the widget is handed is the other half. Both are promises:
// change them only by raising API_VERSION, and keep reading the older one where it
// costs little.

// The plugin interface this shell speaks. A plugin names the one it was written for in
// `api`; one this shell does not speak is skipped with a message, never loaded half-broken.
var API_VERSION = 1
var SUPPORTED = [1]

// The folder name is the id, so the id can be trusted as a file name and in an ipc call.
var ID_RE = /^[a-z0-9][a-z0-9-]{0,39}$/
// A secret's name, and a setting's key: something that reads well as `host.secrets.token`.
var KEY_RE = /^[A-Za-z_][A-Za-z0-9_]{0,39}$/

function isObj(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

// A settings value a plugin may declare: what JSON and an ipc call can carry plainly.
function plainValue(v) {
    return typeof v === "string" || typeof v === "boolean" || (typeof v === "number" && isFinite(v))
}

// The QML files a plugin folder may hold, by what they are for. The scan says which are there
// (plugin-state.sh scan); `files` on a plugin is { widget, bar, popup, service } as booleans.
var FILES = { widget: "Widget.qml", bar: "Bar.qml", popup: "Popup.qml", service: "Service.qml" }

// What the scan's file list says is in the folder. No list at all (an older scan, or a test
// that only has the manifest) reads as the plugin interface's first shape: a widget alone.
function readFiles(list) {
    if (typeof list !== "string")
        return { widget: true, bar: false, popup: false, service: false }
    var names = list.split(/\s+/)
    var out = {}
    for (var k in FILES)
        out[k] = names.indexOf(FILES[k]) >= 0
    return out
}

// parse(text, folder, files) -> { ok: true, plugin } or { ok: false, id, error, code, field }
// `files` is the scan's list of the folder's QML files (readFiles); leave it out for a widget.
// `plugin` is the manifest with every optional field filled in, so nothing downstream has
// to guess:
//   { id, name, version, api, description, icon, frame, cloneable, settings, secrets,
//     settingsInfo, groups, bar, files }
// `bar` is { label, icon } for a plugin with an entry in the bar, null otherwise.
// `code` says what kind of problem `error` is, so Settings can say it in plain words and name
// who has to fix it (PluginForm.skipInfo) without matching the message's text:
//   folder   the folder's name can't be an id        id       id and folder differ
//   json     plugin.json is not JSON                 object   it is JSON but not an object
//   api-new  written for a newer shell               api-old  written for an older one
//   field    a field is missing or wrong (`field` names it)
//   files    the QML files and the manifest disagree (`bar` without Bar.qml, nothing to draw)
//   missing  no plugin.json at all (only from scan())
function parse(text, folder, fileList) {
    var bad = function (code, msg, field) {
        return { ok: false, id: folder, error: msg, code: code, field: field || "" }
    }
    if (!ID_RE.test(folder))
        return bad("folder", "the folder name must be lower case letters, digits and dashes (it is the plugin's id)")
    var m
    try {
        m = JSON.parse(text)
    } catch (e) {
        return bad("json", "plugin.json is not valid JSON")
    }
    if (!isObj(m))
        return bad("object", "plugin.json must be an object")
    if (m.id !== folder)
        return bad("id", "plugin.json says id \"" + m.id + "\" but its folder is \"" + folder + "\"; they must match")
    if (typeof m.name !== "string" || m.name.trim() === "")
        return bad("field", "plugin.json needs a name", "name")
    if (typeof m.version !== "string" || m.version === "")
        return bad("field", "plugin.json needs a version (a string)", "version")
    if (typeof m.api !== "number" || Math.floor(m.api) !== m.api)
        return bad("field", "plugin.json needs `api`: the plugin interface version it was written for (this shell speaks " + API_VERSION + ")", "api")
    if (SUPPORTED.indexOf(m.api) < 0)
        return bad(m.api > API_VERSION ? "api-new" : "api-old", "written for plugin api " + m.api + ", this shell speaks " + SUPPORTED.join(", ")
            + (m.api > API_VERSION ? " (update SekaiPop)" : " (update the plugin)"))

    var settings = {}
    if (m.settings !== undefined) {
        if (!isObj(m.settings))
            return bad("field", "`settings` must be an object of name: default value", "settings")
        for (var k in m.settings) {
            if (!KEY_RE.test(k))
                return bad("field", "setting \"" + k + "\": names are letters, digits and _", "settings." + k)
            if (!plainValue(m.settings[k]))
                return bad("field", "setting \"" + k + "\": a default is a string, a number or true / false", "settings." + k)
            settings[k] = m.settings[k]
        }
    }

    var secrets = {}
    if (m.secrets !== undefined) {
        if (!isObj(m.secrets))
            return bad("field", "`secrets` must be an object of name: { env, file }", "secrets")
        for (var s in m.secrets) {
            var d = m.secrets[s]
            if (!KEY_RE.test(s))
                return bad("field", "secret \"" + s + "\": names are letters, digits and _", "secrets." + s)
            if (!isObj(d) || (typeof d.env !== "string" && typeof d.file !== "string"))
                return bad("field", "secret \"" + s + "\": say where it is read from, `env` and / or `file`", "secrets." + s)
            secrets[s] = {
                env: typeof d.env === "string" ? d.env : "",
                file: typeof d.file === "string" ? d.file : ""
            }
        }
    }

    var files = readFiles(fileList)
    var bar = null
    if (m.bar !== undefined) {
        if (!isObj(m.bar))
            return bad("field", "`bar` must be an object: { label, icon }", "bar")
        if (!files.bar)
            return bad("files", "plugin.json has `bar` but the folder has no Bar.qml", "bar")
        bar = {
            // The module's name in Settings > Bar and on Edit Desktop's BAR tab.
            label: typeof m.bar.label === "string" && m.bar.label.trim() !== "" ? m.bar.label.trim() : m.name.trim(),
            icon: typeof m.bar.icon === "string" && m.bar.icon !== "" ? m.bar.icon : (typeof m.icon === "string" && m.icon !== "" ? m.icon : "extension")
        }
    } else if (files.bar) {
        return bad("files", "the folder has Bar.qml but plugin.json has no `bar`: add \"bar\": { \"label\", \"icon\" }", "bar")
    }
    if (!files.widget && !bar)
        return bad("files", "nothing to draw: a plugin needs Widget.qml, or Bar.qml with `bar` in plugin.json")
    // A popup belongs to a bar entry; without one nothing could open it.
    files.popup = files.popup && !!bar

    return {
        ok: true,
        plugin: {
            id: m.id,
            name: m.name.trim(),
            version: m.version,
            api: m.api,
            description: typeof m.description === "string" ? m.description : "",
            // A Material Symbols name, for its tile on the Edit Desktop shelf.
            icon: typeof m.icon === "string" && m.icon !== "" ? m.icon : "extension",
            // The shell's card around the widget (outline, ring, surface, shadow), so a plugin
            // looks like the built-in cards without drawing one. false = the widget draws all.
            frame: m.frame !== false,
            // A copy on more than one monitor (EditMode's "one widget, several monitors").
            cloneable: m.cloneable !== false,
            settings: settings,
            secrets: secrets,
            settingsInfo: readSettingsInfo(m.settingsInfo, settings),
            groups: readGroups(m.groups),
            bar: bar,
            files: files
        }
    }
}

// `settingsInfo` (optional, added within api 1): how Settings draws each setting.
//   { key: { label, description, group, min, max, step, unit, choices, multiline } }
// It only describes; the setting's type is still its default's. So it is read leniently: a
// field that is wrong for its setting is dropped and the rest kept, and a wrong `settingsInfo`
// never skips a plugin that works. Only settings the manifest declares are kept.
function readSettingsInfo(raw, settings) {
    var out = {}
    if (!isObj(raw))
        return out
    var text = function (v) {
        return typeof v === "string" && v.trim() !== "" ? v.trim() : ""
    }
    var num = function (v) {
        return typeof v === "number" && isFinite(v)
    }
    for (var k in settings) {
        var d = raw[k]
        if (!isObj(d))
            continue
        var t = typeof settings[k]
        var o = {}
        if (text(d.label))
            o.label = text(d.label)
        if (text(d.description))
            o.description = text(d.description)
        if (text(d.group))
            o.group = text(d.group)
        if (t === "number") {
            if (num(d.min) && num(d.max) && d.min < d.max) {
                o.min = d.min
                o.max = d.max
            }
            if (num(d.step) && d.step > 0)
                o.step = d.step
            if (text(d.unit))
                o.unit = text(d.unit)
        }
        if (t === "string") {
            if (Array.isArray(d.choices)) {
                var cs = []
                for (var i = 0; i < d.choices.length; i++) {
                    var c = d.choices[i]
                    if (typeof c === "string")
                        cs.push({ value: c, label: c })
                    else if (isObj(c) && typeof c.value === "string")
                        cs.push({ value: c.value, label: text(c.label) || c.value })
                }
                if (cs.length > 0)
                    o.choices = cs
            }
            if (d.multiline === true && !o.choices)
                o.multiline = true
        }
        out[k] = o
    }
    return out
}

// `groups` (optional): the order of the group headings in Settings.
function readGroups(raw) {
    var out = []
    if (!Array.isArray(raw))
        return out
    for (var i = 0; i < raw.length; i++) {
        var g = typeof raw[i] === "string" ? raw[i].trim() : ""
        if (g !== "" && out.indexOf(g) < 0)
            out.push(g)
    }
    return out
}

// The manifest's defaults with the user's saved values on top. A saved value only counts
// for a setting the manifest still declares and only with the default's type, so a plugin
// update that drops or retypes a setting never hands the widget something it did not ask for.
function mergeSettings(defaults, saved) {
    var out = {}
    for (var k in defaults) {
        var v = isObj(saved) ? saved[k] : undefined
        out[k] = (v !== undefined && typeof v === typeof defaults[k] && plainValue(v)) ? v : defaults[k]
    }
    return out
}

// One value from an ipc call (always a string) turned into the setting's type, or
// undefined when it cannot be one.
function coerce(defaultValue, text) {
    if (typeof defaultValue === "string")
        return String(text)
    if (typeof defaultValue === "boolean") {
        if (text === true || text === "true" || text === "1" || text === "on")
            return true
        if (text === false || text === "false" || text === "0" || text === "off")
            return false
        return undefined
    }
    if (typeof defaultValue === "number") {
        var n = typeof text === "number" ? text : parseFloat(text)
        return isFinite(n) ? n : undefined
    }
    return undefined
}

// The scan script's output (scripts/state/plugin-state.sh scan): for every plugin folder,
// a line "\x1e<folder>\x1f<its QML files, space separated>" followed by its plugin.json (or
// nothing when it has none). A line without "\x1f" (an older script) has no file list.
// -> [{ folder, text, files }]
function splitScan(out) {
    var recs = []
    var parts = String(out || "").split("\x1e")
    for (var i = 1; i < parts.length; i++) {
        var nl = parts[i].indexOf("\n")
        var head = nl < 0 ? parts[i] : parts[i].slice(0, nl)
        var text = nl < 0 ? "" : parts[i].slice(nl + 1)
        var us = head.indexOf("\x1f")
        var folder = us < 0 ? head : head.slice(0, us)
        var files = us < 0 ? undefined : head.slice(us + 1)
        if (folder !== "")
            recs.push({ folder: folder, text: text, files: files })
    }
    return recs
}

// scan(out) -> { plugins: [plugin], skipped: [{ id, error, code, field }] }, sorted by id so the shelf
// keeps one order.
function scan(out) {
    var plugins = []
    var skipped = []
    var recs = splitScan(out)
    recs.sort(function (a, b) { return a.folder < b.folder ? -1 : a.folder > b.folder ? 1 : 0 })
    for (var i = 0; i < recs.length; i++) {
        var r = recs[i]
        if (r.text.trim() === "") {
            skipped.push({ id: r.folder, error: "no plugin.json", code: "missing", field: "" })
            continue
        }
        var p = parse(r.text, r.folder, r.files)
        if (p.ok)
            plugins.push(p.plugin)
        else
            skipped.push({ id: p.id, error: p.error, code: p.code, field: p.field })
    }
    return { plugins: plugins, skipped: skipped }
}

// A plugin's saved state (spot, on / off, settings) read back; anything unreadable is the
// default: never placed, off, the manifest's settings.
function readState(text, defaults) {
    var s = {}
    try {
        s = JSON.parse(text)
    } catch (e) {
        s = {}
    }
    if (!isObj(s))
        s = {}
    return {
        x: typeof s.x === "number" ? s.x : -1,
        y: typeof s.y === "number" ? s.y : -1,
        scale: typeof s.scale === "number" && s.scale > 0 ? s.scale : 0,
        screen: typeof s.screen === "string" ? s.screen : "",
        shown: s.shown === true,
        // Its entry is on the bar (a plugin with `bar`); off until the user puts it there.
        bar: s.bar === true,
        settings: mergeSettings(defaults || {}, s.settings)
    }
}

// "~/x" and "x" (relative to the plugin's folder) as an absolute path.
function expandPath(path, home, dir) {
    if (typeof path !== "string" || path === "")
        return ""
    if (path === "~")
        return home
    if (path.indexOf("~/") === 0)
        return home + path.slice(1)
    if (path.charAt(0) === "/")
        return path
    return dir + "/" + path
}
