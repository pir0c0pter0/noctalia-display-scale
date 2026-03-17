import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root

    // State
    property bool authenticated: false
    property bool premium: false
    property string userName: ""
    property bool isPlaying: false
    property bool noDevice: false
    property var currentTrack: null
    property int progressMs: 0
    property int volume: 50
    property bool shuffleState: false
    property string repeatState: "off"
    property string deviceName: ""
    property bool loading: false
    property string lastError: ""
    property string lastErrorCode: ""

    // Paths
    readonly property string scriptPath: {
        // Resolve path relative to this QML file
        var base = Qt.resolvedUrl(".")
        return base.toString().replace("file://", "") + "scripts/spotify_bridge.py"
    }

    // Signals
    signal authCompleted(bool success, string message)
    signal commandCompleted(string command, var result)
    signal commandError(string command, string code, string message)

    // Poll Timer
    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: root.authenticated && !pollProcess.running && root.visible
        onTriggered: root.fetchStatus()
    }

    // Poll Process — dedicated to status polling
    Process {
        id: pollProcess
        command: ["python3", root.scriptPath, "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (data.status === "error") {
                        root.lastError = data.message
                        root.lastErrorCode = data.code
                        if (data.code === "token_expired") {
                            root.authenticated = false
                        }
                    } else {
                        root.lastError = ""
                        root.lastErrorCode = ""
                        root.isPlaying = data.is_playing || false
                        root.noDevice = data.no_device || false
                        root.currentTrack = data.track || null
                        root.progressMs = data.progress_ms || 0
                        root.volume = data.volume || 0
                        root.shuffleState = data.shuffle || false
                        root.repeatState = data.repeat || "off"
                        if (data.device) {
                            root.deviceName = data.device.name || ""
                        }
                    }
                } catch (e) {
                    Logger.e("SpotifyService", "Failed to parse status:", e)
                }
            }
        }

        stderr: StdioCollector {}
    }

    // Command Process — for user actions
    Process {
        id: cmdProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                try {
                    var data = JSON.parse(text)
                    var cmd = root._currentCommand
                    if (data.status === "error") {
                        root.lastError = data.message
                        root.lastErrorCode = data.code
                        root.commandError(cmd, data.code, data.message)
                    } else {
                        root.lastError = ""
                        root.lastErrorCode = ""
                        root.commandCompleted(cmd, data)
                    }
                } catch (e) {
                    Logger.e("SpotifyService", "Failed to parse command response:", e)
                }
                root._processQueue()
            }
        }

        stderr: StdioCollector {}
    }

    // Command queue
    property var _commandQueue: []
    property string _currentCommand: ""

    function _enqueue(args, cmdName) {
        _commandQueue.push({"args": args, "name": cmdName})
        if (!cmdProcess.running) {
            _processQueue()
        }
    }

    function _processQueue() {
        if (_commandQueue.length === 0) return
        var next = _commandQueue.shift()
        _currentCommand = next.name
        cmdProcess.command = ["python3", root.scriptPath].concat(next.args)
        root.loading = true
        cmdProcess.running = true
    }

    // Public API
    function fetchStatus() {
        if (!pollProcess.running) {
            pollProcess.running = true
        }
    }

    function setup(clientId, clientSecret) {
        _enqueue(["setup", clientId, clientSecret], "setup")
    }

    function auth() {
        _enqueue(["auth"], "auth")
    }

    function logout() {
        _enqueue(["logout"], "logout")
    }

    function play() { _enqueue(["play"], "play") }
    function pause() { _enqueue(["pause"], "pause") }
    function next() { _enqueue(["next"], "next") }
    function prev() { _enqueue(["prev"], "prev") }
    function setVolume(level) { _enqueue(["volume", level.toString()], "volume") }
    function setShuffle(on) { _enqueue(["shuffle", on ? "on" : "off"], "shuffle") }
    function setRepeat(mode) { _enqueue(["repeat", mode], "repeat") }
    function getPlaylists() { _enqueue(["playlists"], "playlists") }
    function playPlaylist(id) { _enqueue(["playlist", id], "playlist") }
    function getPlaylistTracks(id) { _enqueue(["playlist_tracks", id], "playlist_tracks") }
    function search(query) { _enqueue(["search"].concat(query.split(" ")), "search") }
    function addToQueue(uri) { _enqueue(["queue", uri], "queue") }
    function getQueue() { _enqueue(["queue_list"], "queue_list") }

    function togglePlayPause() {
        if (root.isPlaying) pause(); else play()
    }

    function toggleShuffle() {
        setShuffle(!root.shuffleState)
    }

    function cycleRepeat() {
        if (root.repeatState === "off") setRepeat("context")
        else if (root.repeatState === "context") setRepeat("track")
        else setRepeat("off")
    }
}
