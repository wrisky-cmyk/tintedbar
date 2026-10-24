import QtQuick

Item {
    id: fileIcon

    property string iconName: ""

    property var iconNames: []
    property string source: ""

    function cleanNames() {
        const clean = [];
        for (let name of fileIcon.iconNames || []) {
            name = String(name || "");

            const marker = "image://icon/";
            if (name.indexOf(marker) === 0)
                name = name.substring(marker.length);
            if (!name)
                continue;

            if (name.indexOf("/") === 0) {
                fileIcon.source = WallpaperMap.fileUrl(name);
                return null;
            }
            if (name.indexOf("://") >= 0) {
                fileIcon.source = name;
                return null;
            }

            const q = name.indexOf("?");
            if (q >= 0)
                name = name.substring(0, q);
            if (!name)
                continue;
            if (clean.indexOf(name) < 0)
                clean.push(name);
        }
        return clean;
    }

    function restart() {
        const clean = fileIcon.cleanNames();
        if (clean === null)
            return;
        if (clean.length === 0) {
            fileIcon.source = "";
            return;
        }

        const cached = IconProbe.iconCacheGet(JSON.stringify(clean));
        if (cached !== undefined) {
            fileIcon.source = cached === "" ? "" : WallpaperMap.fileUrl(cached);
            return;
        }

        if (Style.debug)
            console.log("[FILEICON] queue", JSON.stringify(clean));
        IconProbe.requestIconProbe(JSON.stringify(clean), clean);
    }

    onIconNameChanged: {
        fileIcon.iconNames = fileIcon.iconName ? [fileIcon.iconName] : [];
    }
    onIconNamesChanged: fileIcon.restart()

    Connections {
        target: IconProbe
        function onIconProbesFinished() {
            const clean = fileIcon.cleanNames();
            if (clean === null || clean.length === 0)
                return;
            const key = JSON.stringify(clean);
            const cached = IconProbe.iconCacheGet(key);
            if (cached === undefined) {
                IconProbe.requestIconProbe(key, clean);
                return;
            }
            fileIcon.source = cached === "" ? "" : WallpaperMap.fileUrl(cached);
            if (Style.debug) {
                console.log("[FILEICON]", fileIcon.iconName, "->", cached === "" ? "MISS" : fileIcon.source);
            }
        }
    }

    Component.onCompleted: {
        if (fileIcon.iconNames.length === 0 && fileIcon.iconName) {
            fileIcon.iconNames = [fileIcon.iconName];
        } else {
            fileIcon.restart();
        }
    }
}
