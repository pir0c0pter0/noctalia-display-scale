import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import "components"
import "screens"

ColumnLayout {
    id: root
    spacing: 0

    // Navigation state
    property var navStack: ["~"]
    property string currentPath: "spotfy@noctalia:~$"

    SpotifyService {
        id: spotifyService
    }

    // Check if configured on load
    Component.onCompleted: {
        // Try to fetch status — if not_configured error, show setup
        spotifyService.fetchStatus()
    }

    Connections {
        target: spotifyService
        function onCommandError(command, code, message) {
            if (code === "not_configured" || code === "token_expired") {
                if (stackView.depth > 0) stackView.clear()
                stackView.push(setupComponent)
            }
        }
        function onCommandCompleted(command, result) {
            if (command === "auth") {
                spotifyService.authenticated = true
                spotifyService.premium = result.premium || false
                spotifyService.userName = result.user || ""
                navigateTo("~", {})
            }
        }
    }

    // Terminal frame wrapping everything
    TerminalFrame {
        Layout.fillWidth: true
        Layout.fillHeight: true
        prompt: root.currentPath

        contentItem: [
            // TypeWriter for transition animation
            TypeWriter {
                id: transitionText
                anchors.left: parent.left
                anchors.top: parent.top
                textColor: Color.mPrimary
                visible: animating
                z: 10

                onFinished: root._onTransitionFinished()
            },

            StackView {
                id: stackView
                anchors.fill: parent
                anchors.topMargin: transitionText.visible ? transitionText.implicitHeight + Style.marginS : 0

                // Always starts with setup; Component.onCompleted routes to NowPlaying if already authenticated
                initialItem: setupComponent

                pushEnter: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                }
                pushExit: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                }
                popEnter: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                }
                popExit: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                }
            }
        ]
    }

    // Screen components
    Component {
        id: setupComponent
        Setup {
            service: spotifyService
            onSetupComplete: navigateTo("~", {})
        }
    }

    Component {
        id: nowPlayingComponent
        NowPlaying {
            service: spotifyService
            onNavigate: (screen, params) => navigateTo(screen, params)
        }
    }

    Component {
        id: playlistsComponent
        Playlists {
            service: spotifyService
            onNavigate: (screen, params) => navigateTo(screen, params)
            onBack: goBack()
        }
    }

    Component {
        id: playlistTracksComponent
        PlaylistTracks {
            service: spotifyService
            onBack: goBack()
        }
    }

    Component {
        id: searchComponent
        Search {
            service: spotifyService
            onBack: goBack()
        }
    }

    Component {
        id: queueComponent
        Queue {
            service: spotifyService
            onBack: goBack()
        }
    }

    // Transition state — used by _onTransitionFinished() to know what to do
    property var _pendingNav: null  // {action: "push"/"pop", target: Component, params: {}}

    function _onTransitionFinished() {
        if (!_pendingNav) return
        var nav = _pendingNav
        _pendingNav = null
        if (nav.action === "pop") {
            stackView.pop()
        } else if (nav.params && nav.params.id) {
            stackView.push(nav.target, {
                "playlistId": nav.params.id,
                "playlistName": nav.params.name || ""
            })
        } else {
            stackView.push(nav.target)
        }
    }

    function navigateTo(screen, params) {
        var target
        var pathSegment

        switch (screen) {
            case "~":
                navStack = ["~"]
                root.currentPath = "spotfy@noctalia:~$"
                stackView.clear()
                stackView.push(nowPlayingComponent)
                return
            case "playlists":
                target = playlistsComponent
                pathSegment = "playlists"
                break
            case "playlist_tracks":
                target = playlistTracksComponent
                pathSegment = params.name || "tracks"
                break
            case "search":
                target = searchComponent
                pathSegment = "search"
                break
            case "queue":
                target = queueComponent
                pathSegment = "queue"
                break
            default:
                return
        }

        navStack.push(pathSegment)
        root.currentPath = "spotfy@noctalia:~/" + navStack.slice(1).join("/") + "$"

        _pendingNav = { action: "push", target: target, params: params }
        transitionText.fullText = "cd " + pathSegment + "/"
        transitionText.start()
    }

    function goBack() {
        if (navStack.length <= 1) return
        navStack.pop()
        if (navStack.length <= 1) {
            root.currentPath = "spotfy@noctalia:~$"
        } else {
            root.currentPath = "spotfy@noctalia:~/" + navStack.slice(1).join("/") + "$"
        }

        _pendingNav = { action: "pop" }
        transitionText.fullText = "cd .."
        transitionText.start()
    }
}
