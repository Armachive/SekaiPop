.pragma library

// Settings › Desktop › Plugins (SettingsPluginsCard.qml, docs/PLUGIN-SETTINGS.md): what the
// card shows, worked out from a plugin's manifest (PluginManifest.parse) and its current
// settings. Pure functions on plain objects, unit-tested in node:
// tests/plugin-test/form_unit.js.
//
// The manifest's `settingsInfo` is optional, and so is every field in it. Each field falls
// back on its own, so a plugin written before `settingsInfo` existed still gets a usable form:
//   no label        the key split into words ("refreshMinutes" -> "Refresh minutes"), and the
//                   raw key shown under it
//   number          min and max: a slider; otherwise a stepper (step 1, or `step`)
//   string          choices: chips; multiline: a taller field; otherwise a text field
//   true / false    a toggle
//   no group        one list in manifest order; grouped ones follow `groups`, ungrouped last

// "refreshMinutes" -> "Refresh minutes", "use24h" -> "Use 24h", "api_key" -> "Api key".
function humanize(key) {
    var s = String(key || "")
        .replace(/_+/g, " ")
        .replace(/([a-z])([A-Z])/g, "$1 $2")
        .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
        .replace(/([A-Za-z])([0-9])/g, "$1 $2")
        .trim()
        .replace(/\s+/g, " ")
    if (s === "")
        return ""
    var words = s.split(" ")
    for (var i = 0; i < words.length; i++) {
        // An acronym keeps its capitals ("URL"); a camelCase word goes lower case.
        if (i > 0 && words[i] !== words[i].toUpperCase())
            words[i] = words[i].toLowerCase()
    }
    return words[0].charAt(0).toUpperCase() + words[0].slice(1) + (words.length > 1 ? " " + words.slice(1).join(" ") : "")
}

// Decimal places worth showing for a number setting: as many as its step or its default has.
function decimalsOf(n) {
    var s = String(n)
    var dot = s.indexOf(".")
    return dot < 0 ? 0 : Math.min(4, s.length - dot - 1)
}

// Which control a setting gets: text, multiline, choice, slider, stepper, toggle.
function kindOf(def, info) {
    var t = typeof def
    if (t === "boolean")
        return "toggle"
    if (t === "number")
        return info && info.min !== undefined && info.max !== undefined ? "slider" : "stepper"
    if (info && info.choices)
        return "choice"
    if (info && info.multiline)
        return "multiline"
    return "text"
}

// A value as the card says it: the number with its unit, a choice's label, On / Off.
function valueText(row, v) {
    if (typeof v === "boolean")
        return v ? "On" : "Off"
    if (typeof v === "number") {
        var n = row.decimals > 0 ? v.toFixed(row.decimals) : String(Math.round(v * 1e6) / 1e6)
        return row.unit ? n + " " + row.unit : n
    }
    if (row.choices) {
        for (var i = 0; i < row.choices.length; i++) {
            if (row.choices[i].value === v)
                return row.choices[i].label
        }
    }
    return v === "" ? "empty" : String(v)
}

function same(a, b) {
    return typeof a === typeof b && a === b
}

// One row of the form. `settings` is the plugin's current settings (PluginState.settings).
function row(plugin, settings, key) {
    var def = plugin.settings[key]
    var info = (plugin.settingsInfo && plugin.settingsInfo[key]) || {}
    var value = settings && settings[key] !== undefined ? settings[key] : def
    var r = {
        key: key,
        kind: kindOf(def, info),
        label: info.label || humanize(key),
        hasLabel: !!info.label,
        description: info.description || "",
        group: info.group || "",
        value: value,
        def: def,
        changed: !same(value, def),
        min: info.min,
        max: info.max,
        step: info.step !== undefined ? info.step : 1,
        unit: info.unit || "",
        choices: info.choices || null,
        decimals: 0
    }
    if (typeof def === "number")
        r.decimals = Math.max(decimalsOf(r.step), decimalsOf(def))
    // A value the manifest's own range or choices would not allow is shown as it is, never
    // rewritten: it is what the widget has.
    r.outside = (r.kind === "slider" && (value < r.min || value > r.max))
        || (r.kind === "choice" && !r.choices.some(function (c) { return c.value === value }))
    r.shown = valueText(r, value)
    r.defText = "Default: " + valueText(r, def)
    return r
}

