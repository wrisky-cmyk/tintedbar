import QtQuick
import Quickshell.Widgets

Item {
    id: root

    required property var note
    property int iconSize: 22

    property int fallbackPx: 9
    property bool showFallback: hasIcon

    width: iconSize
    height: iconSize

    readonly property bool hasIcon: !!note && ((note.appIcon && note.appIcon !== "") || (note.image && note.image !== "") || (note.desktopEntry && note.desktopEntry !== ""))

    FileIcon {
        id: fileIcon
        visible: false
        iconNames: {
            if (!root.note)
                return [];
            const names = [];
            if (root.note.image)
                names.push(root.note.image);
            if (root.note.appIcon)
                names.push(root.note.appIcon);
            if (root.note.desktopEntry)
                names.push(root.note.desktopEntry);
            return names;
        }
    }

    IconImage {
        id: img
        anchors.fill: parent
        source: fileIcon.source
        visible: root.hasIcon && source !== "" && status !== Image.Error
    }

    Text {
        anchors.centerIn: parent
        visible: root.showFallback && !img.visible
        text: "●"
        color: Style.text3
        font.family: Style.cjk
        font.pixelSize: root.fallbackPx
    }
}
