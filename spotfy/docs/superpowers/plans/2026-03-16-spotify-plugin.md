# Spotify Plugin for Noctalia Shell — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Spotify control panel integrated into Noctalia Shell Settings with terminal aesthetic, ASCII animations, and Python backend for Spotify Web API.

**Architecture:** QML panel with dual-Process communication to a Python bridge script (`spotify_bridge.py`). The Python script handles OAuth 2.0 and all Spotify API calls via `spotipy`, returning JSON to stdout. The QML side renders everything with terminal aesthetics using theme colors from `Color.qml` and `Style.qml`.

**Tech Stack:** QML/Qt (Quickshell), Python 3 + spotipy, Noctalia Shell widget system (NLabel, NBox, etc.), Material Design 3 theme colors.

**Spec:** `docs/superpowers/specs/2026-03-16-spotify-plugin-design.md`

**Noctalia Shell root:** `~/.config/quickshell/noctalia-shell/`

---

## File Map

### New Files (under `files/Modules/Panels/Settings/Tabs/Spotify/`)

| File | Responsibility |
|------|----------------|
| `SpotifyTab.qml` | Main tab component with StackView navigation, header prompt, footer playback controls |
| `SpotifyService.qml` | Dual Process (poll + cmd), command queue, JSON parsing, all API methods |
| `screens/Setup.qml` | First-run: Client ID/Secret input, OAuth trigger |
| `screens/NowPlaying.qml` | Current track info, progress bar, equalizer, nav options |
| `screens/Playlists.qml` | List of saved playlists |
| `screens/PlaylistTracks.qml` | Tracks within a selected playlist |
| `screens/Search.qml` | grep> prompt, search results |
| `screens/Queue.qml` | Current playback queue |
| `components/TerminalFrame.qml` | Box-drawing border container with prompt header |
| `components/AsciiEqualizer.qml` | Animated equalizer bars |
| `components/TypeWriter.qml` | Character-by-character text reveal |
| `components/PlaybackControls.qml` | play/pause/skip/prev/volume/shuffle/repeat |
| `components/MarqueeText.qml` | Horizontal scrolling for long text |
| `components/TerminalSpinner.qml` | Braille loading spinner |
| `scripts/spotify_bridge.py` | Python backend: OAuth + all Spotify API commands |

### New Patch Files (under `patches/`)

| File | Responsibility |
|------|----------------|
| `06-SettingsPanel.qml.patch` | Add `Spotify` to `SettingsPanel.Tab` enum |
| `07-SettingsContent.qml.patch` | Add import, Component, and tabsModel entry |
| `08-en.json.patch` | English translations |
| `09-pt.json.patch` | Portuguese translations |

---

## Task 1: Python Backend — `spotify_bridge.py`

**Files:**
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/scripts/spotify_bridge.py`

- [ ] **Step 1: Create the script with argument parsing and config management**

```python
#!/usr/bin/env python3
"""Spotify bridge for Noctalia Shell. Receives commands via CLI args, returns JSON via stdout."""

import sys
import json
import os
import argparse

CONFIG_DIR = os.path.expanduser("~/.config/noctalia-shell")
CONFIG_FILE = os.path.join(CONFIG_DIR, "spotify_config.json")
TOKEN_FILE = os.path.join(CONFIG_DIR, "spotify_token.json")
REDIRECT_URI = "http://localhost:8888/callback"
SCOPES = (
    "user-read-playback-state "
    "user-modify-playback-state "
    "user-read-currently-playing "
    "playlist-read-private "
    "playlist-read-collaborative "
    "user-library-read"
)


def output(data):
    print(json.dumps(data, ensure_ascii=False))
    sys.exit(0)


def error(code, message):
    output({"status": "error", "code": code, "message": message})


def load_config():
    if not os.path.exists(CONFIG_FILE):
        return None
    with open(CONFIG_FILE) as f:
        return json.load(f)


def save_config(client_id, client_secret):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump({"client_id": client_id, "client_secret": client_secret}, f)


