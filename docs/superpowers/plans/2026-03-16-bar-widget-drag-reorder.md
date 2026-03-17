# Bar Widget Drag-and-Drop Reordering — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable users to reorder bar widgets within the same section by long-press dragging, with real-time animation and persistent order.

**Architecture:** Manual drag via MouseArea long-press on BarWidgetLoader. Visual displacement offsets (`transform: Translate`) animate neighbor widgets during drag. A bar-level MouseArea tracks cursor during drag for hit-testing. `ListModel.move()` + `BarService.moveWidget()` finalize order and persist to `settings.json` on drop.

**Tech Stack:** QML/Qt Quick, Quickshell framework, ListModel, ShaderEffectSource

**Spec:** `docs/superpowers/specs/2026-03-16-bar-widget-drag-reorder-design.md`

---

## File Structure

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `files/Modules/Bar/Extras/BarDragOverlay.qml` | Ghost overlay rendering during drag |
| Patch | `patches/08-BarService.qml.patch` (target: `Services/UI/BarService.qml`) | `moveWidget()` function for reorder + persist |
| Patch | `patches/06-BarWidgetLoader.qml.patch` (target: `Modules/Bar/Extras/BarWidgetLoader.qml`) | Long-press detection, drag state, visual offset + transform |
| Patch | `patches/07-Bar.qml.patch` (target: `Modules/Bar/Bar.qml`) | Drag coordination, cursor tracking, visual offsets, overlay, Escape |

---

## Key Design Decisions

### Event forwarding strategy

The drag MouseArea on BarWidgetLoader does NOT try to forward clicks. Instead:
- `enabled: false` by default — the MouseArea starts disabled
- A **bar-level** MouseArea (`dragTracker`) with `pressAndHoldInterval: 300` is used
- On long-press, it identifies which widget is under the cursor, sets `isDragging = true`, and the `dragTracker` takes over cursor tracking
- Normal clicks are never intercepted — the bar-level MouseArea only accepts `Qt.LeftButton` and only activates drag on `pressAndHold`; `onClicked` does `mouse.accepted = false`

This avoids all event-forwarding issues since widget MouseAreas receive events normally unless a long-press specifically starts a drag.

### Cursor tracking

Bar.qml's `dragTracker` MouseArea tracks `onPositionChanged` during drag and maps coordinates to section-local space for hit-testing. No need to relay positions from BarWidgetLoader.

---

## Task 1: BarService.moveWidget() — Persistence function

**Files:**
- Create: `patches/08-BarService.qml.patch` (target: `Services/UI/BarService.qml:625-627`)

- [ ] **Step 1: Write the patch file**

Create `patches/08-BarService.qml.patch`:

```diff
--- a/Services/UI/BarService.qml
+++ b/Services/UI/BarService.qml
@@ -624,4 +624,33 @@
     }
   }
+
+  // Move a widget within a section (reorder) and persist to settings
+  function moveWidget(screenName, section, fromIndex, toIndex) {
+    if (fromIndex === toIndex) return;
+    Logger.d("BarService", "moveWidget:", screenName, section, fromIndex, "→", toIndex);
+
+    if (Settings.hasScreenOverride(screenName, "widgets")) {
+      var overrideWidgets = JSON.parse(JSON.stringify(
+        Settings.getBarWidgetsForScreen(screenName)
+      ));
+      var oArr = overrideWidgets[section];
+      if (!oArr || fromIndex >= oArr.length || toIndex >= oArr.length) return;
+      var oItem = oArr.splice(fromIndex, 1)[0];
+      oArr.splice(toIndex, 0, oItem);
+      Settings.setScreenOverride(screenName, "widgets", overrideWidgets);
+      Settings.saveImmediate();
+    } else {
+      var widgets = Settings.data.bar.widgets;
+      var gArr = widgets[section];
+      if (!gArr || fromIndex >= gArr.length || toIndex >= gArr.length) return;
+      var gItem = gArr.splice(fromIndex, 1)[0];
+      gArr.splice(toIndex, 0, gItem);
+      Settings.saveImmediate();
+    }
+    root.widgetsRevision++;
+  }
 }
```

Note: override path deep-copies via `JSON.parse(JSON.stringify(...))` to avoid mutating live settings. Variables use distinct names (`oArr`/`gArr`) to avoid shadowing.

