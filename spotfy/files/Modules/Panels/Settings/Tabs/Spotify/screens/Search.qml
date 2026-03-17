import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../components"

ColumnLayout {
    id: root

    property var service
    signal back()

    spacing: Style.marginS
    Layout.fillWidth: true

    readonly property color textColor: Color.mOnSurface
    readonly property color dimColor: Color.mOnSurfaceVariant
    readonly property color accentColor: Color.mPrimary
    readonly property int fontSize: Style.fontSizeM

    property var searchResults: null

    Connections {
        target: root.service
        function onCommandCompleted(command, result) {
            if (command === "search") {
                root.searchResults = result
            }
        }
    }

    // Search input
    Row {
        spacing: Style.marginXS

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.accentColor
            text: "grep>"
        }

        TextInput {
            id: searchInput
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.textColor
            width: 250
            clip: true
            focus: true

            Keys.onReturnPressed: {
                if (text.trim()) {
                    root.service.search(text.trim())
                }
            }
        }

        TerminalSpinner {
            spinning: root.service.loading
        }
    }

    // Track results
    ColumnLayout {
        visible: root.searchResults !== null && root.searchResults.tracks.length > 0
        spacing: Style.marginXXS
        Layout.fillWidth: true

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.dimColor
            text: "--- tracks ---"
        }

        Repeater {
            model: root.searchResults ? root.searchResults.tracks : []

            RowLayout {
                spacing: Style.marginS
                Layout.fillWidth: true

                Text {
                    font.family: "monospace"
                    font.pixelSize: root.fontSize
                    color: root.textColor
                    text: modelData.name
                    elide: Text.ElideRight
                    Layout.maximumWidth: 180
                }

                Text {
                    font.family: "monospace"
                    font.pixelSize: root.fontSize - 1
                    color: root.dimColor
                    text: modelData.artist
                    elide: Text.ElideRight
                    Layout.maximumWidth: 120
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
    }

    // Artist results
    ColumnLayout {
        visible: root.searchResults !== null && root.searchResults.artists.length > 0
        spacing: Style.marginXXS
        Layout.fillWidth: true

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.dimColor
            text: "--- artists ---"
        }

        Repeater {
            model: root.searchResults ? root.searchResults.artists : []

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.textColor
                text: "  " + modelData.name
            }
        }
    }

    // No results
    Text {
        visible: root.searchResults !== null &&
                 root.searchResults.tracks.length === 0 &&
                 root.searchResults.artists.length === 0
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: I18n.tr("panels.spotify.no-results")
    }

    Item { Layout.fillHeight: true }

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
