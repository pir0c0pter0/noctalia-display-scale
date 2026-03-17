# Layout Settings & Scale Limit — Design Spec

## Overview

Add GUI settings for **focus-ring width** and **window gaps** to the Noctalia Shell Display tab, and reduce the display scale maximum from 300% to 200%.

All settings persist across reboots. The niri compositor is configured by editing `~/.config/niri/config.kdl` and reloading via `niri msg action load-config-file`.

## Scope

1. **FocusRingSubTab** — spinner to set focus-ring width (0–8px, default 2)
2. **GapsSubTab** — spinner to set gaps between windows (0–32px, default 8)
3. **ScaleSubTab change** — max scale from 300% → 200%, with `maxScale` property that actively filters the options array
4. Persistence via `Settings.data.display.focusRingWidth` and `Settings.data.display.gaps`
5. On startup, saved values are always applied (matching `applySavedScales()` pattern — no guard)

## Architecture

```
FocusRingSubTab.qml / GapsSubTab.qml (UI)
  └── CompositorService.setFocusRingWidth(width) / .setGaps(gaps)
        ├── Persists to Settings.data.display.focusRingWidth / .gaps
        └── Delegates to NiriService.setFocusRingWidth() / .setGaps()
              ├── Edits ~/.config/niri/config.kdl via sed
              └── Executes: niri msg action load-config-file

On startup: CompositorService.applySavedLayoutSettings()
  └── Calls NiriService.applyLayoutSettings(focusRingWidth, gaps)
      └── Single sed command edits both values atomically
      └── Single niri reload
```

### Why edit config.kdl instead of IPC?

Niri has no IPC command for layout settings (gaps, focus-ring). The only way to change them at runtime is editing `config.kdl` and running `niri msg action load-config-file`. This is the officially supported hot-reload mechanism.

### Sequencing strategy

To avoid file-write races when applying both settings on startup, NiriService exposes an `applyLayoutSettings(focusRingWidth, gaps)` method that runs a single `sed` command editing both values, followed by a single `niri msg action load-config-file`. The individual `setFocusRingWidth()` and `setGaps()` methods (used by the UI) each run their own sed + reload — this is safe because user interaction is sequential.

## New Files

Both files go in `files/Modules/Panels/Settings/Tabs/Display/` (same directory as ScaleSubTab.qml, so no import needed — Quickshell module resolution picks them up automatically).

### `FocusRingSubTab.qml`

- `ColumnLayout` with `id: root`, follows ScaleSubTab pattern
- `NLabel` with title + description (translated)
- `NSpinBox` for width: min 0, max 8, step 1, suffix "px"
- Reads initial value from `Settings.data.display.focusRingWidth`
- On value change: `CompositorService.setFocusRingWidth(value)`
- `NText` note about persistence

### `GapsSubTab.qml`

- Same structure as FocusRingSubTab
- `NSpinBox` for gaps: min 0, max 32, step 1, suffix "px"
- Reads initial value from `Settings.data.display.gaps`
- On value change: `CompositorService.setGaps(value)`
- `NText` note about persistence

## Patches

### Patch 08: DisplayTab.qml
Add two new `NTabButton` entries ("Focus Ring" at index 3, "Gaps" at index 4) and two new sub-tab instantiations in `NTabView`.

### Patch 09: CompositorService.qml
Add methods:
- `setFocusRingWidth(width)` — delegates to backend, persists to Settings
- `setGaps(gaps)` — delegates to backend, persists to Settings
- `applySavedLayoutSettings()` — called on startup after `applySavedScales()`, always applies saved values (no default-check guard, matching `applySavedScales()` pattern). Calls `backend.applyLayoutSettings(focusRingWidth, gaps)` for atomic application.

### Patch 10: NiriService.qml
Add methods:
- `setFocusRingWidth(width)` — sed on config.kdl + reload (for UI use)
- `setGaps(gaps)` — sed on config.kdl + reload (for UI use)
- `applyLayoutSettings(focusRingWidth, gaps)` — single sed + single reload (for startup)
- Helper: `reloadNiriConfig()` — runs `niri msg action load-config-file`

**sed commands (whitespace-tolerant):**
- Gaps: `sed -i 's/^\s*gaps [0-9]\+/    gaps NEW_VALUE/' ~/.config/niri/config.kdl`
- Focus-ring width: `sed -i '/^\s*focus-ring\s*{/,/}/ s/^\(\s*\)width [0-9]\+/\1width NEW_VALUE/' ~/.config/niri/config.kdl`

The focus-ring sed uses a capture group `\(\s*\)` to preserve original indentation. The range `/^\s*focus-ring\s*{/,/}/` scopes the substitution to the focus-ring block. The `width` match is anchored to start-of-line with optional whitespace, preventing accidental rewrites of unrelated properties.

### Patch 11: Settings.qml
Add `focusRingWidth` and `gaps` properties to the `display` JsonObject:
```qml
property JsonObject display: JsonObject {
  property var outputScales: ({})
  property int focusRingWidth: 2
  property int gaps: 8
}
```

### Patch 12: settings-default.json
Add default values:
```json
"display": {
  "outputScales": {},
  "focusRingWidth": 2,
  "gaps": 8
}
```

### Patch 13: en.json
Add translation keys:
- `panels.display.focus-ring-tab`
- `panels.display.focus-ring-title`
- `panels.display.focus-ring-description`
- `panels.display.focus-ring-label`
- `panels.display.focus-ring-note`
- `panels.display.gaps-tab`
- `panels.display.gaps-title`
- `panels.display.gaps-description`
- `panels.display.gaps-label`
- `panels.display.gaps-note`

### Patch 14: pt.json
Portuguese translations for the same keys.

## ScaleSubTab Change

In `ScaleSubTab.qml`, use `maxScale` as an active filter over a master list:

```qml
readonly property real maxScale: 2.0

readonly property var allScaleOptions: [
  { "key": "0.75", "name": "75%", "scale": 0.75 },
  { "key": "1", "name": "100%", "scale": 1.0 },
  { "key": "1.25", "name": "125%", "scale": 1.25 },
  { "key": "1.5", "name": "150%", "scale": 1.5 },
  { "key": "1.75", "name": "175%", "scale": 1.75 },
  { "key": "2", "name": "200%", "scale": 2.0 },
  { "key": "2.25", "name": "225%", "scale": 2.25 },
  { "key": "2.5", "name": "250%", "scale": 2.5 },
  { "key": "3", "name": "300%", "scale": 3.0 }
]

readonly property var scaleOptions: allScaleOptions.filter(o => o.scale <= maxScale)
```

Changing `maxScale` automatically filters the dropdown — no need to manually edit the array.

## Startup Flow

```
Quickshell init
  → CompositorService backend loads
  → backend.initialize()
  → applySavedScales()              (existing)
  → applySavedLayoutSettings()      (new)
      → reads Settings.data.display.focusRingWidth
      → reads Settings.data.display.gaps
      → calls backend.applyLayoutSettings(width, gaps)
      → single sed edits both values in config.kdl
      → single niri reload
```

## Defaults & Ranges

| Setting | Min | Max | Default | Step | Suffix |
|---------|-----|-----|---------|------|--------|
| Focus Ring Width | 0 | 8 | 2 | 1 | px |
| Gaps | 0 | 32 | 8 | 1 | px |
| Display Scale | 75% | 200% | 100% | — | — |
