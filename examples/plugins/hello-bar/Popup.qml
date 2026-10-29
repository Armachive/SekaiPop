import QtQuick

// The example plugin's popup (docs/PLUGINS.md, "A bar entry"): the face of the card that
// opens under its bar entry. The shell draws the card, places it, pops it in and out and
// closes it on a click away or Escape; this draws what is on it, sized by its
// implicitWidth x implicitHeight (kept between 280 and 480 wide).
Item {
    id: root

    required property var host

    readonly property var t: root.host.theme
    readonly property var svc: root.host.service

    implicitWidth: 300
    implicitHeight: col.implicitHeight + 32

    Column {
        id: col
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 8

        Text {
            text: "Up for"
            color: root.t.inkSub
            font.family: root.t.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
        }

        Text {
            text: root.svc ? root.svc.short(root.svc.uptime) : "--"
            color: root.t.ink
            font.family: root.t.fontFamily
            font.pixelSize: 28
            font.weight: Font.ExtraBold
            font.styleName: root.t.fontStyleBold
        }

        Text {
            visible: root.host.settings.showLoad && !!root.svc && root.svc.load !== ""
            text: "Load " + (root.svc ? root.svc.load : "")
            color: root.t.inkSub
            font.family: root.t.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
        }

        // An action that ends the popup puts it away itself (host.popup.close).
        Rectangle {
            width: closeText.implicitWidth + 24
            height: 30
            radius: 10
            color: area.containsMouse ? root.t.surfaceHover : root.t.surface
            border.width: 2.5
            border.color: root.t.line

            Text {
                id: closeText
                anchors.centerIn: parent
                text: "Close"
                color: root.t.ink
                font.family: root.t.fontFamily
                font.pixelSize: 12
                font.weight: Font.ExtraBold
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.popup.close()
            }
        }
    }
}