def get_spotify_client():
    config = load_config()
    if not config:
        error("not_configured", "Spotify app credentials not configured")
    if not os.path.exists(TOKEN_FILE):
        error("token_expired", "Not authenticated. Run auth first.")
    try:
        import spotipy
        from spotipy.oauth2 import SpotifyOAuth
        auth_manager = SpotifyOAuth(
            client_id=config["client_id"],
            client_secret=config["client_secret"],
            redirect_uri=REDIRECT_URI,
            scope=SCOPES,
            cache_path=TOKEN_FILE,
        )
        token_info = auth_manager.get_cached_token()
        if not token_info:
            error("token_expired", "Token expired. Re-authenticate.")
        if auth_manager.is_token_expired(token_info):
            token_info = auth_manager.refresh_access_token(token_info["refresh_token"])
        sp = spotipy.Spotify(auth_manager=auth_manager)
        return sp
    except Exception as e:
        error("network_error", str(e))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command")

    setup_p = sub.add_parser("setup")
    setup_p.add_argument("client_id")
    setup_p.add_argument("client_secret")
    sub.add_parser("auth")
    sub.add_parser("logout")
    sub.add_parser("status")
    sub.add_parser("play")
    sub.add_parser("pause")
    sub.add_parser("next")
    sub.add_parser("prev")
    volume_p = sub.add_parser("volume")
    volume_p.add_argument("level", type=int)
    shuffle_p = sub.add_parser("shuffle")
    shuffle_p.add_argument("state", choices=["on", "off"])
    repeat_p = sub.add_parser("repeat")
    repeat_p.add_argument("mode", choices=["off", "track", "context"])
    sub.add_parser("playlists")
    playlist_p = sub.add_parser("playlist")
    playlist_p.add_argument("id")
    pt_p = sub.add_parser("playlist_tracks")
    pt_p.add_argument("id")
    search_p = sub.add_parser("search")
    search_p.add_argument("query", nargs="+")
    queue_p = sub.add_parser("queue")
    queue_p.add_argument("uri")
    sub.add_parser("queue_list")

    args = parser.parse_args()

    if not args.command:
        error("invalid_command", "No command provided")

    if args.command == "setup":
        if not args.client_id or not args.client_secret:
            error("invalid_input", "Client ID and Secret are required")
        save_config(args.client_id, args.client_secret)
        output({"status": "ok"})

    elif args.command == "auth":
        cmd_auth()

    elif args.command == "status":
        cmd_status()

    elif args.command == "play":
        sp = get_spotify_client()
        try:
            sp.start_playback()
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "pause":
        sp = get_spotify_client()
        try:
            sp.pause_playback()
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "next":
        sp = get_spotify_client()
        try:
            sp.next_track()
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "prev":
        sp = get_spotify_client()
        try:
            sp.previous_track()
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "volume":
        sp = get_spotify_client()
        try:
            sp.volume(args.level)
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "shuffle":
        sp = get_spotify_client()
        try:
            sp.shuffle(args.state == "on")
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "repeat":
        sp = get_spotify_client()
        try:
            sp.repeat(args.mode)
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "playlists":
        cmd_playlists()

    elif args.command == "playlist":
        sp = get_spotify_client()
        try:
            sp.start_playback(context_uri=f"spotify:playlist:{args.id}")
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "playlist_tracks":
        cmd_playlist_tracks(args.id)

    elif args.command == "search":
        cmd_search(" ".join(args.query))

    elif args.command == "queue":
        sp = get_spotify_client()
        try:
            sp.add_to_queue(args.uri)
            output({"status": "ok"})
        except Exception as e:
            handle_playback_error(e)

    elif args.command == "queue_list":
        cmd_queue_list()

    elif args.command == "logout":
        # Delete token file to force re-auth
        if os.path.exists(TOKEN_FILE):
            os.remove(TOKEN_FILE)
        output({"status": "ok"})


def handle_playback_error(e):
    msg = str(e)
    if "NO_ACTIVE_DEVICE" in msg or "No active device" in msg:
        error("no_active_device", "No active Spotify device found")
    elif "PREMIUM_REQUIRED" in msg or "Premium required" in msg:
        error("not_premium", "Spotify Premium required for playback control")
    elif "429" in msg:
        error("rate_limited", "Rate limited. Try again shortly.")
    else:
        error("api_error", msg)


