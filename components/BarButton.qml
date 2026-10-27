import QtQuick

Item {
    id: btn

    property string glyph: ""
    property int glyphSize: 18

    property string tailText: ""
    property int tailSize: 0
    property int tailGap: 0
    property color textColor: Style.text1
    property int fontWeight: Font.Normal
    property int padH: 6
    property int rad: 5
    property color bgColor: "transparent"
    property int marginLeft: 0
    property int marginRight: 0
    property real opacityVal: 1.0

    property bool shown: true

    property bool hoverTint: true

    property int glyphYOffset: 0
    signal clicked
    signal rightClicked

    implicitWidth: btnRow.implicitWidth + btn.padH * 2 + btn.marginLeft + btn.marginRight
    implicitHeight: Style.barContentHeight
    visible: btn.shown

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: btn.marginLeft
        anchors.top: parent.top
        width: parent.width - btn.marginLeft - btn.marginRight
        height: parent.height
        radius: btn.rad
        color: btn.bgColor
        opacity: btn.opacityVal
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: btn.marginLeft
        anchors.top: parent.top
        width: parent.width - btn.marginLeft - btn.marginRight
        height: parent.height
        radius: btn.rad
        color: "#ffffff"
        opacity: (btn.hoverTint && btnMouse.containsMouse) ? 0.05 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }
    }

    Row {
        id: btnRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: btn.glyphYOffset
        x: btn.marginLeft + btn.padH
        spacing: btn.tailGap

        Text {
            id: glyphText
            text: btn.glyph
            color: btn.textColor
            font.family: Style.nerd
            font.pixelSize: btn.glyphSize
            font.weight: btn.fontWeight
            opacity: btn.opacityVal
        }

        Text {
            id: tailTextItem
            anchors.baseline: glyphText.baseline
            visible: btn.tailText !== ""
            text: btn.tailText
            color: btn.textColor
            font.family: Style.nerd
            font.pixelSize: btn.tailSize > 0 ? btn.tailSize : btn.glyphSize
            font.weight: btn.fontWeight
            opacity: btn.opacityVal
        }
    }

    MouseArea {
        id: btnMouse
        anchors.left: parent.left
        anchors.leftMargin: btn.marginLeft
        anchors.top: parent.top
        width: parent.width - btn.marginLeft - btn.marginRight
        height: parent.height
        hoverEnabled: btn.hoverTint
        cursorShape: btn.hoverTint ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton)
                btn.rightClicked();
            else
                btn.clicked();
        }
    }
}
