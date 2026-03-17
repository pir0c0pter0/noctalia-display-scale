# Noctalia Shell - Feature Contributions

Feature contributions for [Noctalia Shell](https://github.com/nicop2000/noctalia-shell), a QML/Qt-based Linux desktop shell built on the Quickshell framework.

**Goal: Merge these features into the official Noctalia Shell project.**

Each subdirectory is an independent feature module containing new QML files and numbered patches to apply against an existing Noctalia Shell installation.

## Features

### Display Scale (`display-scale/`)

Per-monitor display scale configuration under **Settings > Display > Scale**.

- Percentage-based dropdown (75% - 200%)
- Max scale configurable via `maxScale` property (default: 200%)
- Persists across reboots via `Settings.data.display.outputScales`
- Compositor backend: `niri msg output <name> scale <value>`

| Scale | Percentage |
|-------|-----------|
| 0.75  | 75%       |
| 1.0   | 100%      |
| 1.25  | 125%      |
| 1.5   | 150%      |
| 1.75  | 175%      |
| 2.0   | 200%      |

### Focus Ring Width (`display-scale/`)

Configure the width of the focus indicator around the active window under **Settings > Display > Focus Ring**.

- Spinner control: 0-8px (default: 2px)
- Persists via `Settings.data.display.focusRingWidth`
- Edits `~/.config/niri/config.kdl` `focus-ring { width }` and reloads niri

### Window Gaps (`display-scale/`)

Configure spacing between tiled windows under **Settings > Display > Gaps**.

- Spinner control: 0-32px (default: 8px)
- Persists via `Settings.data.display.gaps`
- Edits `~/.config/niri/config.kdl` `layout { gaps }` and reloads niri

### Spotify Plugin (`spotfy/`)

Full Spotify control panel with terminal aesthetic under **Settings > Spotify**.

- OAuth 2.0 authentication flow
- Now Playing, Playlists, Search, Queue screens
- Playback controls (play/pause, next, prev, volume, shuffle, repeat)
- ASCII animations: equalizer bars, typewriter effects, braille spinners
- Python backend (`spotify_bridge.py`) via `spotipy`
- Requires Spotify Premium + Developer App

### Bar Widget Drag Reorder (`widgetsmove/`)

Long-press drag to reorder bar widgets within sections (left, center, right).

- 300ms long-press to initiate drag
- Ghost overlay via `ShaderEffectSource`
- Persists new order to `settings.json`
- Supports horizontal and vertical bar orientations

## Files Structure

```
display-scale/
  files/    -- New QML files (ScaleSubTab, FocusRingSubTab, GapsSubTab)
  patches/  -- Patches 01-14 for existing Noctalia Shell files

spotfy/
  files/    -- SpotifyTab, screens, components, Python bridge
  patches/  -- Patches 06-09

widgetsmove/
  files/    -- BarDragOverlay.qml
  patches/  -- Patches 01-03 (BarWidgetLoader, Bar, BarService)
```

## How to Install

### Automatic Install (recommended)

There are two install scripts depending on your distro:

| Script | Distro | Noctalia Shell path | Requires sudo |
|--------|--------|---------------------|---------------|
| `install.sh` | CachyOS / Arch | `/etc/xdg/quickshell/noctalia-shell` | Yes |
| `install-fedora.sh` | Fedora | `~/.config/quickshell/noctalia-shell` | No |

**CachyOS / Arch:**

```bash
git clone https://github.com/pir0c0pter0/noctalia-display-scale.git
cd noctalia-display-scale
sudo bash install.sh
```

**Fedora:**

```bash
git clone https://github.com/pir0c0pter0/noctalia-display-scale.git
cd noctalia-display-scale
bash install-fedora.sh
```

Both scripts are idempotent — they skip already-applied changes, so you can re-run safely after updates.

After install, `fix-niri-functions.py` (Arch) or `fix-niri-functions-fedora.py` (Fedora) is run automatically to patch NiriService for modular niri configs (split `.kdl` files with includes).

### Key differences between CachyOS and Fedora

| | CachyOS / Arch | Fedora |
|--|---------------|--------|
| Shell location | `/etc/xdg/quickshell/noctalia-shell` (system-wide) | `~/.config/quickshell/noctalia-shell` (per-user) |
| Permissions | Requires `sudo` | No `sudo` needed |
| Install method | Inline patching + patch files | Inline patching only (no patch files needed) |
| Niri config | Single `config.kdl` | Modular config with includes |

### Manual Install

<details>
<summary>Click to expand manual instructions</summary>

#### Display Scale + Focus Ring + Gaps

```bash
# Copy new files
cp display-scale/files/Modules/Panels/Settings/Tabs/Display/*.qml \
   ~/.config/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Display/

# Apply patches in order
cd ~/.config/quickshell/noctalia-shell
for patch in /path/to/noctalia/display-scale/patches/*.patch; do
  patch -p1 < "$patch"
done

# Restart
quickshell -c noctalia-shell
```

#### Spotify Plugin

```bash
# Install dependencies
pip install spotipy

# Copy files
cp -r spotfy/files/Modules/Panels/Settings/Tabs/Spotify \
   ~/.config/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/

# Apply patches
cd ~/.config/quickshell/noctalia-shell
for patch in /path/to/noctalia/spotfy/patches/*.patch; do
  patch -p1 < "$patch"
done
```

#### Bar Widget Drag Reorder

```bash
# Copy files
cp widgetsmove/files/Modules/Bar/Extras/BarDragOverlay.qml \
   ~/.config/quickshell/noctalia-shell/Modules/Bar/Extras/

# Apply patches
cd ~/.config/quickshell/noctalia-shell
for patch in /path/to/noctalia/widgetsmove/patches/*.patch; do
  patch -p1 < "$patch"
done
```

</details>

## Architecture

### Display Settings Flow

```
UI (ScaleSubTab / FocusRingSubTab / GapsSubTab)
  └── CompositorService (facade)
        ├── Persists to Settings.data.display.*
        └── Delegates to NiriService
              ├── Scale: niri msg output <name> scale <value>
              └── Focus Ring / Gaps: sed on config.kdl + niri msg action load-config-file

On startup: CompositorService restores all saved settings automatically.
```

## Compositor Support

Currently implemented for **Niri**. The `CompositorService` facade makes it straightforward to add backends for other compositors (Hyprland, Sway, etc.).

## Translations

All features include English and Portuguese translations.

## License

These contributions follow the same license as the Noctalia Shell project.
