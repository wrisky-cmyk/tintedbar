import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

Item {
    id: wallpaperRoot

    Variants {
        model: Quickshell.screens

        delegate: Item {
            id: screenRoot

            required property var modelData

            PanelWindow {
                id: bg
                screen: screenRoot.modelData

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.namespace: "quickshell-wallpaper"

                color: bg.wpColor

                readonly property var scr: screenRoot.modelData
                readonly property string screenName: bg.scr ? String(bg.scr.name) : "?"
                readonly property string wpPath: WallpaperMap.pathFor(bg.screenName)
                readonly property string wpMode: WallpaperMap.modeFor(bg.screenName)

                readonly property color wpColor: WallpaperMap.colorFor(bg.screenName) || Style.bgSolid

                readonly property int decodeWidth: {
                    if (bg.scr && bg.scr.width > 0)
                        return Math.round(bg.scr.width * (bg.scr.devicePixelRatio || 1));

                    return bg.width > 0 ? bg.width : 1920;
                }

                Image {
                    id: wpImage
                    anchors.fill: parent
                    source: bg.wpPath !== "" ? "file://" + bg.wpPath : ""

                    sourceSize.width: bg.decodeWidth
                    fillMode: bg.wpMode === "contain" ? Image.PreserveAspectFit : (bg.wpMode === "tile" ? Image.Tile : Image.PreserveAspectCrop)
                    asynchronous: true
                    cache: false

                    visible: status === Image.Ready

                    onStatusChanged: {
                        if (status === Image.Error)
                            console.log("[WALLPAPER] " + bg.screenName + " 加载失败: " + source);
                    }
                }
            }
        }
    }
}
