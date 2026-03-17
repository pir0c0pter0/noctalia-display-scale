import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../components"

ColumnLayout {
    id: root

    property var service
    signal navigate(string screen, var params)

    spacing: Style.marginS

    readonly property color textColor: Color.mOnSurface
    readonly property color dimColor: Color.mOnSurfaceVariant
    readonly property color accentColor: Color.mPrimary
    readonly property int fontSize: Style.fontSizeM

    // No device warning
    Text {
        visible: root.service.noDevice
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: Color.mError
        text: "[ERR] " + I18n.tr("panels.spotify.no-device")
        Layout.fillWidth: true
    }

    // Not premium warning
    Text {
        visible: root.service.authenticated && !root.service.premium
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: Color.mError
        text: "[WARN] " + I18n.tr("panels.spotify.not-premium")
        Layout.fillWidth: true
    }

    // Track info area
    ColumnLayout {
        visible: root.service.currentTrack !== null
        spacing: Style.marginXS
        Layout.fillWidth: true

        // Album art placeholder + track info
        RowLayout {
            spacing: Style.marginM

            // ASCII album art placeholder
            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.dimColor
                text: "▄▄▄▄▄▄▄▄\n█ ♫  ♪ █\n█  ♪ ♫ █\n▀▀▀▀▀▀▀▀"
                lineHeight: 1.0
            }

            ColumnLayout {
                spacing: Style.marginXXS

                MarqueeText {
                    text: root.service.currentTrack ? root.service.currentTrack.name : ""
                    textColor: root.textColor
                    maxWidth: 250
                }

                Text {
                    font.family: "monospace"
                    font.pixelSize: root.fontSize
                    color: root.dimColor
                    text: root.service.currentTrack ? root.service.currentTrack.artist : ""
                    elide: Text.ElideRight
                    Layout.maximumWidth: 250
                }

                Text {
                    font.family: "monospace"
                    font.pixelSize: root.fontSize - 1
                    color: root.dimColor
                    text: root.service.currentTrack ? root.service.currentTrack.album : ""
                    elide: Text.ElideRight
                    Layout.maximumWidth: 250
                }
            }
        }

        Item { Layout.preferredHeight: Style.marginXS }

        // Progress bar
        Row {
            spacing: Style.marginS

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.service.isPlaying ? root.accentColor : root.dimColor
                text: root.service.isPlaying ? "▶" : "❚❚"
            }

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.dimColor
                text: formatTime(root.service.progressMs)
            }

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.accentColor
                text: {
                    var total = root.service.currentTrack ? root.service.currentTrack.duration_ms : 1
                    var progress = root.service.progressMs
                    var ratio = Math.min(1, progress / Math.max(1, total))
                    var barLen = 20
                    var filled = Math.round(ratio * barLen)
                    return "━".repeat(filled) + "╺" + "─".repeat(Math.max(0, barLen - filled - 1))
                }
            }

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.dimColor
                text: formatTime(root.service.currentTrack ? root.service.currentTrack.duration_ms : 0)
            }
        }

        // Equalizer
        AsciiEqualizer {
            playing: root.service.isPlaying
            barColor: root.accentColor
        }
    }

    // No track playing
    Text {
        visible: root.service.currentTrack === null && !root.service.noDevice
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: I18n.tr("panels.spotify.no-track")
    }

    Item { Layout.preferredHeight: Style.marginS }

    // Playback controls
    PlaybackControls {
        isPlaying: root.service.isPlaying
        shuffleOn: root.service.shuffleState
        repeatMode: root.service.repeatState
        volume: root.service.volume

        onPlayPauseClicked: root.service.togglePlayPause()
        onNextClicked: root.service.next()
        onPrevClicked: root.service.prev()
        onShuffleClicked: root.service.toggleShuffle()
        onRepeatClicked: root.service.cycleRepeat()
    }

    Item { Layout.preferredHeight: Style.marginS }

    // Navigation options
    Row {
        spacing: Style.marginL

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.accentColor
            text: "> playlists"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.navigate("playlists", {})
            }
        }

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.accentColor
            text: "> search"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.navigate("search", {})
            }
        }

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.accentColor
            text: "> queue"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.navigate("queue", {})
            }
        }

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.dimColor
            text: "> logout"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.service.logout()
                    root.service.authenticated = false
                }
            }
        }
    }

    // Loading spinner
    TerminalSpinner {
        spinning: root.service.loading
    }

    function formatTime(ms) {
        var totalSec = Math.floor(ms / 1000)
        var min = Math.floor(totalSec / 60)
        var sec = totalSec % 60
        return min + ":" + (sec < 10 ? "0" : "") + sec
    }
}