- [ ] **Step 2: Verify patch applies cleanly**

```bash
cd ~/.config/quickshell/noctalia-shell && patch --dry-run -p1 < /home/mariostjr/Documents/noctalia/patches/08-BarService.qml.patch
```

Expected: `patching file Services/UI/BarService.qml` — no errors.

- [ ] **Step 3: Commit**

```bash
cd /home/mariostjr/Documents/noctalia && git add patches/08-BarService.qml.patch && git commit -m "feat: add moveWidget() to BarService for drag reorder persistence"
```

---

## Task 2: BarDragOverlay.qml — Ghost visual component

**Files:**
- Create: `files/Modules/Bar/Extras/BarDragOverlay.qml`

- [ ] **Step 1: Create the overlay component**

```qml
import QtQuick

Item {
  id: overlay
  anchors.fill: parent
  visible: active
  z: 1000

  // Input properties — set by Bar.qml
  property bool active: false
  property Item sourceItem: null
  property bool isVertical: false
  property real cursorX: 0
  property real cursorY: 0

  // Capture ghost snapshot when drag starts
  function captureAndShow() {
    if (!sourceItem) return;
    ghost.sourceItem = sourceItem;
    ghost.width = sourceItem.width;
    ghost.height = sourceItem.height;
    ghost.scheduleUpdate();
    ghost.visible = true;
    ghost.opacity = 0.8;
  }

  // Fade out and clean up
  function hideGhost() {
    fadeOut.start();
  }

  onActiveChanged: {
    if (active) {
      captureAndShow();
    } else {
      hideGhost();
    }
  }

  ShaderEffectSource {
    id: ghost
    visible: false
    live: false
    hideSource: false
    width: 0
    height: 0

    x: overlay.isVertical
       ? Math.round((overlay.width - width) / 2)
       : Math.round(overlay.cursorX - width / 2)
    y: overlay.isVertical
       ? Math.round(overlay.cursorY - height / 2)
       : Math.round((overlay.height - height) / 2)

    scale: 1.05

    NumberAnimation {
      id: fadeOut
      target: ghost
      property: "opacity"
      from: 0.8
      to: 0.0
      duration: 100
      onFinished: {
        ghost.visible = false;
        ghost.sourceItem = null;
      }
    }
  }
}
```

Key fixes vs original:
- `NumberAnimation` is standalone (not `on opacity` property value source) — avoids conflicts with direct `opacity` assignments
- `captureAndShow()` is a callable function so Bar.qml can control timing (call it BEFORE setting widget opacity to 0.3)

- [ ] **Step 2: Commit**

```bash
cd /home/mariostjr/Documents/noctalia && git add files/Modules/Bar/Extras/BarDragOverlay.qml && git commit -m "feat: add BarDragOverlay ghost component for drag reorder"
```

---

## Task 3: BarWidgetLoader.qml — Visual offset and transform

**Files:**
- Create: `patches/06-BarWidgetLoader.qml.patch` (target: `Modules/Bar/Extras/BarWidgetLoader.qml`)

This patch is minimal — it only adds the `visualOffset` property, `Behavior`, and `transform: Translate` to BarWidgetLoader. No MouseArea, no drag logic. All drag detection happens in Bar.qml.

- [ ] **Step 1: Write the patch file**

Create `patches/06-BarWidgetLoader.qml.patch`:

```diff
--- a/Modules/Bar/Extras/BarWidgetLoader.qml
+++ b/Modules/Bar/Extras/BarWidgetLoader.qml
@@ -14,6 +14,14 @@
   readonly property string section: widgetProps ? (widgetProps.section || "") : ""
   readonly property int sectionIndex: widgetProps ? (widgetProps.sectionWidgetIndex || 0) : 0

+  // Drag reorder: visual displacement offset animated via Behavior
+  property real visualOffset: 0
+  // Controls whether offset changes animate (true) or snap instantly (false for cancel)
+  property bool animateOffset: true
+  Behavior on visualOffset {
+    enabled: animateOffset
+    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
+  }
+  // Apply offset via transform so it works inside RowLayout/ColumnLayout
+  transform: Translate { x: isVerticalBar ? 0 : visualOffset; y: isVerticalBar ? visualOffset : 0 }
+
   // Store registration key at registration time so unregistration always uses the correct key,
   // even if binding properties (section, sectionIndex) have changed by destruction time
   property string _regScreen: ""
```

