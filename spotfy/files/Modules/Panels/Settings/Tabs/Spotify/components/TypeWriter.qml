import QtQuick
import qs.Commons

Item {
    id: root

    property string fullText: ""
    property int charDelay: 30
    property bool animating: false
    property color textColor: Color.mOnSurface

    signal finished()

    implicitHeight: display.implicitHeight
    implicitWidth: display.implicitWidth

    Text {
        id: display
        font.family: "monospace"
        font.pixelSize: Style.fontSizeM
        color: root.textColor
        text: ""
    }

    property int _charIndex: 0

    Timer {
        id: typeTimer
        interval: root.charDelay
        repeat: true
        running: false
        onTriggered: {
            if (root._charIndex < root.fullText.length) {
                display.text += root.fullText[root._charIndex]
                root._charIndex++
            } else {
                typeTimer.running = false
                root.animating = false
                root.finished()
            }
        }
    }

    function start() {
        display.text = ""
        _charIndex = 0
        animating = true
        typeTimer.running = true
    }

    function skipToEnd() {
        typeTimer.running = false
        display.text = fullText
        _charIndex = fullText.length
        animating = false
        finished()
    }
}
