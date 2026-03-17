import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../components"

ColumnLayout {
    id: root

    property var service
    property string playlistId: ""
    property string playlistName: ""
    signal back()

    spacing: Style.marginXS
    Layout.fillWidth: true

    readonly property color textColor: Color.mOnSurface
    readonly property color dimColor: Color.mOnSurfaceVariant
    readonly property color accentColor: Color.mPrimary
    readonly property int fontSize: Style.fontSizeM

    property var tracks: []

    Component.onCompleted: {
        if (root.playlistId) {
            root.service.getPlaylistTracks(root.playlistId)
        }
    }

    Connections {
        target: root.service
        function onCommandCompleted(command, result) {
            if (command === "playlist_tracks") {
                root.tracks = result.items || []
            }
        }
    }

    TerminalSpinner {
        spinning: root.tracks.length === 0 && root.service.loading
    }

    Repeater {
        model: root.tracks

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

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.accentColor
                text: "[+queue]"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.addToQueue(modelData.uri)
                }
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
