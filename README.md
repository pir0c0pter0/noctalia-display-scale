# Noctalia Shell - Display Scale Settings

Feature contribution for [Noctalia Shell](https://github.com/nicop2000/noctalia-shell): a Windows-style display scale configuration panel.

## Goal

**Merge this feature into the official Noctalia Shell project.**

This adds a "Scale" subtab to **Settings > Display** that allows users to change the display scale per monitor using a percentage-based dropdown (75% - 300%), similar to Windows display settings.

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

## What's included

### New file

- `files/Modules/Panels/Settings/Tabs/Display/ScaleSubTab.qml` — The complete scale configuration UI

### Patches (for existing files)

| Patch | Target file | Description |
|-------|-------------|-------------|
| `01-DisplayTab.qml.patch` | `Modules/Panels/Settings/Tabs/Display/DisplayTab.qml` | Adds the "Scale" tab button and includes `ScaleSubTab` |
| `02-CompositorService.qml.patch` | `Services/Compositor/CompositorService.qml` | Adds `setOutputScale()` facade function |
| `03-NiriService.qml.patch` | `Services/Compositor/NiriService.qml` | Adds `setOutputScale()` using `niri msg output <name> scale <value>` |
| `04-en.json.patch` | `Assets/Translations/en.json` | English translation keys |
| `05-pt.json.patch` | `Assets/Translations/pt.json` | Portuguese translation keys |

## How to apply manually

1. Copy `ScaleSubTab.qml` to `Modules/Panels/Settings/Tabs/Display/` in your noctalia-shell directory

2. Apply patches:
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

## How it works

1. The **ScaleSubTab** iterates over all connected monitors via `Quickshell.screens`
2. For each monitor, it reads the current scale from `CompositorService.displayScales`
3. The user selects a percentage from the dropdown
4. `CompositorService.setOutputScale()` delegates to the compositor backend
5. `NiriService.setOutputScale()` executes `niri msg output <output> scale <value>`
6. Niri applies the scale change immediately (temporary, survives until config reload)
7. The outputs are re-queried to update the UI

## Compositor support

Currently implemented for **Niri** via `niri msg output <output> scale <value>`. The `CompositorService` facade makes it straightforward to add support for other compositors (Hyprland, Sway, etc.) by implementing `setOutputScale()` in their respective service files.

## License

This contribution follows the same license as the Noctalia Shell project.
