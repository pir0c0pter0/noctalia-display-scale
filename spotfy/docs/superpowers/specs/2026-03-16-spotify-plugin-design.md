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
- **SpotifyService.qml** — Service layer co-located with the tab. Uses two `Process` instances: one dedicated to status polling, one for user-triggered commands. This avoids command conflicts. Placed alongside the tab rather than under `Services/` since it is only consumed by the Spotify UI.
- **spotify_bridge.py** — Lightweight Python script using `spotipy` for OAuth 2.0 and Spotify Web API calls. Returns JSON via stdout. No daemon — each invocation is stateless (token persisted to disk).

### Communication

Unidirectional: QML sends command via Process args → Python returns JSON via stdout.

**Dual Process model:**
- `pollProcess` — Dedicated Process for `status` polling every ~2s via Timer. Timer pauses while a poll is in flight and resumes after response.
- `cmdProcess` — Dedicated Process for user-triggered commands (play, pause, next, search, etc.). Commands are queued: if a command is in flight, subsequent commands are buffered and executed sequentially.

This prevents the race condition where a poll and a user action collide on the same Process instance.

### Relationship with MPRIS / MediaService

Noctalia Shell already has `Services/Media/MediaService.qml` which provides MPRIS-based playback control. When Spotify desktop is running, it registers as an MPRIS player. This plugin uses the **Spotify Web API** instead, which provides access to playlists, search, queue, and works even when controlling playback on other devices (phone, speaker, etc.). The two systems are independent — the Web API commands do not conflict with MPRIS. The plugin does not interact with MediaService.

## Backend — `spotify_bridge.py`

### Commands

| Command | Description | Output JSON |
|---------|-------------|-------------|
| `auth` | Start OAuth flow, open browser, save token | `{"status": "ok", "user": "name"}` |
| `status` | Current player state | See full schema below |
| `play` | Resume playback | `{"status": "ok"}` |
| `pause` | Pause playback | `{"status": "ok"}` |
| `next` | Next track | `{"status": "ok"}` |
| `prev` | Previous track | `{"status": "ok"}` |
| `volume <0-100>` | Set volume | `{"status": "ok"}` |
| `shuffle <on\|off>` | Toggle shuffle | `{"status": "ok"}` |
| `repeat <off\|track\|context>` | Set repeat mode | `{"status": "ok"}` |
| `playlists` | List saved playlists | `{"items": [{"id": "...", "name": "...", "track_count": 42}]}` |
| `playlist <id>` | Play a playlist | `{"status": "ok"}` |
| `playlist_tracks <id>` | List tracks in a playlist | `{"items": [{"name": "...", "artist": "...", "album": "...", "duration_ms": 210000, "uri": "..."}]}` |
| `search <query>` | Search tracks/artists | `{"tracks": [{"name": "...", "artist": "...", "album": "...", "uri": "..."}], "artists": [{"name": "...", "uri": "..."}]}` |
| `queue <uri>` | Add to queue | `{"status": "ok"}` |
| `queue_list` | List current queue (max 20 tracks per Spotify API limitation) | `{"items": [{"name": "...", "artist": "...", "uri": "..."}]}` |
| `setup <client_id> <client_secret>` | Save Spotify app credentials | `{"status": "ok"}` |

### Status Response Schema

```json
{
  "is_playing": true,
  "track": {
    "name": "Track Name",
    "artist": "Artist Name",
    "album": "Album Name",
    "album_art_url": "https://i.scdn.co/image/...",
    "duration_ms": 210000,
    "uri": "spotify:track:..."
  },
  "progress_ms": 45000,
  "volume": 75,
  "shuffle": true,
  "repeat": "off",
  "device": {
    "name": "Device Name",
    "type": "Computer"
  }
}
```

When no active device is available, status returns:
```json
{
  "is_playing": false,
  "no_device": true,
  "track": null
}
```

### Error Response Schema

All errors follow a standard format:

```json
{
  "status": "error",
  "code": "error_code",
  "message": "Human-readable description"
}
```

