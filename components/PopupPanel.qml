import QtQuick
import Quickshell

PopupWindow {
    id: popup

    required property var panel

    required property var anchorItem

    readonly property int cardTopMargin: Style.barHeight + 2 - Style.barInset

    visible: false
    color: "transparent"
    grabFocus: true

    anchor.window: panel
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Top
}