def cmd_auth():
    config = load_config()
    if not config:
        error("not_configured", "Run setup first")
    try:
        import spotipy
        from spotipy.oauth2 import SpotifyOAuth
        import threading

        auth_manager = SpotifyOAuth(
            client_id=config["client_id"],
            client_secret=config["client_secret"],
            redirect_uri=REDIRECT_URI,
            scope=SCOPES,
            cache_path=TOKEN_FILE,
            open_browser=True,
        )
        # This blocks until browser callback or timeout
        import signal

        def timeout_handler(signum, frame):
            error("auth_timeout", "Authorization timed out after 120 seconds")

        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(120)

        token_info = auth_manager.get_access_token(as_dict=True)
        signal.alarm(0)

        if token_info:
            sp = spotipy.Spotify(auth_manager=auth_manager)
            user = sp.current_user()
            premium = user.get("product", "free") == "premium"
            output({
                "status": "ok",
                "user": user.get("display_name", "Unknown"),
                "premium": premium,
            })
        else:
            error("auth_failed", "Failed to obtain token")
    except SystemExit:
        raise
    except Exception as e:
        error("auth_failed", str(e))


def cmd_status():
    sp = get_spotify_client()
    try:
        pb = sp.current_playback()
        if not pb or not pb.get("device"):
            output({
                "is_playing": False,
                "no_device": True,
                "track": None,
            })
            return
        track = pb.get("item")
        track_data = None
        if track:
            artists = ", ".join(a["name"] for a in track.get("artists", []))
            album = track.get("album", {})
            images = album.get("images", [])
            art_url = images[0]["url"] if images else ""
            track_data = {
                "name": track.get("name", "Unknown"),
                "artist": artists,
                "album": album.get("name", "Unknown"),
                "album_art_url": art_url,
                "duration_ms": track.get("duration_ms", 0),
                "uri": track.get("uri", ""),
            }
        device = pb.get("device", {})
        output({
            "is_playing": pb.get("is_playing", False),
            "no_device": False,
            "track": track_data,
            "progress_ms": pb.get("progress_ms", 0),
            "volume": device.get("volume_percent", 0),
            "shuffle": pb.get("shuffle_state", False),
            "repeat": pb.get("repeat_state", "off"),
            "device": {
                "name": device.get("name", "Unknown"),
                "type": device.get("type", "Unknown"),
            },
        })
    except Exception as e:
        handle_playback_error(e)


def cmd_playlists():
    sp = get_spotify_client()
    try:
        results = sp.current_user_playlists(limit=50)
        items = []
        for pl in results.get("items", []):
            items.append({
                "id": pl["id"],
                "name": pl["name"],
                "track_count": pl["tracks"]["total"],
            })
        output({"items": items})
    except Exception as e:
        error("api_error", str(e))


def cmd_playlist_tracks(playlist_id):
    sp = get_spotify_client()
    try:
        results = sp.playlist_tracks(playlist_id, limit=100)
        items = []
        for item in results.get("items", []):
            track = item.get("track")
            if not track:
                continue
            artists = ", ".join(a["name"] for a in track.get("artists", []))
            items.append({
                "name": track.get("name", "Unknown"),
                "artist": artists,
                "album": track.get("album", {}).get("name", "Unknown"),
                "duration_ms": track.get("duration_ms", 0),
                "uri": track.get("uri", ""),
            })
        output({"items": items})
    except Exception as e:
        error("api_error", str(e))


def cmd_search(query):
    sp = get_spotify_client()
    try:
        results = sp.search(q=query, limit=15, type="track,artist")
        tracks = []
        for t in results.get("tracks", {}).get("items", []):
            artists = ", ".join(a["name"] for a in t.get("artists", []))
            tracks.append({
                "name": t.get("name", "Unknown"),
                "artist": artists,
                "album": t.get("album", {}).get("name", "Unknown"),
                "uri": t.get("uri", ""),
            })
        artists = []
        for a in results.get("artists", {}).get("items", []):
            artists.append({
                "name": a.get("name", "Unknown"),
                "uri": a.get("uri", ""),
            })
        output({"tracks": tracks, "artists": artists})
    except Exception as e:
        error("api_error", str(e))