Error codes:
- `no_active_device` — No Spotify device is active. UI shows terminal message: `"[ERR] no active device — open Spotify on any device"`.
- `not_premium` — Account is not Premium. Detected at auth time. UI shows: `"[ERR] Spotify Premium required for playback control"`.
- `token_expired` — Token could not be refreshed. UI prompts re-auth.
- `network_error` — Network unreachable.
- `rate_limited` — Spotify API rate limit hit. Includes `retry_after` field.
- `not_configured` — Client ID/Secret not yet set up.
- `auth_timeout` — OAuth flow timed out (user didn't authorize in browser).

### OAuth Flow

1. User triggers `auth` command.
2. Script starts HTTP server on `localhost:8888` with a **120-second timeout**.
3. Browser opens with Spotify authorization URL.
4. User authorizes, Spotify redirects to `localhost:8888/callback`.
5. Script captures auth code, exchanges for token, saves to `~/.config/noctalia-shell/spotify_token.json`.
6. Server shuts down.

If the user does not complete authorization within 120 seconds, the server shuts down and returns `{"status": "error", "code": "auth_timeout", "message": "..."}`.

The QML side shows a terminal-style waiting message during the auth flow: `"waiting for browser authorization... (timeout: 120s)"` with the braille spinner. A "cancel" option kills the auth Process.

Token refresh is handled automatically by `spotipy`.

### First-Run Setup

On first use, the plugin shows a setup screen in terminal style:

```
╔══════════════════════════════════════╗
║ spotfy@noctalia:~$ setup             ║
║                                      ║
║  Spotify Developer App required.     ║
║  1. Go to developer.spotify.com      ║
║  2. Create an app                    ║
║  3. Set redirect URI:                ║
║     http://localhost:8888/callback    ║
║                                      ║
║  client_id> _                        ║
║  client_secret> _                    ║
║                                      ║
║  [save]  [open developer dashboard]  ║
╚══════════════════════════════════════╝
```

Credentials stored in `~/.config/noctalia-shell/spotify_config.json`.

### Spotify Premium Detection

At auth time, the script checks the user's subscription level. If the account is Free, the auth response includes `"premium": false`. The UI displays a persistent warning that playback control is unavailable but playlist browsing and search still work.

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

**Album art:** The album art area is a decorative block using box-drawing characters, not an image-to-ASCII conversion. It displays a stylized placeholder (e.g., a music note in block characters). Actual album art rendering is out of scope.

**No active device state:** When `no_device` is true, the Now Playing area shows:
```
║  [ERR] no active device              ║
║  open Spotify on any device          ║
║  to start playback                   ║
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
- **Queue** — Current playback queue (max 20 tracks per Spotify API limitation). Add/remove options.

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
| **Marquee scroll** | Long names | Horizontal scrolling text for track/artist names exceeding available width. Timer at 60ms intervals, pauses when not hovered. |
| **Screen transition** | Navigation | Old content scrolls up rapidly, new content appears with typewriter effect. |

## File Structure

```
files/Modules/Panels/Settings/Tabs/Spotify/
├── SpotifyTab.qml              # Main tab, registers in Settings
├── SpotifyService.qml          # Dual-Process + Python communication
├── screens/
│   ├── NowPlaying.qml          # Main player screen
│   ├── Playlists.qml           # Playlist listing
│   ├── PlaylistTracks.qml      # Tracks within a playlist
│   ├── Search.qml              # Search with grep> prompt
│   ├── Queue.qml               # Playback queue
│   └── Setup.qml               # First-run setup (Client ID/Secret)
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
├── 06-SettingsPanel.qml.patch  # Add Spotify entry to SettingsPanel.Tab enum
├── 07-SettingsContent.qml.patch# Add import, Component, and tabsModel entry for SpotifyTab
├── 08-en.json.patch            # English translations
└── 09-pt.json.patch            # Portuguese translations
```

### Tab Registration (Patches 06-07)

Adding a tab to Noctalia Shell Settings requires changes in two files:

1. **SettingsPanel.qml** — Add `Spotify` to the `SettingsPanel.Tab` enum.
2. **SettingsContent.qml** — Three changes:
   - Add `import qs.Modules.Panels.Settings.Tabs.Spotify`
   - Add `Component { id: spotifyTab; SpotifyTab {} }`
   - Add the tab entry to the `tabsModel` array in `initialize()`

Patch numbering continues from the existing series (01-05 are display scale patches).

## Dependencies

- **Python 3** with `spotipy` package (`pip install spotipy`).
- **Spotify Premium** account required for playback control. Free accounts can browse playlists and search but cannot control playback.
- **Spotify Developer App** — user must register at developer.spotify.com to get Client ID and Client Secret.

## Internationalization

Supports English (`en.json`) and Portuguese (`pt.json`) via Noctalia Shell's existing i18n system. All user-visible strings use translation keys.
