# Bar Widget Drag-and-Drop Reordering

## Goal

Allow users to reorder widgets within the top bar by long-pressing and dragging them. The widget follows the cursor, other widgets animate to make space in real time, and the new order persists across restarts.

## Constraints

- Reordering is within the same section only (left, center, or right)
- Must not break existing click/hover interactions on widgets
- Must work for both horizontal and vertical bar orientations
- Must respect per-screen widget overrides in settings
- Delivered as patches + new files (same pattern as the Scale Settings feature)

## Architecture

### Approach

Qt Quick native `Drag`/`DropArea` is not used. Instead, a manual drag approach with `MouseArea` long-press is implemented. This avoids reparenting complexity and integrates cleanly with the existing `RowLayout` + `Repeater` + `ListModel` architecture. The key insight is that calling `ListModel.move()` during drag causes the `Repeater` to reposition delegates automatically, and `Behavior on x` animations make the transition smooth.

### Components

#### Modified: `BarWidgetLoader.qml`

Adds a `MouseArea` overlay that:
- Detects long-press (300ms) to enter drag mode
- Tracks cursor position during drag via `onPositionChanged`
- Reports drag state to parent `Bar.qml` via properties
- On release, finalizes the reorder or cancels

New properties:
- `isDragging: bool` — true while this widget is being dragged
- `dragStartX: real` / `dragStartY: real` — initial cursor position

#### Modified: `Bar.qml`

Adds drag coordination state:
- `property bool isDragging: false`
- `property string dragSection: ""` — which section is being reordered
- `property int dragFromIndex: -1` — original index of dragged widget
- `property int dragCurrentIndex: -1` — current position during drag
- `property var dragGhostSource: null` — reference to the widget being dragged

Adds to each `Repeater` delegate:
- `Behavior on x` (horizontal) or `Behavior on y` (vertical) with `NumberAnimation { duration: 150; easing.type: Easing.OutQuad }` for smooth reordering animation

Includes the `BarDragOverlay` component.

Adds hit-testing logic:
- During drag, maps cursor position to widget positions in the section
- When cursor crosses the midpoint of an adjacent widget, calls `ListModel.move()` on the section's model to reorder in real time

#### New: `BarDragOverlay.qml`

A visual overlay positioned above all bar content that renders the "ghost" of the dragged widget.

Properties:
- `active: bool` — bound to `Bar.isDragging`
- `sourceItem: Item` — the widget instance being dragged
- `cursorX: real` / `cursorY: real` — current cursor position

Behavior:
- When active, uses `ShaderEffectSource` to capture the widget's visual and renders it at cursor position
- Ghost opacity: 0.8, scale: 1.05
- Original widget opacity drops to 0.3 while dragging
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

### Interaction Flow

1. User long-presses (300ms) a widget in the bar
2. Widget scales up slightly (1.05x), enters drag mode
3. A ghost (ShaderEffectSource snapshot) appears at cursor, opacity 0.8
4. Original widget stays in layout at opacity 0.3 (placeholder)
5. As cursor moves over adjacent widgets in the same section, `ListModel.move()` reorders in real time
6. Other widgets animate smoothly to new positions (150ms ease-out)
7. On mouse release: ghost fades out, `BarService.moveWidget()` persists the final order
8. On Escape or drag outside bar: cancel, widget returns to original position

### Persistence

- The reordered array is saved to `~/.config/noctalia/settings.json`
- Uses existing `Settings.saveImmediate()` mechanism
- Respects per-screen overrides: if a screen has a widget override, only that override is modified
- No schema changes needed — widget arrays simply change element order
- `widgetsRevision` is bumped so other screens sync their ListModels

### Deliverables

| Type | Path | Description |
|------|------|-------------|
| New file | `files/Modules/Bar/Extras/BarDragOverlay.qml` | Ghost overlay during drag |
| Patch | `patches/06-BarWidgetLoader.qml.patch` | Long-press MouseArea + drag state |
| Patch | `patches/07-Bar.qml.patch` | Drag coordination, hit-testing, Behavior animations |
| Patch | `patches/08-BarService.qml.patch` | `moveWidget()` function for reorder + persist |

### Edge Cases

- **Single widget in section**: drag activates but no reorder is possible (no-op)
- **Vertical bar**: same logic, but hit-testing uses Y axis instead of X
- **Auto-hide bar**: drag prevents auto-hide while active
- **Widget panels open**: drag is disabled while any panel/popup is open (prevents conflicts)
- **Spacer widget**: can be reordered like any other widget
