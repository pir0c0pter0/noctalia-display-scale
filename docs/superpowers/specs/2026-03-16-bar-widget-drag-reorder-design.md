# Bar Widget Drag-and-Drop Reordering

## Goal

Allow users to reorder widgets within the top bar by long-pressing and dragging them. The widget follows the cursor, other widgets animate to make space in real time, and the new order persists across restarts.

## Constraints

- Reordering is within the same section only (left, center, or right)
- Must not break existing click/hover interactions on widgets
- Must work for both horizontal and vertical bar orientations
- Must respect per-screen widget overrides in settings
- Delivered as patches + new files (same pattern as the Scale Settings feature)
- Touch devices are out of scope (mouse/trackpad only)
- Keyboard-based reordering is out of scope (future work)

## Architecture

### Approach

Qt Quick native `Drag`/`DropArea` is not used. Instead, a manual drag approach with `MouseArea` long-press is implemented. This avoids reparenting complexity and integrates cleanly with the existing `RowLayout` + `Repeater` + `ListModel` architecture.

**Animation strategy**: `Behavior on x`/`Behavior on y` does not work reliably inside `RowLayout`/`ColumnLayout` because the layout engine overrides animated values. Instead, each delegate uses a visual displacement offset (`property real visualOffset: 0` with `Behavior on visualOffset`) applied via `transform: Translate { x: visualOffset }`. The layout manages logical positions, the offset provides smooth animation. This is inspired by the displacement approach in `NReorderCheckboxes.qml`, adapted for layout containers (which use `transform: Translate` instead of direct `y` positioning).

`ListModel.move()` is only called **at drop time**, not during drag. During drag, visual displacement offsets simulate the reordering. This avoids invalidating widget registration keys mid-drag.

### Components

#### Modified: `BarWidgetLoader.qml`

Adds a `MouseArea` overlay with event forwarding:
- Uses `propagateComposedEvents: true` and `preventStealing: true` so normal clicks pass through to widget-internal MouseAreas and parent items cannot steal the drag grab
- `pressAndHoldInterval: 300` — only enters drag mode on long-press
- Normal clicks (< 300ms) are forwarded to the underlying widget via `mouse.accepted = false`
- Tracks cursor position during drag via `onPositionChanged`
- Reports drag state to parent `Bar.qml` via properties
- On release, finalizes the reorder or cancels
- For `Taskbar` widget (which has its own internal drag): the overlay checks `widgetId === "Taskbar"` and skips drag activation to avoid conflict

New properties:
- `isDragging: bool` — true while this widget is being dragged
- `dragStartX: real` / `dragStartY: real` — initial cursor position

#### Modified: `Bar.qml`

Adds drag coordination state:
- `property bool isDragging: false`
- `property string dragSection: ""` — which section is being reordered
- `property int dragFromIndex: -1` — original index of dragged widget
- `property int dragCurrentIndex: -1` — current visual position during drag
- `property Item dragGhostSource: null` — reference to the widget being dragged

Adds to each `Repeater` delegate:
- `property real visualOffset: 0` with `Behavior on visualOffset { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }`
- `transform: Translate { x: visualOffset }` (horizontal) or `Translate { y: visualOffset }` (vertical)

During drag, Bar.qml computes visual offsets for each delegate:
- The dragged widget's offset follows the cursor delta
- Adjacent widgets shift by the dragged widget's width/height to "make space"
- Hit-testing maps cursor position to widget positions and updates `dragCurrentIndex`

Includes the `BarDragOverlay` component.

Adds keyboard focus during drag for Escape handling:
- `Keys.onEscapePressed` cancels drag, resets all visual offsets

#### New: `BarDragOverlay.qml`

A visual overlay positioned above all bar content that renders the "ghost" of the dragged widget.

Properties:
- `active: bool` — bound to `Bar.isDragging`
- `sourceItem: Item` — the widget instance being dragged
- `cursorX: real` / `cursorY: real` — current cursor position

