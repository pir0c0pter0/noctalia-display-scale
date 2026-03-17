# Spotify Control Plugin for Noctalia Shell

## Overview

A QML panel integrated into Noctalia Shell's Settings that provides full Spotify control with a retro terminal aesthetic. Features ASCII animations, hierarchical terminal-style navigation, and a Python backend for Spotify API communication.

## Architecture

### Components

```
┌─────────────────────────────────────┐
│         Noctalia Shell (QML)        │
│                                     │
│  ┌───────────────────────────────┐  │
│  │     SpotifyTab.qml (UI)      │  │
│  │  ┌─────────┐ ┌────────────┐  │  │
│  │  │TermView │ │ AsciiAnims │  │  │
│  │  └────┬────┘ └─────┬──────┘  │  │
│  │       │             │         │  │
│  │  ┌────▼─────────────▼──────┐  │  │
│  │  │   SpotifyService.qml    │  │  │
│  │  │  (Process + JSON parse) │  │  │
│  │  └────────────┬────────────┘  │  │
│  └───────────────│───────────────┘  │
│                  │ Process/stdout    │
│  ┌───────────────▼───────────────┐  │
│  │   spotify_bridge.py           │  │
│  │  - OAuth server (porta local) │  │
│  │  - API calls (spotipy)        │  │
│  │  - JSON para stdout           │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

- **SpotifyTab.qml** — Main component registered as a tab in the Noctalia Settings panel.
- **SpotifyService.qml** — Service layer using Quickshell's `Process` to invoke `spotify_bridge.py` with CLI commands, parsing JSON responses from stdout.
- **spotify_bridge.py** — Lightweight Python script using `spotipy` for OAuth 2.0 and Spotify Web API calls. Returns JSON via stdout. No daemon — each invocation is stateless (token persisted to disk).

### Communication

Unidirectional: QML sends command via Process args → Python returns JSON via stdout. Polling via QML Timer (~2s) for player status updates.

## Backend — `spotify_bridge.py`

### Commands

| Command | Description | Output JSON |
|---------|-------------|-------------|
| `auth` | Start OAuth flow, open browser, save token | `{"status": "ok", "user": "name"}` |
| `status` | Current player state | `{"is_playing": true, "track": {...}, "progress_ms": 12000}` |
| `play` | Resume playback | `{"status": "ok"}` |
| `pause` | Pause playback | `{"status": "ok"}` |
| `next` | Next track | `{"status": "ok"}` |
| `prev` | Previous track | `{"status": "ok"}` |
| `volume <0-100>` | Set volume | `{"status": "ok"}` |
| `shuffle <on\|off>` | Toggle shuffle | `{"status": "ok"}` |
| `repeat <off\|track\|context>` | Set repeat mode | `{"status": "ok"}` |
| `playlists` | List saved playlists | `{"items": [{...}]}` |
| `playlist <id>` | Play a playlist | `{"status": "ok"}` |
| `playlist_tracks <id>` | List tracks in a playlist | `{"items": [{...}]}` |
| `search <query>` | Search tracks/artists | `{"tracks": [...], "artists": [...]}` |
| `queue <uri>` | Add to queue | `{"status": "ok"}` |
| `queue_list` | List current queue | `{"items": [{...}]}` |

### OAuth Flow

1. User triggers `auth` command.
2. Script starts HTTP server on `localhost:8888`.
3. Browser opens with Spotify authorization URL.
4. User authorizes, Spotify redirects to `localhost:8888/callback`.
5. Script captures auth code, exchanges for token, saves to `~/.config/noctalia-shell/spotify_token.json`.
6. Server shuts down.

Token refresh is handled automatically by `spotipy`.

### Configuration

User must create an app at Spotify Developer Dashboard and provide Client ID + Client Secret. Stored in `~/.config/noctalia-shell/spotify_config.json`.

## UI Design

### Terminal Theme

- Monospace font, colors from Noctalia Shell theme (no hardcoded colors).
- Box-drawing character borders (`╔═╗║╚═╝`).
- All text styled to resemble terminal output.

### Screen Layout — Now Playing (Main)

```
╔══════════════════════════════════════╗
║ spotfy@noctalia:~$ now-playing       ║
║                                      ║
║  ▄▄▄▄▄▄▄▄▄▄                         ║
║  █ ALBUM  █  Track Name             ║
║  █  ART   █  Artist Name            ║
║  █ (ascii)█  Album Name             ║
║  ▀▀▀▀▀▀▀▀▀▀                         ║
║                                      ║
║  ▶ 1:23 ━━━━━━━━━━━━━━━━━━━━ 3:45   ║
║                                      ║
║  ▁▂▃▅▇▅▃▂▁▂▃▅▇▅▃▂▁▂▃  equalizer    ║
║                                      ║
║  [◄◄] [▶/❚❚] [►►]  🔀 🔁  vol:75%  ║
║                                      ║
║  > playlists  search  queue  logout  ║
╚══════════════════════════════════════╝
```

### Navigation — Terminal `cd` Style

- Hierarchical navigation mimicking terminal directory traversal.
- Selecting `playlists` → typing animation `cd playlists/` → playlists screen.
- Selecting a playlist → `cd "Playlist Name"/` → track listing.
- Back → `cd ..` animated → returns to previous screen.
- Path shown in prompt: `spotfy:~$` → `spotfy:~/playlists$` → `spotfy:~/playlists/Rock$`.
- Navigation stack managed via QML StackView or equivalent.

### Sub-screens

- **Playlists** — List with name, track count. Select to play or browse tracks.
- **Search** — Prompt styled as `grep>`, user types query, results appear as terminal "output".
- **Queue** — Current playback queue with add/remove options.

### Fixed Elements

- **Header:** Current "prompt" showing navigation location.
- **Footer:** Playback controls always visible (play/pause, skip, prev).

## ASCII Animations

All animations use QML `Timer` with conditional `running` — only active when visible.

| Animation | Location | Implementation |
|-----------|----------|----------------|
| **Equalizer** | Now Playing | Bars `▁▂▃▅▇` with pseudo-random heights, updating ~100ms. Pauses when music paused. |
| **Blinking cursor** | All prompts | `█` toggling visibility every 500ms on active prompt. |
| **Typewriter effect** | Navigation/transitions | Text appears character by character (~30ms/char) when changing screens (`cd playlists/`). |
| **Loading spinner** | API calls | Rotating braille sequence `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` while waiting for response. |
| **Playing pulse** | Status indicator | `▶` icon opacity oscillates when music is playing. |
| **Marquee scroll** | Long names | Horizontal scrolling text for track/artist names exceeding available width. |
| **Screen transition** | Navigation | Old content scrolls up rapidly, new content appears with typewriter effect. |

## File Structure

```
files/Modules/Panels/Settings/Tabs/Spotify/
├── SpotifyTab.qml              # Main tab, registers in Settings
├── SpotifyService.qml          # Process + Python communication
├── screens/
│   ├── NowPlaying.qml          # Main player screen
│   ├── Playlists.qml           # Playlist listing
│   ├── PlaylistTracks.qml      # Tracks within a playlist
│   ├── Search.qml              # Search with grep> prompt
│   └── Queue.qml               # Playback queue
├── components/
│   ├── TerminalFrame.qml       # Container with box-drawing border + prompt
│   ├── AsciiEqualizer.qml      # Animated equalizer
│   ├── TypeWriter.qml          # Typewriter text effect
│   ├── PlaybackControls.qml    # Fixed footer controls
│   ├── MarqueeText.qml         # Scrolling text for long names
│   └── TerminalSpinner.qml     # Braille loading spinner
└── scripts/
    └── spotify_bridge.py       # OAuth + API backend

patches/
├── 06-SettingsTab.qml.patch    # Add Spotify tab to Settings
├── 07-en.json.patch            # English translations
└── 08-pt.json.patch            # Portuguese translations
```

## Dependencies

- **Python 3** with `spotipy` package (`pip install spotipy`).
- **Spotify Premium** account (required for playback control via Web API).
- **Spotify Developer App** — user must register at developer.spotify.com to get Client ID and Client Secret.

## Internationalization

Supports English (`en.json`) and Portuguese (`pt.json`) via Noctalia Shell's existing i18n system. All user-visible strings use translation keys.