def cmd_queue_list():
    sp = get_spotify_client()
    try:
        q = sp.queue()
        items = []
        for t in q.get("queue", [])[:20]:
            artists = ", ".join(a["name"] for a in t.get("artists", []))
            items.append({
                "name": t.get("name", "Unknown"),
                "artist": artists,
                "uri": t.get("uri", ""),
            })
        output({"items": items})
    except Exception as e:
        error("api_error", str(e))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Make the script executable and test with --help**

Run: `chmod +x files/Modules/Panels/Settings/Tabs/Spotify/scripts/spotify_bridge.py && python3 files/Modules/Panels/Settings/Tabs/Spotify/scripts/spotify_bridge.py --help`
Expected: Usage help output without errors.

- [ ] **Step 3: Test error path without config**

Run: `python3 files/Modules/Panels/Settings/Tabs/Spotify/scripts/spotify_bridge.py status`
Expected: `{"status": "error", "code": "not_configured", "message": "Spotify app credentials not configured"}`

- [ ] **Step 4: Commit**

```bash
git add files/Modules/Panels/Settings/Tabs/Spotify/scripts/spotify_bridge.py
git commit -m "feat(spotify): add Python backend bridge script"
```

---

## Task 2: Terminal UI Components

**Files:**
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/components/TerminalFrame.qml`
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/components/AsciiEqualizer.qml`
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/components/TypeWriter.qml`
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/components/MarqueeText.qml`
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/components/TerminalSpinner.qml`
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/components/PlaybackControls.qml`

### Step-by-step for each component:

- [ ] **Step 1: Create TerminalFrame.qml**

Container with box-drawing borders and a prompt header. Uses theme colors.

```qml
import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
    id: root

    property string prompt: "spotfy@noctalia:~$"
    property alias contentItem: contentArea.data

    implicitHeight: outerColumn.implicitHeight
    implicitWidth: outerColumn.implicitWidth

    readonly property string borderColor: Color.mOutline
    readonly property string bgColor: Color.mSurface
    readonly property string textColor: Color.mOnSurface
    readonly property string promptColor: Color.mPrimary
    readonly property int fontSize: Style.fontSizeM

    ColumnLayout {
        id: outerColumn
        anchors.fill: parent
        spacing: 0

        // Top border
        Text {
            Layout.fillWidth: true
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.borderColor
            text: "╔" + "═".repeat(Math.max(0, Math.floor(root.width / charWidth()) - 2)) + "╗"

            function charWidth() {
                return font.pixelSize * 0.6
            }
        }

        // Content area with side borders
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.borderColor
                text: "║"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Style.marginS
                spacing: Style.marginXS

                // Prompt line
                Row {
                    spacing: Style.marginXS

                    Text {
                        font.family: "monospace"
                        font.pixelSize: root.fontSize
                        color: root.promptColor
                        text: root.prompt
                    }

                    // Blinking cursor
                    Text {
                        font.family: "monospace"
                        font.pixelSize: root.fontSize
                        color: root.promptColor
                        text: "█"
                        visible: cursorTimer.cursorVisible

                        Timer {
                            id: cursorTimer
                            property bool cursorVisible: true
                            interval: 500
                            repeat: true
                            running: root.visible
                            onTriggered: cursorVisible = !cursorVisible
                        }
                    }
                }

                // User content goes here
                Item {
                    id: contentArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.borderColor
                text: "║"
            }
        }

        // Bottom border
        Text {
            Layout.fillWidth: true
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.borderColor
            text: "╚" + "═".repeat(Math.max(0, Math.floor(root.width / charWidth()) - 2)) + "╝"

            function charWidth() {
                return font.pixelSize * 0.6
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgColor
        opacity: 0.95
        z: -1
        radius: Style.radiusS
    }
}
```

- [ ] **Step 2: Create AsciiEqualizer.qml**

```qml
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
```

- [ ] **Step 3: Create TypeWriter.qml**