Behavior:
- Uses `ShaderEffectSource` with `live: false` — captures a snapshot at drag start via `scheduleUpdate()` **before** the opacity change, ensuring the ghost is captured at full opacity
- Ghost opacity: 0.8, scale: 1.05
- Original widget opacity drops to 0.3 **after** ShaderEffectSource capture
- On release: ghost fades out (100ms), original widget restores opacity

#### Modified: `BarService.qml`

New function:

```javascript
function moveWidget(screenName, section, fromIndex, toIndex) {
    // Update the settings data
    if (Settings.hasScreenOverride(screenName, "widgets")) {
        var overrideWidgets = Settings.getBarWidgetsForScreen(screenName);
        var arr = overrideWidgets[section];
        var item = arr.splice(fromIndex, 1)[0];
        arr.splice(toIndex, 0, item);
        Settings.setScreenOverride(screenName, "widgets", overrideWidgets);
        Settings.saveImmediate();
    } else {
        var widgets = Settings.data.bar.widgets;
        var arr = widgets[section];
        var item = arr.splice(fromIndex, 1)[0];
        arr.splice(toIndex, 0, item);
        Settings.saveImmediate();
    }
    root.widgetsRevision++;
}
```

Note: `saveImmediate()` is called on both paths (override and non-override) to ensure persistence.

### Interaction Flow

1. User long-presses (300ms) a widget in the bar
2. `ShaderEffectSource` snapshots the widget at full opacity (`live: false`, `scheduleUpdate()`)
3. Widget opacity drops to 0.3, ghost appears at cursor with opacity 0.8 and scale 1.05
4. Bar.qml gains keyboard focus for Escape handling
5. As cursor moves, visual displacement offsets are computed for all delegates in the section — adjacent widgets shift smoothly to simulate reordering
6. `dragCurrentIndex` tracks where the widget would land based on cursor position
7. On mouse release: `ListModel.move(dragFromIndex, dragCurrentIndex)` is called once, then `BarService.moveWidget()` persists the final order. Ghost fades out (100ms), all visual offsets reset to 0
8. On Escape or drag outside bar: cancel — all visual offsets reset to 0, no model change, no save

### Multi-screen behavior

- During drag: only the current screen's bar shows the drag interaction. Other screens are unaffected
- On drop: `widgetsRevision` is bumped, causing all screens without per-screen overrides to sync their ListModels to the new order
- Screens with per-screen widget overrides are only affected if the drag happened on that screen

### Persistence

- The reordered array is saved to `~/.config/noctalia/settings.json`
- Uses existing `Settings.saveImmediate()` mechanism on both code paths
- Respects per-screen overrides: if a screen has a widget override, only that override is modified
- No schema changes needed — widget arrays simply change element order
- `widgetsRevision` is bumped so other screens sync their ListModels

### Deliverables

| Type | Path | Description |
|------|------|-------------|
| New file | `files/Modules/Bar/Extras/BarDragOverlay.qml` | Ghost overlay during drag |
| Patch | `patches/06-BarWidgetLoader.qml.patch` | Long-press MouseArea + drag state + event forwarding |
| Patch | `patches/07-Bar.qml.patch` | Drag coordination, hit-testing, visual offsets, Escape handling |
| Patch | `patches/08-BarService.qml.patch` | `moveWidget()` function for reorder + persist |

Note: patches 01-05 already exist from the Scale Settings feature.

### Edge Cases

- **Single widget in section**: drag activates but no reorder is possible (no-op)
- **Vertical bar**: same logic, but hit-testing and visual offsets use Y axis instead of X
- **Auto-hide bar**: drag prevents auto-hide while active
- **Widget panels open**: drag is disabled while any panel/popup is open (prevents conflicts)
- **Spacer widget**: can be reordered like any other widget
- **Taskbar widget**: has its own internal drag for task items — widget-level drag is skipped for Taskbar to avoid conflict
- **Widget registration keys**: since `ListModel.move()` only happens at drop time (not during drag), registration keys remain valid throughout the drag. After drop, the `widgetsRevision` bump triggers `syncWidgetModel` which handles re-registration