// The form: [{ title, rows }]. Headings in `groups` order, then any group only named by a
// setting (in the order the settings name it), then the ungrouped settings under no heading.
function form(plugin, settings) {
    var keys = Object.keys(plugin.settings || {})
    var rows = keys.map(function (k) { return row(plugin, settings, k) })
    var order = (plugin.groups || []).slice()
    for (var i = 0; i < rows.length; i++) {
        if (rows[i].group !== "" && order.indexOf(rows[i].group) < 0)
            order.push(rows[i].group)
    }
    var out = []
    for (var g = 0; g < order.length; g++) {
        var these = rows.filter(function (r) { return r.group === order[g] })
        if (these.length > 0)
            out.push({ title: order[g], rows: these })
    }
    var loose = rows.filter(function (r) { return r.group === "" })
    if (loose.length > 0)
        out.push({ title: "", rows: loose })
    return out
}

// The settings that differ from their defaults, by key.
function changedKeys(plugin, settings) {
    return Object.keys(plugin.settings || {}).filter(function (k) {
        return settings && settings[k] !== undefined && !same(settings[k], plugin.settings[k])
    })
}

function plural(n, one) {
    return n + " " + one + (n === 1 ? "" : "s")
}

// "5 settings · 3 secrets", "1 setting", "No settings".
function countText(plugin) {
    var s = Object.keys(plugin.settings || {}).length
    var k = Object.keys(plugin.secrets || {}).length
    var parts = []
    if (s > 0)
        parts.push(plural(s, "setting"))
    if (k > 0)
        parts.push(plural(k, "secret"))
    return parts.length > 0 ? parts.join(" · ") : "No settings"
}

// Whether the card has a form to open (settings or secrets), or only the plugin's details.
function hasForm(plugin) {
    return Object.keys(plugin.settings || {}).length > 0 || Object.keys(plugin.secrets || {}).length > 0
}

// A skipped folder (PluginManifest.scan's `skipped`) in plain words: what is wrong, who has
// to change something, and the one thing the card offers to do about it.
//   action: "update" (Check for updates), "folder" (Open its folder)
function skipInfo(s) {
    var code = s && s.code ? s.code : ""
    var authorFix = "To fix: the plugin's author, or you if you are writing it"
    switch (code) {
    case "json":
    case "object":
        return { reason: "Its plugin.json has a mistake in it, so the shell can't read it.", fix: authorFix, action: "folder" }
    case "api-new":
        return { reason: "Made for a newer SekaiPop than this one.", fix: "To fix: update SekaiPop", action: "update" }
    case "api-old":
        return { reason: "Made for an older SekaiPop.", fix: "To fix: update the plugin (git pull in its folder)", action: "folder" }
    case "id":
        return { reason: "Its folder is named differently from its id.", fix: "To fix: rename the folder to the plugin's id", action: "folder" }
    case "folder":
        return { reason: "The folder's name can't be a plugin id.", fix: "To fix: rename it with lower case letters, digits and dashes", action: "folder" }
    case "missing":
        return { reason: "This folder has no plugin.json, so it isn't a plugin.", fix: "To fix: check the clone, or remove the folder", action: "folder" }
    case "field":
        return { reason: "Its plugin.json is missing or misspells: " + (s.field || "a field") + ".", fix: authorFix, action: "folder" }
    case "files":
        return { reason: "Its files and its plugin.json don't agree: " + (s.error || "a QML file is missing") + ".", fix: authorFix, action: "folder" }
    }
    return { reason: "It could not be loaded.", fix: authorFix, action: "folder" }
}

// What the card says about one secret, never its value. `source` is PluginState's:
// "env", "file" or "" (not found).
function secretInfo(name, decl, source) {
    return {
        name: name,
        found: source === "env" || source === "file",
        source: source || "",
        env: decl && decl.env ? decl.env : "",
        file: decl && decl.file ? decl.file : ""
    }
}

// The warning on a plugin's row in the list: the first missing secret, or "".
function warnText(plugin, sources) {
    var names = Object.keys(plugin.secrets || {})
    var missing = names.filter(function (n) { return !(sources && (sources[n] === "env" || sources[n] === "file")) })
    if (missing.length === 0)
        return ""
    return missing.length === 1 ? missing[0] + " not found" : plural(missing.length, "secret") + " not found"
}