```qml
import QtQuick
import qs.Commons

Item {
    id: root

    property string fullText: ""
    property int charDelay: 30
    property bool animating: false
    property color textColor: Color.mOnSurface

    signal finished()

    implicitHeight: display.implicitHeight
    implicitWidth: display.implicitWidth

    Text {
        id: display
        font.family: "monospace"
        font.pixelSize: Style.fontSizeM
        color: root.textColor
        text: ""
    }

    property int _charIndex: 0

    Timer {
        id: typeTimer
        interval: root.charDelay
        repeat: true
        running: false
        onTriggered: {
            if (root._charIndex < root.fullText.length) {
                display.text += root.fullText[root._charIndex]
                root._charIndex++
            } else {
                typeTimer.running = false
                root.animating = false
                root.finished()
            }
        }
    }

    function start() {
        display.text = ""
        _charIndex = 0
        animating = true
        typeTimer.running = true
    }

    function skipToEnd() {
        typeTimer.running = false
        display.text = fullText
        _charIndex = fullText.length
        animating = false
        finished()
    }
}
```

- [ ] **Step 4: Create MarqueeText.qml**

```qml
import QtQuick
import qs.Commons

Item {
    id: root

    property string text: ""
    property color textColor: Color.mOnSurface
    property int scrollSpeed: 60
    property real maxWidth: 200

    implicitHeight: clippedText.implicitHeight
    implicitWidth: Math.min(maxWidth, fullText.implicitWidth)
    clip: true

    readonly property bool needsScroll: fullText.implicitWidth > root.maxWidth

    Text {
        id: fullText
        font.family: "monospace"
        font.pixelSize: Style.fontSizeM
        color: root.textColor
        text: root.needsScroll ? root.text + "   " + root.text : root.text
        visible: false
    }

    Text {
        id: clippedText
        font.family: "monospace"
        font.pixelSize: Style.fontSizeM
        color: root.textColor
        text: root.needsScroll ? root.text + "   " + root.text : root.text
        x: 0

        NumberAnimation on x {
            id: scrollAnim
            from: 0
            to: -(fullText.implicitWidth / 2)
            duration: root.text.length * root.scrollSpeed
            loops: Animation.Infinite
            running: root.needsScroll && root.visible
        }
    }
}
```

- [ ] **Step 5: Create TerminalSpinner.qml**

```qml
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
```

- [ ] **Step 6: Create PlaybackControls.qml**

```qml
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
```

- [ ] **Step 7: Commit all components**

```bash
git add files/Modules/Panels/Settings/Tabs/Spotify/components/
git commit -m "feat(spotify): add terminal UI components"
```

---

## Task 3: SpotifyService.qml