- [ ] **Step 2: Verify patch applies cleanly**

```bash
cd ~/.config/quickshell/noctalia-shell && patch --dry-run -p1 < /home/mariostjr/Documents/noctalia/patches/06-BarWidgetLoader.qml.patch
```

- [ ] **Step 3: Commit**

```bash
cd /home/mariostjr/Documents/noctalia && git add patches/06-BarWidgetLoader.qml.patch && git commit -m "feat: add visualOffset and transform to BarWidgetLoader for drag reorder"
```

---

## Task 4: Bar.qml — Drag coordination (part 1: state + functions)

This is the largest change. Split into two sub-tasks for manageability.

**Files:**
- Modify (working copy): `~/.config/quickshell/noctalia-shell/Modules/Bar/Bar.qml`

- [ ] **Step 1: Add drag state properties after `id: root` (line 17)**

Add after line 17 (`id: root`), before the `property ShellScreen screen` line:

```qml
  // ── Drag reorder state ──
  property bool isDragging: false
  property string dragSection: ""
  property int dragFromIndex: -1
  property int dragCurrentIndex: -1
  property Item dragGhostSource: null
  property real dragCursorX: 0
  property real dragCursorY: 0
```

- [ ] **Step 2: Add drag functions after the state properties**

Add these functions right after the drag state properties:

```qml
  // Cancel drag — instant reset, no save
  function cancelDrag() {
    resetVisualOffsets(dragSection, false);
    isDragging = false;
    dragSection = "";
    dragFromIndex = -1;
    dragCurrentIndex = -1;
    if (dragGhostSource && dragGhostSource.hasOwnProperty("loader")) {
      // Restore widget opacity if the loader item exists
      var loaderItem = dragGhostSource.children[0]?.item;
      if (loaderItem) loaderItem.opacity = 1.0;
    }
    dragGhostSource = null;
  }

  // Finalize drag — move in model + persist
  function finalizeDrag() {
    var model = getModelForSection(dragSection);
    if (model && dragFromIndex >= 0 && dragCurrentIndex >= 0
        && dragFromIndex !== dragCurrentIndex
        && dragFromIndex < model.count && dragCurrentIndex < model.count) {
      model.move(dragFromIndex, dragCurrentIndex, 1);
      BarService.moveWidget(screen?.name || "", dragSection, dragFromIndex, dragCurrentIndex);
    }
    resetVisualOffsets(dragSection, true);
    isDragging = false;
    dragSection = "";
    dragFromIndex = -1;
    dragCurrentIndex = -1;
    dragGhostSource = null;
  }

  function getModelForSection(sectionName) {
    if (sectionName === "left") return leftWidgetsModel;
    if (sectionName === "center") return centerWidgetsModel;
    if (sectionName === "right") return rightWidgetsModel;
    return null;
  }

  // Reset visual offsets for all delegates in a section
  // animated=true for normal drop, animated=false for cancel (instant snap)
  function resetVisualOffsets(sectionName, animated) {
    var sectionObjName = sectionName === "left" ? "leftSection"
                       : sectionName === "center" ? "centerSection"
                       : "rightSection";
    var layout = barContentLoader.item?.children[0];
    if (!layout) return;
    // Find section by iterating children and checking objectName
    var sectionItem = null;
    for (var s = 0; s < layout.children.length; s++) {
      if (layout.children[s].objectName === sectionObjName) {
        sectionItem = layout.children[s];
        break;
      }
    }
    if (!sectionItem) return;
    for (var i = 0; i < sectionItem.children.length; i++) {
      var child = sectionItem.children[i];
      if (child && child.hasOwnProperty("visualOffset")) {
        child.animateOffset = animated;
        child.visualOffset = 0;
        if (!animated) {
          // Re-enable animation for future drags
          child.animateOffset = true;
        }
      }
    }
  }

  // Start drag for a specific widget delegate
  function startDrag(delegate, sectionName, widgetIndex) {
    if (isDragging) return;
    var model = getModelForSection(sectionName);
    if (!model || model.count <= 1) return;
    if (BarService.popupOpen) return;

    dragSection = sectionName;
    dragFromIndex = widgetIndex;
    dragCurrentIndex = widgetIndex;
    dragGhostSource = delegate;
    isDragging = true;
  }

  // Compute visual offsets during drag (works for both axes)
  function updateDragOffsets() {
    if (!isDragging || !dragGhostSource) return;

    var sectionObjName = dragSection === "left" ? "leftSection"
                       : dragSection === "center" ? "centerSection"
                       : "rightSection";
    var layout = barContentLoader.item?.children[0];
    if (!layout) return;

    var sectionItem = null;
    for (var s = 0; s < layout.children.length; s++) {
      if (layout.children[s].objectName === sectionObjName) {
        sectionItem = layout.children[s];
        break;
      }
    }
    if (!sectionItem) return;

    // Collect delegates that have visualOffset (BarWidgetLoader instances)
    var delegates = [];
    for (var i = 0; i < sectionItem.children.length; i++) {
      var child = sectionItem.children[i];
      if (child && child.hasOwnProperty("visualOffset") && child.hasOwnProperty("widgetId")) {
        delegates.push(child);
      }
    }
    if (delegates.length === 0) return;

    var isVert = barIsVertical;
    var localCursor = sectionItem.mapFromItem(null, dragCursorX, dragCursorY);
    var cursorPos = isVert ? localCursor.y : localCursor.x;

    // Determine new index based on cursor position relative to delegate midpoints
    var newIndex = dragFromIndex;
    for (var j = 0; j < delegates.length; j++) {
      if (delegates[j] === dragGhostSource) continue;
      var pos = isVert ? delegates[j].y : delegates[j].x;
      var size = isVert ? delegates[j].height : delegates[j].width;
      var mid = pos + size / 2;
      if (dragFromIndex < j && cursorPos > mid) {
        newIndex = j;
      } else if (dragFromIndex > j && cursorPos < mid) {
        newIndex = Math.min(newIndex, j);
      }
    }
    dragCurrentIndex = newIndex;

    // Apply visual offsets
    var draggedSize = (isVert ? dragGhostSource.height : dragGhostSource.width)
                    + Settings.data.bar.widgetSpacing;
    for (var k = 0; k < delegates.length; k++) {
      if (delegates[k] === dragGhostSource) {
        delegates[k].visualOffset = 0;
        continue;
      }
      if (dragFromIndex < dragCurrentIndex) {
        // Dragged forward: items between from+1..current shift backward
        if (k > dragFromIndex && k <= dragCurrentIndex) {
          delegates[k].visualOffset = -draggedSize;
        } else {
          delegates[k].visualOffset = 0;
        }
      } else if (dragFromIndex > dragCurrentIndex) {
        // Dragged backward: items between current..from-1 shift forward
        if (k >= dragCurrentIndex && k < dragFromIndex) {
          delegates[k].visualOffset = draggedSize;
        } else {
          delegates[k].visualOffset = 0;
        }
      } else {
        delegates[k].visualOffset = 0;
      }
    }
  }
```

