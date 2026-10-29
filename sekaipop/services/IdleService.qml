pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The idle times: after how long the screen locks, turns off, and the machine sleeps
// or hibernates, each of them optional (Settings > General > Idle & sleep, issue #101).
//
// hypridle still does the waiting, because it is what honours every reason to stay
// awake: Keep Awake (a systemd idle inhibitor, QuickSource.qml), a video playing in a
// browser (the ScreenSaver D-Bus interface) and Wayland's idle inhibitors. The shell
// only writes what it waits for, ~/.config/sekaipop/idle.conf, which the shipped
// hypridle.conf reads with `source =` (scripts/system/idle-config.sh does the file work
// and restarts hypridle, which reads its config only when it starts).
//
// A hypridle.conf from before this, or one of your own, has its own listeners and doesn't
// read the file: `linked` is false and the Settings offer to switch it (link()).
//
//   qs -c sekaipop ipc call options set idle.lock 10       minutes, 0 = never
//   qs -c sekaipop ipc call options set idle.screenOff 0
//   qs -c sekaipop ipc call options set idle.sleep 30
//   qs -c sekaipop ipc call options set idle.sleepAction hibernate
//   qs -c sekaipop ipc call idle status
//   qs -c sekaipop ipc call idle link
Singleton {
    id: root

    readonly property string script: Directories.script("system/idle-config.sh")

    readonly property int lockMinutes: SettingsService.get("idle.lock")
    readonly property int screenOffMinutes: SettingsService.get("idle.screenOff")
    readonly property int sleepMinutes: SettingsService.get("idle.sleep")
    readonly property string sleepAction: SettingsService.get("idle.sleepAction") === "hibernate" ? "hibernate" : "suspend"

    // What `idle-config.sh status` said: "yes" | "no" | "missing" ("" until it has).
    property string linked: ""
    property bool running: true
    // "yes" | "no" | "unknown"
    property string canHibernate: "unknown"
    property bool linking: false
    // Why the last link() didn't link ("" when it did, or before one ran).
    property string linkError: ""

    // Read by shell.qml so the singleton exists from the start: the file has to be
    // written (and kept in step after an update) whether or not the Settings open.
    readonly property bool ready: SettingsService.loaded

    function args() {
        const sec = m => String(Math.max(0, Math.round(m)) * 60)
        return [sec(root.lockMinutes), sec(root.screenOffMinutes), sec(root.sleepMinutes), root.sleepAction]
    }

    function refresh() {
        if (!status.running)
            status.running = true
    }

    // Switches hypridle.conf over to these times. Writes our file first, so hypridle
    // finds it when it restarts.
    function link() {
        if (root.linking)
            return
        root.linking = true
        root.linkError = ""
        writer.thenLink = true
        root.write()
    }

    // Steppers repeat while held, and every write that changes something restarts
    // hypridle, so the write waits for the value to settle.
    Timer {
        id: settle
        interval: 1200
        onTriggered: root.write()
    }

    function write() {
        if (writer.running) {
            writer.queued = true
            return
        }
        writer.exec(["sh", root.script, "write"].concat(root.args()))
    }

    onLockMinutesChanged: if (SettingsService.loaded) settle.restart()
    onScreenOffMinutesChanged: if (SettingsService.loaded) settle.restart()
    onSleepMinutesChanged: if (SettingsService.loaded) settle.restart()
    onSleepActionChanged: if (SettingsService.loaded) settle.restart()

    Connections {
        target: SettingsService
        function onLoadedChanged() {
            if (SettingsService.loaded)
                root.write()
        }
    }

    Component.onCompleted: {
        if (SettingsService.loaded)
            root.write()
        root.refresh()
    }

    Process {
        id: writer

        property bool queued: false
        property bool thenLink: false

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("IdleService: " + text.trim())
        }

        onExited: {
            if (writer.queued) {
                writer.queued = false
                root.write()
                return
            }
            if (writer.thenLink) {
                writer.thenLink = false
                linker.running = true
                return
            }
            root.refresh()
        }
    }

    Process {
        id: linker
        command: ["sh", root.script, "link"]
        stderr: StdioCollector {
            onStreamFinished: {
                root.linkError = text.trim().replace(/\s+/g, " ")
                if (root.linkError !== "")
                    console.warn("IdleService: " + root.linkError)
            }
        }
        onExited: {
            root.linking = false
            root.refresh()
        }
    }

    Process {
        id: status
        command: ["sh", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i < 0)
                        continue
                    const k = line.slice(0, i), v = line.slice(i + 1).trim()
                    if (k === "linked")
                        root.linked = v
                    else if (k === "running")
                        root.running = v === "yes"
                    else if (k === "hibernate")
                        root.canHibernate = v
                }
            }
        }
    }

    IpcHandler {
        target: "idle"

        function status(): string {
            root.refresh()
            return "lock " + root.lockMinutes + " min, screen off " + root.screenOffMinutes
                + " min, " + root.sleepAction + " " + root.sleepMinutes + " min (0 = never); "
                + "hypridle.conf reads them: " + (root.linked || "?") + "; hypridle running: " + (root.running ? "yes" : "no")
        }

        function link(): void {
            root.link()
        }
    }
}