**Files:**
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/SpotifyService.qml`

- [ ] **Step 1: Create SpotifyService with dual Process and command queue**

```qml
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
```

- [ ] **Step 2: Commit**

```bash
git add files/Modules/Panels/Settings/Tabs/Spotify/SpotifyService.qml
git commit -m "feat(spotify): add SpotifyService with dual Process and command queue"
```

---

## Task 4: Screens — Setup and NowPlaying

**Files:**
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/screens/Setup.qml`
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/screens/NowPlaying.qml`

- [ ] **Step 1: Create Setup.qml**

```qml
import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root

    property var service
    signal setupComplete()

    spacing: Style.marginS

    readonly property color textColor: Color.mOnSurface
    readonly property color promptColor: Color.mPrimary
    readonly property color dimColor: Color.mOnSurfaceVariant
    readonly property int fontSize: Style.fontSizeM

    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: I18n.tr("panels.spotify.setup-instruction-1")
    }

    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: I18n.tr("panels.spotify.setup-instruction-2")
    }

    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: I18n.tr("panels.spotify.setup-instruction-3")
    }

    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.textColor
        text: "  redirect_uri: http://localhost:8888/callback"
    }

    Item { Layout.preferredHeight: Style.marginM }

    // Client ID input
    Row {
        spacing: Style.marginXS
        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.promptColor
            text: "client_id>"
        }
        TextInput {
            id: clientIdInput
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.textColor
            width: 300
            clip: true
        }
    }

    // Client Secret input
    Row {
        spacing: Style.marginXS
        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.promptColor
            text: "client_secret>"
        }
        TextInput {
            id: clientSecretInput
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.textColor
            echoMode: TextInput.Password
            width: 300
            clip: true
        }
    }

    Item { Layout.preferredHeight: Style.marginS }

    Row {
        spacing: Style.marginL

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.promptColor
            text: "[" + I18n.tr("panels.spotify.save") + "]"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (clientIdInput.text.trim() && clientSecretInput.text.trim()) {
                        root.service.setup(clientIdInput.text.trim(), clientSecretInput.text.trim())
                    }
                }
            }
        }

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.dimColor
            text: "[" + I18n.tr("panels.spotify.open-dashboard") + "]"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally("https://developer.spotify.com/dashboard")
            }
        }
    }

    // Status messages
    Text {
        id: statusText
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: ""
        visible: text !== ""
    }

    Connections {
        target: root.service
        function onCommandCompleted(command, result) {
            if (command === "setup") {
                statusText.text = I18n.tr("panels.spotify.setup-ok")
                statusText.color = root.promptColor
                // Now trigger auth
                root.service.auth()
            }
            if (command === "auth") {
                root.service.authenticated = true
                root.service.premium = result.premium || false
                root.service.userName = result.user || ""
                root.setupComplete()
            }
        }
        function onCommandError(command, code, message) {
            statusText.text = "[ERR] " + message
            statusText.color = Color.mError
        }
    }
}
```

- [ ] **Step 2: Create NowPlaying.qml**

```qml
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
```

- [ ] **Step 3: Commit**

```bash
git add files/Modules/Panels/Settings/Tabs/Spotify/screens/Setup.qml files/Modules/Panels/Settings/Tabs/Spotify/screens/NowPlaying.qml
git commit -m "feat(spotify): add Setup and NowPlaying screens"
```

---

## Task 5: Screens — Playlists, PlaylistTracks, Search, Queue

**Files:**
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/screens/Playlists.qml`
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/screens/PlaylistTracks.qml`
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/screens/Search.qml`
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/screens/Queue.qml`

- [ ] **Step 1: Create Playlists.qml**

Note: All list screens wrap their Repeater content in a `Flickable` to handle long lists (50+ playlists, 100+ tracks).

```qml
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
```

- [ ] **Step 2: Create PlaylistTracks.qml**

```qml
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
```

- [ ] **Step 3: Create Search.qml**

```qml
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
```

- [ ] **Step 4: Create Queue.qml**

```qml
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
```

- [ ] **Step 5: Commit**

```bash
git add files/Modules/Panels/Settings/Tabs/Spotify/screens/
git commit -m "feat(spotify): add Playlists, PlaylistTracks, Search, and Queue screens"
```

---

## Task 6: SpotifyTab.qml — Main Tab with StackView Navigation

**Files:**
- Create: `files/Modules/Panels/Settings/Tabs/Spotify/SpotifyTab.qml`

- [ ] **Step 1: Create SpotifyTab.qml with StackView navigation and TypeWriter transitions**

```qml
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
```

- [ ] **Step 2: Commit**

```bash
git add files/Modules/Panels/Settings/Tabs/Spotify/SpotifyTab.qml
git commit -m "feat(spotify): add SpotifyTab with StackView navigation and typewriter transitions"
```

---

## Task 7: Patches — Integration with Noctalia Shell

**Files:**
- Create: `patches/06-SettingsPanel.qml.patch`
- Create: `patches/07-SettingsContent.qml.patch`
- Create: `patches/08-en.json.patch`
- Create: `patches/09-pt.json.patch`

- [ ] **Step 1: Create patch 06 — Add Spotify to SettingsPanel.Tab enum**

The implementer MUST read the live `SettingsPanel.qml` to get the exact current enum format. The actual enum has no numeric comments — it's a plain comma-separated list ending with `Wallpaper`. Add a trailing comma to `Wallpaper` and add `Spotify` as the last entry.

```diff
--- a/Modules/Panels/Settings/SettingsPanel.qml
+++ b/Modules/Panels/Settings/SettingsPanel.qml
 // In the Tab enum, change the last entry:
-      Wallpaper
+      Wallpaper,
+      Spotify
```

- [ ] **Step 2: Create patch 07 — Add Spotify tab to SettingsContent.qml**

Three changes in `SettingsContent.qml`. The implementer MUST read the live file to get exact line numbers.

**Change 1 — Import:** Add after the last `import qs.Modules.Panels.Settings.Tabs.*` line:
```qml
import qs.Modules.Panels.Settings.Tabs.Spotify
```

**Change 2 — Component:** Add after the last `Component { id: ...Tab; ...Tab {} }` declaration:
```qml
    Component {
        id: spotifyTab
        SpotifyTab {}
    }
```

**Change 3 — tabsModel:** In `updateTabsModel()`, the function builds a `let newTabs = [...]` array. Add a new entry at the end of that array (before the closing `]`):
```javascript
    {
        "id": SettingsPanel.Tab.Spotify,
        "label": "panels.spotify.title",
        "icon": "settings-spotify",
        "source": spotifyTab
    }
```

**Important:** The `updateTabsModel()` function uses a static `newTabs` array, NOT `.push()`. The entry must go inside the array literal.

- [ ] **Step 3: Create patch 08 — English translations**

```diff
--- a/Assets/Translations/en.json
+++ b/Assets/Translations/en.json
@@ Add to "panels" object:
+    "spotify": {
+      "title": "Spotify",
+      "setup-instruction-1": "Spotify Developer App required.",
+      "setup-instruction-2": "1. Go to developer.spotify.com",
+      "setup-instruction-3": "2. Create app, set redirect URI:",
+      "save": "save",
+      "open-dashboard": "open developer dashboard",
+      "setup-ok": "Credentials saved. Authenticating...",
+      "no-device": "no active device — open Spotify on any device",
+      "not-premium": "Spotify Premium required for playback control",
+      "no-track": "no track playing",
+      "no-results": "no results found",
+      "queue-empty": "queue is empty"
+    }
```

- [ ] **Step 4: Create patch 09 — Portuguese translations**

```diff
--- a/Assets/Translations/pt.json
+++ b/Assets/Translations/pt.json
@@ Add to "panels" object:
+    "spotify": {
+      "title": "Spotify",
+      "setup-instruction-1": "App Spotify Developer necessário.",
+      "setup-instruction-2": "1. Acesse developer.spotify.com",
+      "setup-instruction-3": "2. Crie um app, defina redirect URI:",
+      "save": "salvar",
+      "open-dashboard": "abrir developer dashboard",
+      "setup-ok": "Credenciais salvas. Autenticando...",
+      "no-device": "nenhum dispositivo ativo — abra o Spotify em algum dispositivo",
+      "not-premium": "Spotify Premium necessário para controle de reprodução",
+      "no-track": "nenhuma música tocando",
+      "no-results": "nenhum resultado encontrado",
+      "queue-empty": "fila vazia"
+    }
```

- [ ] **Step 5: Commit all patches**

```bash
git add patches/
git commit -m "feat(spotify): add integration patches for Noctalia Shell"
```

---

## Task 8: README and Final Verification

**Files:**
- Create: `README_SPOTIFY.md` (or update existing README)

- [ ] **Step 1: Update README.md with Spotify plugin documentation**

Add a section covering:
- Feature overview
- Prerequisites (Python 3, spotipy, Spotify Premium, Developer App)
- Installation steps (copy files + apply patches)
- First-run setup (enter Client ID/Secret, authorize)
- Usage

- [ ] **Step 2: Test Python script error paths**

Run: `python3 files/Modules/Panels/Settings/Tabs/Spotify/scripts/spotify_bridge.py status`
Expected: JSON error about not_configured

Run: `python3 files/Modules/Panels/Settings/Tabs/Spotify/scripts/spotify_bridge.py --help`
Expected: Help text

- [ ] **Step 3: Verify all QML files have correct syntax**

Manually review that all QML files:
- Have matching braces
- Import correct modules
- Use `Color.mPrimary` etc. (not hardcoded colors)
- Use `I18n.tr()` for user-facing strings

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "docs(spotify): add README and finalize plugin"
```
