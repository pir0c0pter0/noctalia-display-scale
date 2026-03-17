# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **feature contribution module** for [Noctalia Shell](https://github.com/nicop2000/noctalia-shell), a QML/Qt-based Linux desktop shell built on the Quickshell framework. This subdirectory adds a **Display Scale Settings** feature — a "Scale" subtab under Settings > Display that lets users change per-monitor display scale (75%–300%) with persistence across reboots.

This is **not a standalone project** — it produces new QML files and patch files to be applied to an existing Noctalia Shell installation.

## Repository Structure

- `files/` — New source files to copy into Noctalia Shell
- `patches/` — Numbered patch files (01–07) to apply against existing Noctalia Shell files

Patches are numbered in application order and target files in `~/.config/quickshell/noctalia-shell/`.

## How to Apply

```bash
# Copy new file
cp files/Modules/Panels/Settings/Tabs/Display/ScaleSubTab.qml \
   ~/.config/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Display/

# Apply patches in order
cd ~/.config/quickshell/noctalia-shell
for patch in /path/to/patches/*.patch; do
  patch -p1 < "$patch"
done

# Restart
quickshell -c noctalia-shell
```

There is no build system, test suite, or linter — testing is manual against a running Noctalia Shell instance.

## Architecture

```
ScaleSubTab.qml (UI)
  ├── Reads monitors from Quickshell.screens
  ├── Reads current scales from CompositorService.displayScales
  └── Calls CompositorService.setOutputScale(name, scale)
        ├── Persists to Settings.data.display.outputScales
        └── Delegates to NiriService.setOutputScale()
              └── Executes: niri msg output <name> scale <value>

On startup: CompositorService.applySavedScales() restores saved scales.
```

The `CompositorService` is a facade — compositor-specific implementations (currently only Niri) live in separate service files. Adding a new compositor backend means adding a `setOutputScale()` method to that backend's service file.

## QML Conventions (Noctalia Shell)

- `id: root` at component root level
- `readonly property` for computed/derived values
- Arrow functions in signal handlers: `onSelected: key => { ... }`
- Noctalia UI components: `NLabel`, `NBox`, `NText`, `NComboBox`, `NTabButton`
- Translations via `I18n.tr("dotted.key.path")` with optional parameter objects
- Settings persistence via `Settings.data.<section>.<property>` (JsonObject)
- Logging via `Logger.e()` / `Logger.w()` / `Logger.i()`
