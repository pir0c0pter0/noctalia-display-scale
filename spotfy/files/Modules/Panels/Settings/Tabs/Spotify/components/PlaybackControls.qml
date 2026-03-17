import QtQuick
import QtQuick.Layouts
import qs.Commons

RowLayout {
    id: root

    property bool isPlaying: false
    property bool shuffleOn: false
    property string repeatMode: "off"
    property int volume: 50

    signal playPauseClicked()
    signal nextClicked()
    signal prevClicked()
    signal shuffleClicked()
    signal repeatClicked()
    signal volumeChanged(int level)

    spacing: Style.marginM

    readonly property color activeColor: Color.mPrimary
    readonly property color inactiveColor: Color.mOnSurfaceVariant
    readonly property int fontSize: Style.fontSizeL

    // Previous
    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.inactiveColor
        text: "[◄◄]"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.prevClicked()
        }
    }

    // Play/Pause
    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.activeColor
        text: root.isPlaying ? "[❚❚]" : "[ ▶ ]"

        // Pulse animation when playing
        SequentialAnimation on opacity {
            running: root.isPlaying && root.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.6; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.playPauseClicked()
        }
    }

    // Next
    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.inactiveColor
        text: "[►►]"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.nextClicked()
        }
    }

    Item { Layout.preferredWidth: Style.marginM }

    // Shuffle
    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.shuffleOn ? root.activeColor : root.inactiveColor
        text: root.shuffleOn ? "[shf:ON]" : "[shf:--]"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.shuffleClicked()
        }
    }

    // Repeat
    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.repeatMode !== "off" ? root.activeColor : root.inactiveColor
        text: {
            if (root.repeatMode === "track") return "[rpt:1]"
            if (root.repeatMode === "context") return "[rpt:A]"
            return "[rpt:--]"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.repeatClicked()
        }
    }

    // Volume
    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.inactiveColor
        text: "vol:" + root.volume + "%"
    }
}
