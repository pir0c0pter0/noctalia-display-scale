import QtQuick
import qs.Commons

Item {
    id: root

    property bool playing: false
    property int barCount: 20
    property color barColor: Color.mPrimary

    implicitHeight: barText.implicitHeight
    implicitWidth: barText.implicitWidth

    readonly property var levels: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

    Text {
        id: barText
        font.family: "monospace"
        font.pixelSize: Style.fontSizeM
        color: root.barColor
        text: generateBars()

        function generateBars() {
            var result = ""
            for (var i = 0; i < root.barCount; i++) {
                var idx = root.playing ? Math.floor(Math.random() * root.levels.length) : 0
                result += root.levels[idx]
            }
            return result
        }
    }

    Timer {
        id: animTimer
        interval: 100
        repeat: true
        running: root.playing && root.visible
        onTriggered: barText.text = barText.generateBars()
    }
}
