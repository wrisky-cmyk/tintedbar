pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

PopupPanel {
    id: weatherPopup

    required property var qsRoot

    anchorItem: weatherModule
    required property var weather
    required property var weatherModule

    visible: false
    function open() {
        if (!qsRoot.showWeather) {
            qsRoot.weatherEditRequested = false;

            qsRoot.panelSet("weather", false);
            return;
        }
        weatherPopup.visible = true;

        if (weatherPopup.weather.located) {
            if (weatherPopup.locationEdit)
                weatherPopup.exitLocationEdit();
        } else {
            weatherPopup.enterLocationEdit();
        }

        if (qsRoot.weatherEditRequested) {
            qsRoot.weatherEditRequested = false;
            weatherPopup.enterLocationEdit();
        }
    }
    property bool editRequested: false
    function close() {
        searchDebounce.stop();
        weatherPopup.visible = false;
    }
    function toggle() {
        weatherPopup.visible ? weatherPopup.close() : weatherPopup.open();
    }

    Connections {
        target: weatherPopup.weather
        function onReadyChanged() {
            if (!weatherPopup.weather.ready)
                weatherPopup.close();
        }
    }

    readonly property string updatedText: {
        const ms = Number(weather.fetchedAt) || 0;
        if (ms <= 0)
            return "";
        const d = new Date(ms);
        const now = new Date();
        const yest = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
        const sameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
        let stamp;
        if (sameDay(d, now))
            stamp = Qt.formatTime(d, "HH:mm");
        else if (sameDay(d, yest))
            stamp = I18n.fill(I18n.t("wx.yesterdayAt"), {
                t: Qt.formatTime(d, "HH:mm")
            });
        else
            stamp = Qt.formatDateTime(d, "MM-dd HH:mm");
        if (weather.stale)
            stamp += " · " + I18n.t("wx.stale");
        return I18n.fill(I18n.t("wx.updated"), {
            t: stamp
        });
    }

    property bool locationEdit: false
    property string searchQuery: ""

    property string searchState: "idle"
    property var searchResults: []
    property int selectedIdx: 0
    property int geoGen: 0
    property string manualWarn: ""

    readonly property string locationText: weather.city !== "" ? weather.city : (weather.located ? weather.lat.toFixed(2) + ", " + weather.lon.toFixed(2) : I18n.t("wx.locationMissing"))

    function enterLocationEdit() {
        geoGen++;
        geoPendingQuery = "";

        if (geoProc.running)
            geoProc.running = false;
        locationEdit = true;
        searchState = "idle";
        searchResults = [];
        selectedIdx = 0;
        searchQuery = "";
        searchInput.text = "";
        manualWarn = "";
        searchInput.forceActiveFocus();
    }
    function exitLocationEdit() {
        geoGen++;
        geoPendingQuery = "";
        if (geoProc.running)
            geoProc.running = false;
        locationEdit = false;
        searchState = "idle";
        searchResults = [];
        selectedIdx = 0;
        searchDebounce.stop();
        searchInput.text = "";
        wxCard.forceActiveFocus();
    }
    function moveSelection(d) {
        const n = searchResults.length;
        if (n === 0)
            return;
        selectedIdx = Math.min(n - 1, Math.max(0, selectedIdx + d));
    }
    function pickSelected() {
        pickLocation(selectedIdx);
    }
    function pickLocation(idx) {
        const r = searchResults[idx];
        if (!r)
            return;
        writeLocationConf(String(r.lat), String(r.lon), r.name);
    }

    property var pendingLocWrite: null
    function writeLocationConf(lat, lon, city) {
        if (locationWrite.running) {
            pendingLocWrite = [lat, lon, city];
            return;
        }

        const oneLine = String(city || "").replace(/[\r\n]+/g, " ").trim();
        locationWrite.pendingContent = "lat=" + lat + "\nlon=" + lon + "\n" + (oneLine !== "" ? "city=" + oneLine + "\n" : "");
        locationWrite.command = ["bash", Style.configDir + "/scripts/atomic-write.sh", weather.confPath];
        locationWrite.stdinEnabled = true;
        locationWrite.running = true;
    }

    function flushPendingOnDestroy() {
        let content = "";
        if (pendingLocWrite !== null) {
            const q = pendingLocWrite;
            pendingLocWrite = null;
            const oneLine = String(q[2] || "").replace(/[\r\n]+/g, " ").trim();
            content = "lat=" + q[0] + "\nlon=" + q[1] + "\n" + (oneLine !== "" ? "city=" + oneLine + "\n" : "");
        } else if (locationWrite.running && locationWrite.pendingContent !== "") {
            content = locationWrite.pendingContent;
        }
        if (content === "")
            return;
        Quickshell.execDetached(["sh", "-c", "printf %s " + Style.sq(content) + " | bash " + Style.sq(Style.configDir + "/scripts/atomic-write.sh") + " " + Style.sq(weather.confPath)]);
    }
    Component.onDestruction: flushPendingOnDestroy()

    function manualSubmit(text) {
        const parts = String(text).split(/[,，]/).map(x => x.trim());
        const la = Number(parts[0] || NaN), lo = Number(parts[1] || NaN);
        if (parts.length !== 2 || !isFinite(la) || !isFinite(lo) || Math.abs(la) > 90 || Math.abs(lo) > 180) {
            manualWarn = I18n.t("wx.manualHint");
            return;
        }
        manualWarn = "";
        writeLocationConf(parts[0], parts[1], "");
    }
    property string geoPendingQuery: ""

    property string lastLandedQuery: ""
    property string geoLandedQuery: ""
    function geoStart(q) {
        geoGen++;

        if (geoProc.running) {
            geoPendingQuery = q;
            return;
        }
        geoProc.myGen = geoGen;
        geoLandedQuery = q;

        geoProc.command = ["curl", "-sS", "-m", "8", "-A", "tintedbar-weather-panel", "-G", "--data-urlencode", "q=" + q, "--data-urlencode", "limit=6", "https://photon.komoot.io/api"];
        geoProc.running = true;
        searchState = "querying";
    }
    function geoDone(text) {
        lastLandedQuery = geoLandedQuery;
        let d = null;
        try {
            d = JSON.parse(text);
        } catch (e) {
            d = null;
        }
        const feats = (d && d.features) || [];
        const out = [];
        for (const f of feats) {
            const p = f.properties || {};
            const c = (f.geometry && f.geometry.coordinates) || [];
            if (c.length < 2 || !p.name)
                continue;
            const region = [p.city, p.county, p.state, p.country].filter(Boolean).join(" ");
            out.push({
                name: String(p.name),
                region: region,
                lat: c[1],
                lon: c[0]
            });
        }

        if (out.length > 0) {
            searchResults = out;
            searchState = "results";
        } else {
            searchResults = [];
            searchState = "failed";
        }
    }
    Process {
        id: geoProc
        running: false
        property int myGen: 0

        onExited: code => {
            if (weatherPopup.searchState === "querying")
                weatherPopup.searchState = "failed";
            if (weatherPopup.geoPendingQuery !== "") {
                const pq = weatherPopup.geoPendingQuery;
                weatherPopup.geoPendingQuery = "";
                weatherPopup.geoStart(pq);
            }
        }
        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: if (geoProc.myGen === weatherPopup.geoGen)
                weatherPopup.geoDone(text)
        }
    }
    Timer {
        id: searchDebounce
        interval: 400
        onTriggered: if (weatherPopup.locationEdit && weatherPopup.searchQuery !== "")
            weatherPopup.geoStart(weatherPopup.searchQuery)
    }

    Process {
        id: locationWrite
        running: false
        property string pendingContent: ""
        stdinEnabled: true
        onStarted: {
            locationWrite.write(locationWrite.pendingContent);
            locationWrite.stdinEnabled = false;
        }
        onExited: code => {
            const q = weatherPopup.pendingLocWrite;
            if (q !== null) {
                weatherPopup.pendingLocWrite = null;
                Qt.callLater(() => weatherPopup.writeLocationConf(q[0], q[1], q[2]));
            }

            if (code === 0) {
                if (q === null)
                    weatherPopup.exitLocationEdit();
            } else if (q === null) {
                Style.notifySimple(I18n.t("wx.writeFailed"), "");
            }
        }
    }

    implicitWidth: 244

    implicitHeight: wxCol.implicitHeight + 20 + Style.barHeight + 2 - Style.barInset

    Rectangle {
        id: wxCard
        anchors.fill: parent

        anchors.topMargin: weatherPopup.cardTopMargin
        radius: 12
        color: Style.card
        border.width: 1
        border.color: Style.border
        focus: true
        Keys.onEscapePressed: weatherPopup.close()

        Column {
            id: wxCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            Column {
                id: editBody
                width: parent.width
                visible: weatherPopup.locationEdit
                spacing: 6

                Item {
                    width: parent.width

                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Style.border
                    }
                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.margins: 6
                        anchors.right: searchExit.left
                        verticalAlignment: TextInput.AlignVCenter
                        color: Style.text1
                        font.family: Style.cjk
                        font.pixelSize: 13
                        clip: true
                        onTextEdited: {
                            weatherPopup.searchQuery = text;

                            const t = text;
                            const last = weatherPopup.lastLandedQuery;
                            if (last !== "" && weatherPopup.searchResults.length > 0 && (t.startsWith(last) || last.startsWith(t))) {
                                weatherPopup.searchResults = weatherPopup.searchResults.filter(function (r) {
                                    return String(r.name || "").indexOf(t) >= 0 || String(r.region || "").indexOf(t) >= 0;
                                });
                                weatherPopup.searchState = "results";
                            }
                            searchDebounce.restart();
                        }

                        Keys.priority: Keys.BeforeItem
                        Keys.onEscapePressed: weatherPopup.exitLocationEdit()
                        Keys.onUpPressed: weatherPopup.moveSelection(-1)
                        Keys.onDownPressed: weatherPopup.moveSelection(1)
                        Keys.onReturnPressed: weatherPopup.pickSelected()
                        Keys.onEnterPressed: weatherPopup.pickSelected()
                        Text {
                            anchors.fill: parent
                            visible: searchInput.text === ""
                            text: I18n.t("wx.locationSearch")
                            color: Style.text3
                            font.family: Style.cjk
                            font.pixelSize: 13
                        }
                    }
                    Text {
                        id: searchExit
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: searchExitMouse.containsMouse ? Style.text1 : Style.text3
                        font.family: Style.nerd
                        font.pixelSize: 12
                        text: "\u{F00D}"
                        MouseArea {
                            id: searchExitMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: weatherPopup.exitLocationEdit()
                        }
                    }
                }

                Text {
                    width: parent.width

                    visible: (weatherPopup.searchState === "querying" || weatherPopup.searchState === "failed") && weatherPopup.searchResults.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: weatherPopup.searchState === "failed" ? Style.danger : Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 12
                    text: weatherPopup.searchState === "querying" ? I18n.t("wx.searching") : I18n.t("wx.searchFailed")
                }

                Repeater {
                    model: weatherPopup.searchResults

                    delegate: Item {
                        id: resultRow
                        width: editBody.width
                        height: 22
                        required property var modelData
                        required property int index

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: (rowMouse.containsMouse || resultRow.index === weatherPopup.selectedIdx) ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                        }
                        Text {
                            id: resName
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(resName.implicitWidth, 115)
                            elide: Text.ElideRight
                            color: resultRow.index === weatherPopup.selectedIdx ? Style.accent : Style.text1
                            font.family: Style.cjk
                            font.pixelSize: 12
                            textFormat: Text.PlainText
                            text: resultRow.modelData.name
                        }
                        Text {
                            anchors.left: resName.right
                            anchors.leftMargin: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                            color: Style.text3
                            font.family: Style.cjk
                            font.pixelSize: 11
                            textFormat: Text.PlainText
                            text: resultRow.modelData.region
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: weatherPopup.pickLocation(resultRow.index)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 32
                    visible: weatherPopup.searchState === "failed"

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Style.border
                    }
                    TextInput {
                        id: manualInput
                        anchors.fill: parent
                        anchors.margins: 6
                        verticalAlignment: TextInput.AlignVCenter
                        color: Style.text1
                        font.family: Style.cjk
                        font.pixelSize: 13
                        clip: true
                        Keys.onEscapePressed: weatherPopup.exitLocationEdit()
                        Keys.onReturnPressed: weatherPopup.manualSubmit(text)
                        Keys.onEnterPressed: weatherPopup.manualSubmit(text)
                        Text {
                            anchors.fill: parent
                            visible: manualInput.text === ""
                            text: weatherPopup.manualWarn !== "" ? weatherPopup.manualWarn : I18n.t("wx.manualHint")
                            color: weatherPopup.manualWarn !== "" ? Style.danger : Style.text3
                            font.family: Style.cjk
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: weatherPopup.weather.located
                    horizontalAlignment: Text.AlignHCenter
                    color: clearMouse.containsMouse ? Style.danger : Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 12
                    text: I18n.t("wx.locationClear")
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: weatherPopup.writeLocationConf("", "", "")
                    }
                }
            }

            Item {
                width: parent.width
                visible: !weatherPopup.locationEdit

                height: 40

                Text {
                    id: wxNowGlyph
                    anchors.left: parent.left
                    anchors.top: parent.top
                    color: Style.accent
                    font.family: Style.nerd
                    font.pixelSize: 30
                    text: weatherPopup.weather.current ? weatherPopup.weather.glyph(weatherPopup.weather.current.code, weatherPopup.weather.current.isDay) : ""
                }
                Text {
                    id: wxNowTemp
                    anchors.left: wxNowGlyph.right
                    anchors.leftMargin: 8

                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.text1
                    font.family: Style.nerd
                    font.pixelSize: 22
                    font.bold: true
                    text: weatherPopup.weather.current ? Math.round(weatherPopup.weather.current.temp) + "°" : ""
                }
                Text {
                    anchors.left: wxNowTemp.right
                    anchors.leftMargin: 8
                    anchors.right: locationValue.left
                    anchors.rightMargin: 8
                    anchors.baseline: wxNowTemp.baseline
                    elide: Text.ElideRight
                    color: Style.text2
                    font.family: Style.cjk
                    font.pixelSize: 13

                    text: weatherPopup.weather.current ? I18n.t("wx.c." + weatherPopup.weather.wmoKey(weatherPopup.weather.current.code)) : ""
                }

                Text {
                    id: locationValue
                    anchors.right: locationGear.left
                    anchors.rightMargin: 6
                    anchors.baseline: wxNowTemp.baseline
                    width: Math.min(locationValue.implicitWidth, 110)
                    elide: Text.ElideRight
                    color: locationMouse.containsMouse ? Style.accent : Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 12
                    textFormat: Text.PlainText
                    text: weatherPopup.locationText
                }
                Text {
                    id: locationGear
                    anchors.right: parent.right
                    anchors.baseline: wxNowTemp.baseline
                    color: locationMouse.containsMouse ? Style.accent : Style.text3
                    font.family: Style.nerd
                    font.pixelSize: 13
                    text: "\u{F013}"
                }
                MouseArea {
                    id: locationMouse
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: locationValue.width + locationGear.width + 6
                    height: parent.height
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: weatherPopup.enterLocationEdit()
                }
            }

            Text {
                width: parent.width
                visible: !weatherPopup.locationEdit
                elide: Text.ElideRight
                color: Style.text3
                font.family: Style.cjk

                font.pixelSize: 13
                text: weatherPopup.weather.current ? I18n.t("wx.feels") + " " + Math.round(weatherPopup.weather.current.feels) + "°  " + I18n.t("wx.humidity") + " " + Math.round(weatherPopup.weather.current.humidity) + "%  " + I18n.t("wx.wind") + " " + Math.round(weatherPopup.weather.current.wind) + " km/h" : ""
            }

            Rectangle {
                width: parent.width
                height: 1
                visible: !weatherPopup.locationEdit
                color: Style.border
                opacity: 0.4
            }

            Repeater {
                model: weatherPopup.weather.daily

                delegate: Item {
                    id: dayRow
                    required property var modelData
                    required property int index
                    width: parent ? parent.width : 0
                    height: 24
                    visible: !weatherPopup.locationEdit

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 52
                        elide: Text.ElideRight
                        color: Style.text2
                        font.family: Style.cjk
                        font.pixelSize: 13
                        text: dayRow.index === 0 ? I18n.t("wx.today") : (dayRow.index === 1 ? I18n.t("wx.tomorrow") : I18n.weekdayShort(weatherPopup.weather.dayDate(dayRow.modelData.date)))
                    }
                    Text {
                        id: wxDayGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: 56
                        anchors.verticalCenter: parent.verticalCenter
                        color: Style.text3
                        font.family: Style.nerd
                        font.pixelSize: 15
                        text: weatherPopup.weather.glyph(dayRow.modelData.code, true)
                    }
                    Text {
                        id: wxDayRange
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: Style.text2
                        font.family: Style.nerd
                        font.pixelSize: 13
                        text: Math.round(dayRow.modelData.min) + " / " + Math.round(dayRow.modelData.max) + "°"
                    }

                    Text {
                        anchors.left: wxDayGlyph.right
                        anchors.leftMargin: 8
                        anchors.right: wxDayRange.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: Style.text3
                        font.family: Style.cjk
                        font.pixelSize: 12
                        text: I18n.t("wx.c." + weatherPopup.weather.wmoKey(dayRow.modelData.code))
                    }
                }
            }

            Item {
                width: parent.width
                height: 18
                visible: !weatherPopup.locationEdit

                Text {
                    anchors.left: parent.left
                    anchors.right: refreshLabel.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    color: weatherPopup.weather.stale ? Style.danger : Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: weatherPopup.updatedText
                }

                Text {
                    id: refreshLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    color: refreshMouse.containsMouse ? Style.accent : Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 11
                    text: weatherPopup.weather.refreshing ? I18n.t("wx.refreshing") : I18n.t("wx.refresh")
                }

                MouseArea {
                    id: refreshMouse
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    width: refreshLabel.width
                    height: parent.height
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: weatherPopup.weather.refresh()
                }
            }
        }
    }
}
