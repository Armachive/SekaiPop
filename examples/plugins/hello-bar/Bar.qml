import QtQuick

// The example plugin's bar entry (docs/PLUGINS.md, "A bar entry"). The shell draws the pill
// around it, presses it while the popup is open, and opens the popup on a left click; this
// draws only what is inside: an icon and the uptime, the uptime under the icon on a
// standing bar.
//
// It reads its numbers from the shared service (host.service), never on its own.
Item {
    id: root

    required property var host

    readonly property var svc: root.host.service
    readonly property string text: root.svc ? root.svc.short(root.svc.uptime) : "--"

    // The hover tag (optional).
    property string tip: "Up for " + root.text
    // false would take the entry off the bar while it has nothing to say (optional).
    property bool present: true

    implicitWidth: root.host.bar.vertical ? col.implicitWidth : row.implicitWidth
    implicitHeight: root.host.bar.vertical ? col.implicitHeight : row.implicitHeight

    Row {
        id: row
        visible: !root.host.bar.vertical
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "timer"
            color: root.host.bar.ink
            font.family: root.host.theme.iconFont
            font.pixelSize: 20
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.host.bar.ink
            font.family: root.host.theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: root.host.theme.fontStyleBold
        }
    }

    Column {
        id: col
        visible: root.host.bar.vertical
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "timer"
            color: root.host.bar.ink
            font.family: root.host.theme.iconFont
            font.pixelSize: 20
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            // A standing bar is narrow: the largest unit only.
            text: root.text.split(" ").slice(0, 2).join("")
            color: root.host.bar.ink
            font.family: root.host.theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.styleName: root.host.theme.fontStyleBold
        }
    }
}
