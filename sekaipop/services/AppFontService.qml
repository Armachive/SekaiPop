pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The font GTK, Qt and KDE apps use (not the shell's own, which is the theme's), changed
// while they run (Settings > Desktop > App fonts, issue #98). The work is
// scripts/theming/app-fonts.sh: its header says which file each kind of app reads its font
// from, which is why a font set in only one of them (qt6ct, settings.ini) seems not to stay.
//
// What the system has is what the Settings show, until a font is picked here. A picked font
// is saved (appFonts.*) and put back at every start if something else changed it meanwhile;
// "Use the system's" forgets it, and nothing is written again.
//
//   qs -c sekaipop ipc call fonts ui "Noto Sans" 10
//   qs -c sekaipop ipc call fonts mono "JetBrains Mono" 10
//   qs -c sekaipop ipc call fonts status
//   qs -c sekaipop ipc call fonts forget
Singleton {
    id: root

    readonly property string script: Directories.script("theming/app-fonts.sh")

    // Installed families: every one, and the monospaced ones.
    property var families: []
    property var monoFamilies: []

    // What GTK reads right now (GNOME's font-name / monospace-font-name).
    property string currentUi: ""
    property int currentUiSize: 0
    property string currentMono: ""
    property int currentMonoSize: 0
    // True once `get` has answered.
    property bool known: false

    readonly property string savedUi: SettingsService.get("appFonts.ui")
    readonly property int savedUiSize: SettingsService.get("appFonts.uiSize")
    readonly property string savedMono: SettingsService.get("appFonts.mono")
    readonly property int savedMonoSize: SettingsService.get("appFonts.monoSize")
    readonly property bool chosen: root.savedUi !== "" || root.savedMono !== ""

    readonly property string shownUi: root.savedUi !== "" ? root.savedUi : root.currentUi
    readonly property int shownUiSize: root.savedUi !== "" && root.savedUiSize > 0 ? root.savedUiSize
        : (root.currentUiSize > 0 ? root.currentUiSize : 10)
    readonly property string shownMono: root.savedMono !== "" ? root.savedMono : root.currentMono
    readonly property int shownMonoSize: root.savedMono !== "" && root.savedMonoSize > 0 ? root.savedMonoSize
        : (root.currentMonoSize > 0 ? root.currentMonoSize : 10)

    readonly property bool busy: runner.running || root.queue.length > 0 || sizeSettle.running
    // The script's complaint about the last change ("" when it worked).
    property string note: ""

    // ===== choosing =====
    function setUi(family, size) {
        const s = size !== undefined ? size : root.shownUiSize
        SettingsService.set("appFonts.ui", family)
        SettingsService.set("appFonts.uiSize", s)
        root.push(["set", "ui", family, String(s)])
    }

    function setMono(family, size) {
        const s = size !== undefined ? size : root.shownMonoSize
        SettingsService.set("appFonts.mono", family)
        SettingsService.set("appFonts.monoSize", s)
        root.push(["set", "mono", family, String(s)])
    }

    // A size moves the saved size at once (the stepper shows it) and is written when it settles.
    function setUiSize(size) {
        if (root.shownUi === "")
            return
        SettingsService.set("appFonts.ui", root.shownUi)
        SettingsService.set("appFonts.uiSize", size)
        sizeSettle.ui = true
        sizeSettle.restart()
    }

    function setMonoSize(size) {
        if (root.shownMono === "")
            return
        SettingsService.set("appFonts.mono", root.shownMono)
        SettingsService.set("appFonts.monoSize", size)
        sizeSettle.mono = true
        sizeSettle.restart()
    }

    function forget() {
        SettingsService.set("appFonts.ui", "")
        SettingsService.set("appFonts.uiSize", 0)
        SettingsService.set("appFonts.mono", "")
        SettingsService.set("appFonts.monoSize", 0)
        root.readCurrent()
    }

    // Up to `limit` families for what was typed: names that start with it first, then names
    // that have it anywhere; case is ignored. Empty text: none.
    function matches(text, mono, limit) {
        const q = String(text || "").trim().toLowerCase()
        if (q === "")
            return []
        const list = mono ? root.monoFamilies : root.families
        const n = limit || 8
        const starts = [], has = []
        for (const f of list) {
            const l = f.toLowerCase()
            if (l.startsWith(q))
                starts.push(f)
            else if (l.indexOf(q) >= 0)
                has.push(f)
        }
        return starts.concat(has).slice(0, n)
    }

    // The family as installed for a typed name (any case), or "".
    function exact(text, mono) {
        const q = String(text || "").trim().toLowerCase()
        const list = mono ? root.monoFamilies : root.families
        for (const f of list) {
            if (f.toLowerCase() === q)
                return f
        }
        // A monospaced font that fontconfig doesn't call monospaced can still be typed in full.
        if (mono) {
            for (const f of root.families) {
                if (f.toLowerCase() === q)
                    return f
            }
        }
        return ""
    }

    Timer {
        id: sizeSettle
        property bool ui: false
        property bool mono: false
        interval: 500
        onTriggered: {
            if (sizeSettle.ui && root.savedUi !== "")
                root.push(["set", "ui", root.savedUi, String(root.savedUiSize)])
            if (sizeSettle.mono && root.savedMono !== "")
                root.push(["set", "mono", root.savedMono, String(root.savedMonoSize)])
            sizeSettle.ui = false
            sizeSettle.mono = false
        }
    }

    // ===== running the script, one change at a time =====
    property var queue: []

    function push(args) {
        root.queue = root.queue.concat([args])
        root.next()
    }

    function next() {
        if (runner.running || root.queue.length === 0)
            return
        const args = root.queue[0]
        root.queue = root.queue.slice(1)
        root.note = ""
        runner.args = args
        runner.exec(["sh", root.script].concat(args))
    }

    Process {
        id: runner
        // What it is running, so a refused change can be taken back.
        property var args: []
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim().replace(/^app-fonts: /gm, "").replace(/\s+/g, " ")
                if (t !== "") {
                    root.note = t
                    console.warn("AppFontService: " + t)
                }
            }
        }
        onExited: (code, status) => {
            // Refused (no such font, a bad size): don't keep a choice that would be tried
            // again at every start. The settings go back to the system's for that kind.
            if (code !== 0 && runner.args[0] === "set") {
                const kind = runner.args[1] === "mono" ? "mono" : "ui"
                SettingsService.set("appFonts." + kind, "")
                SettingsService.set("appFonts." + kind + "Size", 0)
            }
            if (root.queue.length > 0)
                root.next()
            else
                root.readCurrent()
        }
    }

    // ===== reading =====
    function refresh() {
        if (!lister.running)
            lister.running = true
        root.readCurrent()
    }

    function readCurrent() {
        if (!reader.running)
            reader.running = true
    }

    // At start: a font picked here that the system no longer has is put back.
    property bool startChecked: false

    function checkAtStart() {
        if (root.startChecked || !root.known || !SettingsService.loaded)
            return
        root.startChecked = true
        if (root.savedUi !== "" && (root.savedUi !== root.currentUi || root.savedUiSize !== root.currentUiSize)) {
            console.log("AppFontService: the app font was " + root.currentUi + " " + root.currentUiSize
                + ", putting back " + root.savedUi + " " + root.savedUiSize)
            root.push(["set", "ui", root.savedUi, String(root.savedUiSize)])
        }
        if (root.savedMono !== "" && (root.savedMono !== root.currentMono || root.savedMonoSize !== root.currentMonoSize)) {
            console.log("AppFontService: the monospace font was " + root.currentMono + " " + root.currentMonoSize
                + ", putting back " + root.savedMono + " " + root.savedMonoSize)
            root.push(["set", "mono", root.savedMono, String(root.savedMonoSize)])
        }
    }

    // Read by shell.qml so the singleton exists from the start (checkAtStart).
    readonly property bool ready: root.known

    Connections {
        target: SettingsService
        function onLoadedChanged() {
            root.checkAtStart()
        }
    }

    Component.onCompleted: root.readCurrent()

    Process {
        id: reader
        command: ["sh", root.script, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0)
                        kv[line.slice(0, i)] = line.slice(i + 1).trim()
                }
                root.currentUi = kv.ui || ""
                root.currentUiSize = parseInt(kv.uisize, 10) || 0
                root.currentMono = kv.mono || ""
                root.currentMonoSize = parseInt(kv.monosize, 10) || 0
                root.known = true
                root.checkAtStart()
            }
        }
    }

    Process {
        id: lister
        command: ["sh", "-c", "sh \"$0\" list ui; echo '--mono--'; sh \"$0\" list mono", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("--mono--")
                const lines = s => (s || "").split("\n").map(l => l.trim()).filter(l => l !== "")
                root.families = lines(parts[0])
                root.monoFamilies = lines(parts[1])
            }
        }
    }

    IpcHandler {
        target: "fonts"

        function status(): string {
            return "apps: " + root.shownUi + " " + root.shownUiSize + ", monospace: " + root.shownMono + " " + root.shownMonoSize
                + (root.chosen ? " (picked in SekaiPop, put back at start)" : " (the system's)")
        }

        function ui(family: string, size: int): void {
            root.setUi(family, size > 0 ? size : root.shownUiSize)
        }

        function mono(family: string, size: int): void {
            root.setMono(family, size > 0 ? size : root.shownMonoSize)
        }

        function forget(): void {
            root.forget()
        }
    }
}
