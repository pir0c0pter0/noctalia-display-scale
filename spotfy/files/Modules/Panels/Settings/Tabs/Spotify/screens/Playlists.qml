import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import "../components"

Flickable {
    id: flickRoot
    contentHeight: root.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

ColumnLayout {
    id: root
    width: flickRoot.width

    property var service
    signal navigate(string screen, var params)
    signal back()

    spacing: Style.marginXS

    readonly property color textColor: Color.mOnSurface
    readonly property color dimColor: Color.mOnSurfaceVariant
    readonly property color accentColor: Color.mPrimary
    readonly property int fontSize: Style.fontSizeM

    property var playlists: []

    Component.onCompleted: {
        root.service.getPlaylists()
    }

    Connections {
        target: root.service
        function onCommandCompleted(command, result) {
            if (command === "playlists") {
                root.playlists = result.items || []
            }
        }
    }

    // Loading
    TerminalSpinner {
        spinning: root.playlists.length === 0 && root.service.loading
    }

    // Playlist list
    Repeater {
        model: root.playlists

        RowLayout {
            spacing: Style.marginS
            Layout.fillWidth: true

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.accentColor
                text: ">"
            }

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.textColor
                text: modelData.name
                elide: Text.ElideRight
                Layout.maximumWidth: 250

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navigate("playlist_tracks", {
                        "id": modelData.id,
                        "name": modelData.name
                    })
                }
            }

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize - 1
                color: root.dimColor
                text: "(" + modelData.track_count + " tracks)"
            }

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.accentColor
                text: "[play]"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.playPlaylist(modelData.id)
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
} // ColumnLayout
} // Flickable
