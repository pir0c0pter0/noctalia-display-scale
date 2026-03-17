import QtQuick
import qs.Commons

Item {
    id: root

    property string text: ""
    property color textColor: Color.mOnSurface
    property int scrollSpeed: 60
    property real maxWidth: 200

    implicitHeight: clippedText.implicitHeight
    implicitWidth: Math.min(maxWidth, fullText.implicitWidth)
    clip: true

    readonly property bool needsScroll: fullText.implicitWidth > root.maxWidth

    Text {
        id: fullText
        font.family: "monospace"
        font.pixelSize: Style.fontSizeM
        color: root.textColor
        text: root.needsScroll ? root.text + "   " + root.text : root.text
        visible: false
    }

    Text {
        id: clippedText
        font.family: "monospace"
        font.pixelSize: Style.fontSizeM
        color: root.textColor
        text: root.needsScroll ? root.text + "   " + root.text : root.text
        x: 0

        NumberAnimation on x {
            id: scrollAnim
            from: 0
            to: -(fullText.implicitWidth / 2)
            duration: root.text.length * root.scrollSpeed
            loops: Animation.Infinite
            running: root.needsScroll && root.visible
        }
    }
}
