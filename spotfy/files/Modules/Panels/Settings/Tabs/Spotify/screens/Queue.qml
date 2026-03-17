import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../components"

ColumnLayout {
    id: root

    property var service
    signal back()

    spacing: Style.marginXS
    Layout.fillWidth: true

    readonly property color textColor: Color.mOnSurface
    readonly property color dimColor: Color.mOnSurfaceVariant
    readonly property color accentColor: Color.mPrimary
    readonly property int fontSize: Style.fontSizeM

    property var queueItems: []

    Component.onCompleted: {
        root.service.getQueue()
    }

    Connections {
        target: root.service
        function onCommandCompleted(command, result) {
            if (command === "queue_list") {
                root.queueItems = result.items || []
            }
        }
    }

    TerminalSpinner {
        spinning: root.queueItems.length === 0 && root.service.loading
    }

    Text {
        visible: root.queueItems.length === 0 && !root.service.loading
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: I18n.tr("panels.spotify.queue-empty")
    }

    Repeater {
        model: root.queueItems

        RowLayout {
            spacing: Style.marginS
            Layout.fillWidth: true

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.dimColor
                text: (index + 1) + "."
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.textColor
                text: modelData.name
                elide: Text.ElideRight
                Layout.maximumWidth: 200
            }

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize - 1
                color: root.dimColor
                text: modelData.artist
                elide: Text.ElideRight
                Layout.maximumWidth: 150
            }
        }
    }

    Item { Layout.preferredHeight: Style.marginM }

    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: "> cd .."
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }
}
