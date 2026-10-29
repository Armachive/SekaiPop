import QtQuick
import Quickshell.Io

// The example plugin's service (docs/PLUGINS.md, "A service"): made once, shared by the bar
// entry on every monitor and by the popup, so they all read one /proc/uptime.
//
// It reads only while something shows it (host.working), and slowly while that is the bar
// alone: host.wanted lists the surfaces up, and "popup" asks for the setting's pace.
QtObject {
    id: root

    required property var host

    // What the surfaces read: host.service.uptime and so on.
    property real uptime: -1         // seconds; -1 until the first read
    property string load: ""         // "0.42 0.37 0.30"

    readonly property bool hurried: root.host.wanted.indexOf("popup") >= 0

    property Timer timer: Timer {
        running: root.host.working
        repeat: true
        triggeredOnStart: true
        interval: root.hurried ? Math.max(1, root.host.settings.checkSeconds) * 1000 : 60000
        onTriggered: {
            uptimeFile.reload()
            loadFile.reload()
        }
    }

    // Opening the popup asks for fresh numbers at once, not at the bar's next minute.
    onHurriedChanged: {
        if (root.hurried) {
            uptimeFile.reload()
            loadFile.reload()
        }
    }

    property FileView uptimeFile: FileView {
        path: "/proc/uptime"
        blockLoading: false
        onLoaded: root.uptime = parseFloat(String(text()).split(" ")[0]) || 0
    }

    property FileView loadFile: FileView {
        path: "/proc/loadavg"
        blockLoading: false
        onLoaded: root.load = String(text()).split(" ").slice(0, 3).join(" ")
    }

    // "3 d 4 h", "4 h 12 m", "12 m".
    function short(sec) {
        if (sec < 0)
            return "--"
        const d = Math.floor(sec / 86400)
        const h = Math.floor(sec % 86400 / 3600)
        const m = Math.floor(sec % 3600 / 60)
        return d > 0 ? d + " d " + h + " h" : h > 0 ? h + " h " + m + " m" : m + " m"
    }
}