- [ ] **Step 3: Verify file still parses**

Save the file and check for syntax errors:

```bash
cd ~/.config/quickshell/noctalia-shell && qmlformat --verify Modules/Bar/Bar.qml 2>&1 || echo "qmlformat not available, skip"
```

- [ ] **Step 4: Commit working state (local only)**

```bash
cd ~/.config/quickshell/noctalia-shell && git stash
```

(We'll unstash later. This is a checkpoint.)

---

## Task 5: Bar.qml — Drag coordination (part 2: overlay, tracker, delegates)

**Files:**
- Modify (working copy): `~/.config/quickshell/noctalia-shell/Modules/Bar/Bar.qml`

- [ ] **Step 1: Unstash and add BarDragOverlay + dragTracker MouseArea**

```bash
cd ~/.config/quickshell/noctalia-shell && git stash pop
```

Inside the `sourceComponent: Item` block (after `anchors.fill: parent`, before `Item { id: bar`), add:

```qml
      // Drag ghost overlay
      BarDragOverlay {
        id: dragOverlay
        anchors.fill: parent
        active: root.isDragging
        sourceItem: root.dragGhostSource
        isVertical: root.barIsVertical
        cursorX: root.dragCursorX
        cursorY: root.dragCursorY
      }

      // Prevent auto-hide during drag
      Binding {
        target: BarService
        property: "popupOpen"
        value: true
        when: root.isDragging
        restoreMode: Binding.RestoreBindingOrValue
      }

      // Drag tracking MouseArea — covers entire bar
      // Only long-press activates drag; normal clicks pass through
      MouseArea {
        id: dragTracker
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        propagateComposedEvents: true
        pressAndHoldInterval: 300
        hoverEnabled: false
        z: -1  // Below widget MouseAreas so normal clicks go to widgets

        property Item pressedDelegate: null
        property string pressedSection: ""
        property int pressedIndex: -1

        onPressed: function(mouse) {
          // Find which BarWidgetLoader delegate is under the cursor
          var result = findDelegateAt(mouse.x, mouse.y);
          if (result) {
            pressedDelegate = result.delegate;
            pressedSection = result.section;
            pressedIndex = result.index;
          } else {
            pressedDelegate = null;
            mouse.accepted = false;
          }
        }

        onPressAndHold: function(mouse) {
          if (!pressedDelegate) return;
          if (pressedDelegate.widgetId === "Taskbar") { pressedDelegate = null; return; }
          // Start drag
          var globalPos = mapToItem(null, mouse.x, mouse.y);
          root.dragCursorX = globalPos.x;
          root.dragCursorY = globalPos.y;
          // Capture ghost BEFORE setting opacity
          root.startDrag(pressedDelegate, pressedSection, pressedIndex);
          // Now dim the original widget (after ShaderEffectSource captured)
          Qt.callLater(function() {
            if (pressedDelegate && pressedDelegate.children[0] && pressedDelegate.children[0].item) {
              pressedDelegate.children[0].item.opacity = 0.3;
            }
          });
        }

        onPositionChanged: function(mouse) {
          if (!root.isDragging) return;
          var globalPos = mapToItem(null, mouse.x, mouse.y);
          root.dragCursorX = globalPos.x;
          root.dragCursorY = globalPos.y;
          root.updateDragOffsets();

          // Cancel if cursor leaves bar area
          if (mouse.x < 0 || mouse.y < 0
              || mouse.x > width || mouse.y > height) {
            root.cancelDrag();
            pressedDelegate = null;
          }
        }

        onReleased: function(mouse) {
          if (root.isDragging) {
            // Restore widget opacity
            if (pressedDelegate && pressedDelegate.children[0] && pressedDelegate.children[0].item) {
              pressedDelegate.children[0].item.opacity = 1.0;
            }
            root.finalizeDrag();
          }
          pressedDelegate = null;
          mouse.accepted = false;
        }

        onCanceled: {
          if (root.isDragging) {
            if (pressedDelegate && pressedDelegate.children[0] && pressedDelegate.children[0].item) {
              pressedDelegate.children[0].item.opacity = 1.0;
            }
            root.cancelDrag();
          }
          pressedDelegate = null;
        }

        // Find the BarWidgetLoader delegate under a point
        function findDelegateAt(mx, my) {
          var sections = ["left", "center", "right"];
          var sectionNames = ["leftSection", "centerSection", "rightSection"];
          var layout = barContentLoader.item?.children[0];
          if (!layout) return null;

          for (var s = 0; s < sectionNames.length; s++) {
            var sectionItem = null;
            for (var c = 0; c < layout.children.length; c++) {
              if (layout.children[c].objectName === sectionNames[s]) {
                sectionItem = layout.children[c];
                break;
              }
            }
            if (!sectionItem) continue;

            var idx = 0;
            for (var i = 0; i < sectionItem.children.length; i++) {
              var child = sectionItem.children[i];
              if (!child || !child.hasOwnProperty("widgetId")) continue;
              if (!child.visible) { idx++; continue; }

              var localPos = child.mapFromItem(dragTracker, mx, my);
              if (localPos.x >= 0 && localPos.x <= child.width
                  && localPos.y >= 0 && localPos.y <= child.height) {
                return { delegate: child, section: sections[s], index: idx };
              }
              idx++;
            }
          }
          return null;
        }
      }

      // Escape key handler during drag
      Item {
        focus: root.isDragging
        Keys.enabled: root.isDragging
        Keys.onEscapePressed: {
          if (dragTracker.pressedDelegate && dragTracker.pressedDelegate.children[0]
              && dragTracker.pressedDelegate.children[0].item) {
            dragTracker.pressedDelegate.children[0].item.opacity = 1.0;
          }
          root.cancelDrag();
          dragTracker.pressedDelegate = null;
        }
      }
```

- [ ] **Step 2: Add objectName to vertical section ColumnLayouts**

The horizontal sections already have `objectName`. Add to the vertical ones:

- Top section ColumnLayout (line ~508): add `objectName: "leftSection"`
- Center section ColumnLayout (line ~534): add `objectName: "centerSection"`
- Bottom section ColumnLayout (line ~559): add `objectName: "rightSection"`

- [ ] **Step 3: Copy BarDragOverlay to the shell for testing**

```bash
cp /home/mariostjr/Documents/noctalia/files/Modules/Bar/Extras/BarDragOverlay.qml ~/.config/quickshell/noctalia-shell/Modules/Bar/Extras/
```

- [ ] **Step 4: Apply BarWidgetLoader patch for testing**

```bash
cd ~/.config/quickshell/noctalia-shell && patch -p1 < /home/mariostjr/Documents/noctalia/patches/06-BarWidgetLoader.qml.patch
```

- [ ] **Step 5: Apply BarService patch for testing**

```bash
cd ~/.config/quickshell/noctalia-shell && patch -p1 < /home/mariostjr/Documents/noctalia/patches/08-BarService.qml.patch
```

- [ ] **Step 6: Manual test**

```bash
quickshell -c noctalia-shell
```

Test checklist:
- [ ] Long-press widget in left section → ghost appears, widget dims to 0.3 opacity
- [ ] Drag over adjacent widgets → they shift smoothly with 150ms animation
- [ ] Release → widgets reorder, check `~/.config/noctalia/settings.json` for updated order
- [ ] Restart shell → order persists
- [ ] Press Escape during drag → cancels, no reorder
- [ ] Drag cursor outside bar → cancels
- [ ] Normal click on widget → still opens panel (not intercepted)
- [ ] Taskbar widget → long-press does NOT activate drag
- [ ] Single widget in section → long-press does not activate drag
- [ ] Spacer widget → can be dragged
- [ ] Vertical bar → same behavior using Y axis

- [ ] **Step 7: Generate the Bar.qml patch**

```bash
cd ~/.config/quickshell/noctalia-shell && git diff -- Modules/Bar/Bar.qml > /home/mariostjr/Documents/noctalia/patches/07-Bar.qml.patch
```

- [ ] **Step 8: Revert working copy to clean state**

```bash
cd ~/.config/quickshell/noctalia-shell && git checkout -- Modules/Bar/Bar.qml Modules/Bar/Extras/BarWidgetLoader.qml Services/UI/BarService.qml && rm -f Modules/Bar/Extras/BarDragOverlay.qml
```

- [ ] **Step 9: Verify the generated patch applies cleanly**

```bash
cd ~/.config/quickshell/noctalia-shell && patch --dry-run -p1 < /home/mariostjr/Documents/noctalia/patches/07-Bar.qml.patch
```

- [ ] **Step 10: Commit**

```bash
cd /home/mariostjr/Documents/noctalia && git add patches/07-Bar.qml.patch && git commit -m "feat: add drag coordination and visual offsets to Bar.qml"
```

---

## Task 6: Integration test and README update

**Files:**
- Modify: `/home/mariostjr/Documents/noctalia/README.md`

- [ ] **Step 1: Apply everything to a fresh copy and test**

```bash
cp -r ~/.config/quickshell/noctalia-shell /tmp/noctalia-test
cd /tmp/noctalia-test
cp /home/mariostjr/Documents/noctalia/files/Modules/Bar/Extras/BarDragOverlay.qml Modules/Bar/Extras/
for patch in /home/mariostjr/Documents/noctalia/patches/06-BarWidgetLoader.qml.patch \
             /home/mariostjr/Documents/noctalia/patches/07-Bar.qml.patch \
             /home/mariostjr/Documents/noctalia/patches/08-BarService.qml.patch; do
  patch -p1 < "$patch"
done
```

Expected: all 3 patches apply cleanly.

- [ ] **Step 2: Update README.md**

Add widget drag reorder section to the README, listing the new file and 3 new patches.

- [ ] **Step 3: Commit**

```bash
cd /home/mariostjr/Documents/noctalia && git add README.md && git commit -m "docs: add widget drag reorder feature to README"
```

- [ ] **Step 4: Clean up**

```bash
rm -rf /tmp/noctalia-test
```
