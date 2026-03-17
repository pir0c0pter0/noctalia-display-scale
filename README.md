# Noctalia Shell - Feature Contributions

Feature contributions for [Noctalia Shell](https://github.com/nicop2000/noctalia-shell).

## Goal

**Merge these features into the official Noctalia Shell project.**

---

## Feature 1: Display Scale Settings

Adds a "Scale" subtab to **Settings > Display** that allows users to change the display scale per monitor using a percentage-based dropdown (75% - 300%), similar to Windows display settings. The selected scale persists across reboots.

## Preview

The new **Scale** tab appears alongside the existing **Brightness** and **Night Light** tabs:

| Scale | Percentage |
|-------|-----------|
| 0.75  | 75%       |
| 1.0   | 100%      |
| 1.25  | 125%      |
| 1.5   | 150%      |
| 1.75  | 175%      |
| 2.0   | 200%      |
| 2.25  | 225%      |
| 2.5   | 250%      |
| 3.0   | 300%      |

Each connected monitor is shown with its name, resolution, and current scale. A dropdown lets the user change the scale in real time.

### What's included

#### New file

- `files/Modules/Panels/Settings/Tabs/Display/ScaleSubTab.qml` — The complete scale configuration UI

#### Patches

| Patch | Target file | Description |
|-------|-------------|-------------|
| `01-DisplayTab.qml.patch` | `Modules/Panels/Settings/Tabs/Display/DisplayTab.qml` | Adds the "Scale" tab button and includes `ScaleSubTab` |
| `02-CompositorService.qml.patch` | `Services/Compositor/CompositorService.qml` | Adds `setOutputScale()` with persistence and `applySavedScales()` on startup |
| `03-NiriService.qml.patch` | `Services/Compositor/NiriService.qml` | Adds `setOutputScale()` using `niri msg output <name> scale <value>` |
| `04-en.json.patch` | `Assets/Translations/en.json` | English translation keys |
| `05-pt.json.patch` | `Assets/Translations/pt.json` | Portuguese translation keys |
| `06-Settings.qml.patch` | `Commons/Settings.qml` | Adds `display.outputScales` settings property |
| `07-settings-default.json.patch` | `Assets/settings-default.json` | Adds default value for `display.outputScales` |

### How to apply

1. Copy `ScaleSubTab.qml` to `Modules/Panels/Settings/Tabs/Display/` in your noctalia-shell directory
2. Apply patches 01-07

---

## Feature 2: Bar Widget Drag-and-Drop Reordering

Enables users to reorder bar widgets within the same section (left, center, right) by long-press dragging. Widgets animate smoothly during drag, a ghost overlay follows the cursor, and the new order persists to `settings.json`.

### How it works

1. Long-press (300ms) on any bar widget to start dragging
2. A ghost snapshot follows the cursor while the original widget dims
3. Neighboring widgets shift with smooth 150ms animations to show the drop position
4. Release to drop — the widget order is saved immediately
5. Press Escape or drag outside the bar to cancel

### What's included

#### New file

- `files/Modules/Bar/Extras/BarDragOverlay.qml` — Ghost overlay component using `ShaderEffectSource`

#### Patches

| Patch | Target file | Description |
|-------|-------------|-------------|
| `08-BarWidgetLoader.qml.patch` | `Modules/Bar/Extras/BarWidgetLoader.qml` | Adds `visualOffset` property, `Behavior` animation, and `transform: Translate` |
| `09-Bar.qml.patch` | `Modules/Bar/Bar.qml` | Drag state, coordination functions, overlay, cursor tracking MouseArea, Escape handler, vertical section `objectName`s |
| `10-BarService.qml.patch` | `Services/UI/BarService.qml` | `moveWidget()` function for reorder + persist to settings |

### How to apply

1. Copy `BarDragOverlay.qml` to `Modules/Bar/Extras/` in your noctalia-shell directory
2. Apply patches 08-10

---

## Applying all patches

1. Copy new files to your noctalia-shell directory:
```bash
cp files/Modules/Panels/Settings/Tabs/Display/ScaleSubTab.qml ~/.config/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Display/
cp files/Modules/Bar/Extras/BarDragOverlay.qml ~/.config/quickshell/noctalia-shell/Modules/Bar/Extras/
```

2. Apply all patches:
```bash
cd ~/.config/quickshell/noctalia-shell
for patch in /path/to/noctalia/patches/*.patch; do
  patch -p1 < "$patch"
done
```

3. Restart Quickshell:
```bash
quickshell -c noctalia-shell
```

## Technical Details

### Display Scale

1. The **ScaleSubTab** iterates over all connected monitors via `Quickshell.screens`
2. For each monitor, it reads the current scale from `CompositorService.displayScales`
3. The user selects a percentage from the dropdown
4. `CompositorService.setOutputScale()` delegates to the compositor backend and saves the preference
5. `NiriService.setOutputScale()` executes `niri msg output <output> scale <value>`
6. On next startup, `CompositorService.applySavedScales()` restores saved scales automatically

Currently implemented for **Niri**. The `CompositorService` facade makes it straightforward to add support for other compositors.

### Bar Widget Drag Reorder

- A bar-level `MouseArea` (`dragTracker`) with `pressAndHoldInterval: 300` detects long-press
- Normal clicks pass through unaffected (the dragTracker has `z: -1`)
- Visual displacement uses `transform: Translate` on `BarWidgetLoader` to work inside `RowLayout`/`ColumnLayout`
- `ShaderEffectSource` captures a ghost snapshot before dimming the original widget
- `ListModel.move()` reorders in-memory, `BarService.moveWidget()` persists to `settings.json`
- Works for both horizontal and vertical bar orientations

## License

This contribution follows the same license as the Noctalia Shell project.
