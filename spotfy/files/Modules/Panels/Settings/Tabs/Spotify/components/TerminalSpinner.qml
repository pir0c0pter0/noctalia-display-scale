import QtQuick
import qs.Commons

Text {
    id: root

    property bool spinning: false
    property color spinnerColor: Color.mPrimary

    readonly property var frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    property int _frameIndex: 0

    font.family: "monospace"
    font.pixelSize: Style.fontSizeM
    color: root.spinnerColor
    text: root.spinning ? root.frames[root._frameIndex] : ""

    Timer {
        interval: 80
        repeat: true
        running: root.spinning && root.visible
        onTriggered: {
            root._frameIndex = (root._frameIndex + 1) % root.frames.length
        }
    }
}
