# Layout Settings & Scale Limit Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add GUI settings for focus-ring width and window gaps to the Noctalia Shell Display tab, and cap display scale at 200%.

**Architecture:** New QML sub-tabs (FocusRingSubTab, GapsSubTab) delegate to CompositorService → NiriService, which edits `~/.config/niri/config.kdl` and reloads niri. Settings persist via `Settings.data.display.*`. ScaleSubTab gets a `maxScale` property that filters options.

**Tech Stack:** QML/Qt (Quickshell framework), sed for config editing, niri IPC for reload.

**Spec:** `docs/superpowers/specs/2026-03-17-layout-settings-design.md`

**No test suite exists** — this project is tested manually against a running Noctalia Shell. TDD steps are replaced with manual verification notes.

---

### Task 1: ScaleSubTab — Cap max scale at 200%

**Files:**
- Modify: `files/Modules/Panels/Settings/Tabs/Display/ScaleSubTab.qml`

- [ ] **Step 1: Add maxScale property and filter scaleOptions**

Replace the hardcoded `scaleOptions` array with a `maxScale` property + filtered list:

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

- [ ] **Step 2: Commit**

```bash
git add files/Modules/Panels/Settings/Tabs/Display/ScaleSubTab.qml
git commit -m "feat(scale): cap max display scale at 200% with configurable maxScale property"
```

---

### Task 2: Create FocusRingSubTab.qml

**Files:**
- Create: `files/Modules/Panels/Settings/Tabs/Display/FocusRingSubTab.qml`

- [ ] **Step 1: Create the file**

Follow the NSpinBox pattern from `AppearanceSubTab.qml` (lines 309-318):

```qml
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NLabel {
    label: I18n.tr("panels.display.focus-ring-title")
    description: I18n.tr("panels.display.focus-ring-description")
    Layout.fillWidth: true
  }

  NSpinBox {
    Layout.fillWidth: true
    label: I18n.tr("panels.display.focus-ring-label")
    from: 0
    to: 8
    suffix: "px"
    value: Settings.data.display.focusRingWidth
    defaultValue: 2
    onValueChanged: CompositorService.setFocusRingWidth(value)
  }

  NText {
    text: I18n.tr("panels.display.focus-ring-note")
    pointSize: Style.fontSizeXS
    color: Color.mOnSurfaceVariant
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add files/Modules/Panels/Settings/Tabs/Display/FocusRingSubTab.qml
git commit -m "feat(focus-ring): add FocusRingSubTab UI component"
```

---

### Task 3: Create GapsSubTab.qml

**Files:**
- Create: `files/Modules/Panels/Settings/Tabs/Display/GapsSubTab.qml`

- [ ] **Step 1: Create the file**

```qml
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NLabel {
    label: I18n.tr("panels.display.gaps-title")
    description: I18n.tr("panels.display.gaps-description")
    Layout.fillWidth: true
  }

  NSpinBox {
    Layout.fillWidth: true
    label: I18n.tr("panels.display.gaps-label")
    from: 0
    to: 32
    suffix: "px"
    value: Settings.data.display.gaps
    defaultValue: 8
    onValueChanged: CompositorService.setGaps(value)
  }

  NText {
    text: I18n.tr("panels.display.gaps-note")
    pointSize: Style.fontSizeXS
    color: Color.mOnSurfaceVariant
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add files/Modules/Panels/Settings/Tabs/Display/GapsSubTab.qml
git commit -m "feat(gaps): add GapsSubTab UI component"
```

---

### Task 4: Patch DisplayTab.qml — Add tab buttons and sub-tab instances

**Files:**
- Create: `patches/08-DisplayTab.qml.patch`

- [ ] **Step 1: Create the patch**

This patch adds to the already-patched DisplayTab (which has Brightness at 0, Night Light at 1, Scale at 2). Add Focus Ring at 3, Gaps at 4:

```diff
--- a/Modules/Panels/Settings/Tabs/Display/DisplayTab.qml
+++ b/Modules/Panels/Settings/Tabs/Display/DisplayTab.qml
@@ -76,6 +76,16 @@
       tabIndex: 2
       checked: subTabBar.currentIndex === 2
     }
+    NTabButton {
+      text: I18n.tr("panels.display.focus-ring-tab")
+      tabIndex: 3
+      checked: subTabBar.currentIndex === 3
+    }
+    NTabButton {
+      text: I18n.tr("panels.display.gaps-tab")
+      tabIndex: 4
+      checked: subTabBar.currentIndex === 4
+    }
   }

   Item {
@@ -93,5 +103,7 @@
       onCheckWlsunset: wlsunsetCheck.running = true
     }
     ScaleSubTab {}
+    FocusRingSubTab {}
+    GapsSubTab {}
   }
 }
```

- [ ] **Step 2: Commit**

```bash
git add patches/08-DisplayTab.qml.patch
git commit -m "feat(display): patch DisplayTab to add Focus Ring and Gaps tabs"
```

---

### Task 5: Patch CompositorService.qml — Add facade methods + startup restore

**Files:**
- Create: `patches/09-CompositorService.qml.patch`

- [ ] **Step 1: Create the patch**

Add `applySavedLayoutSettings()` call in `onLoaded` (after `applySavedScales()`), and add the new methods after `setOutputScale`. Uses `?? default` fallbacks to handle fresh installs where settings haven't been written yet:

```diff
--- a/Services/Compositor/CompositorService.qml
+++ b/Services/Compositor/CompositorService.qml
@@ -132,6 +132,7 @@
         backend.initialize();
         applySavedScales();
+        applySavedLayoutSettings();
       }
     }
   }
@@ -159,6 +160,33 @@
     }
   }

+  // Apply saved layout settings (gaps, focus-ring) on startup
+  function applySavedLayoutSettings() {
+    try {
+      var focusRingWidth = Settings.data.display.focusRingWidth ?? 2;
+      var gaps = Settings.data.display.gaps ?? 8;
+      if (backend && backend.applyLayoutSettings) {
+        Logger.i("CompositorService", "Restoring layout: focus-ring=" + focusRingWidth + " gaps=" + gaps);
+        backend.applyLayoutSettings(focusRingWidth, gaps);
+      }
+    } catch (error) {
+      Logger.e("CompositorService", "Failed to apply saved layout settings:", error);
+    }
+  }
+
@@ -340,6 +368,20 @@
   }

+  function setFocusRingWidth(width) {
+    if (backend && backend.setFocusRingWidth) {
+      backend.setFocusRingWidth(width);
+      Settings.data.display.focusRingWidth = width;
+    }
+  }
+
+  function setGaps(gaps) {
+    if (backend && backend.setGaps) {
+      backend.setGaps(gaps);
+      Settings.data.display.gaps = gaps;
+    }
+  }
+
   // Public function to get scale for a specific display
```

- [ ] **Step 2: Commit**

```bash
git add patches/09-CompositorService.qml.patch
git commit -m "feat(compositor): patch CompositorService with layout settings facade"
```

---

### Task 6: Patch NiriService.qml — Add config editing methods

**Files:**
- Create: `patches/10-NiriService.qml.patch`

- [ ] **Step 1: Create the patch**

Add methods after `setOutputScale` (line 534) in NiriService.qml. Uses `Quickshell.execDetached` with `sh -c` to run sed + reload atomically via `&&`:

```diff
--- a/Services/Compositor/NiriService.qml
+++ b/Services/Compositor/NiriService.qml
@@ -534,6 +534,34 @@
     }
   }

+  function setFocusRingWidth(width) {
+    try {
+      var cmd = "sed -i '/^\\s*focus-ring\\s*{/,/}/ s/^\\(\\s*\\)width [0-9]\\+/\\1width " + width + "/' ~/.config/niri/config.kdl && niri msg action load-config-file";
+      Quickshell.execDetached(["sh", "-c", cmd]);
+      Logger.i("NiriService", "Setting focus-ring width to " + width);
+    } catch (e) {
+      Logger.e("NiriService", "Failed to set focus-ring width:", e);
+    }
+  }
+
+  function setGaps(gaps) {
+    try {
+      var cmd = "sed -i 's/^\\s*gaps [0-9]\\+/    gaps " + gaps + "/' ~/.config/niri/config.kdl && niri msg action load-config-file";
+      Quickshell.execDetached(["sh", "-c", cmd]);
+      Logger.i("NiriService", "Setting gaps to " + gaps);
+    } catch (e) {
+      Logger.e("NiriService", "Failed to set gaps:", e);
+    }
+  }
+
+  function applyLayoutSettings(focusRingWidth, gaps) {
+    try {
+      var cmd = "sed -i -e 's/^\\s*gaps [0-9]\\+/    gaps " + gaps + "/' -e '/^\\s*focus-ring\\s*{/,/}/ s/^\\(\\s*\\)width [0-9]\\+/\\1width " + focusRingWidth + "/' ~/.config/niri/config.kdl && niri msg action load-config-file";
+      Quickshell.execDetached(["sh", "-c", cmd]);
+      Logger.i("NiriService", "Applied layout settings: focus-ring=" + focusRingWidth + " gaps=" + gaps);
+    } catch (e) {
+      Logger.e("NiriService", "Failed to apply layout settings:", e);
+    }
+  }
+
   function spawn(command) {
```

- [ ] **Step 2: Commit**

```bash
git add patches/10-NiriService.qml.patch
git commit -m "feat(niri): patch NiriService with focus-ring, gaps, and layout config methods"
```

---

### Task 7: Patch Settings.qml — Add focusRingWidth and gaps properties

**Files:**
- Create: `patches/11-Settings.qml.patch`

- [ ] **Step 1: Create the patch**

Extend the existing `display` JsonObject (added by patch 06) with two new properties:

```diff
--- a/Commons/Settings.qml
+++ b/Commons/Settings.qml
@@ -704,6 +704,8 @@
     property JsonObject display: JsonObject {
       property var outputScales: ({})
+      property int focusRingWidth: 2
+      property int gaps: 8
     }
```

- [ ] **Step 2: Commit**

```bash
git add patches/11-Settings.qml.patch
git commit -m "feat(settings): patch Settings.qml with focusRingWidth and gaps properties"
```

---

### Task 8: Patch settings-default.json — Add defaults

**Files:**
- Create: `patches/12-settings-default.json.patch`

- [ ] **Step 1: Create the patch**

Extend the `display` object (added by patch 07):

```diff
--- a/Assets/settings-default.json
+++ b/Assets/settings-default.json
@@ -485,6 +485,8 @@
   "display": {
-    "outputScales": {}
+    "outputScales": {},
+    "focusRingWidth": 2,
+    "gaps": 8
   },
```

- [ ] **Step 2: Commit**

```bash
git add patches/12-settings-default.json.patch
git commit -m "feat(settings): patch defaults with focusRingWidth and gaps"
```

---

### Task 9: Patch en.json — English translations

**Files:**
- Create: `patches/13-en.json.patch`

- [ ] **Step 1: Create the patch**

Add after the existing scale translation keys (added by patch 04):

```diff
--- a/Assets/Translations/en.json
+++ b/Assets/Translations/en.json
@@ -1085,6 +1085,16 @@
       "scale-note": "The selected scale is saved and applied automatically on every startup.",
+      "focus-ring-tab": "Focus Ring",
+      "focus-ring-title": "Focus Ring",
+      "focus-ring-description": "Set the width of the focus indicator around the active window.",
+      "focus-ring-label": "Width",
+      "focus-ring-note": "The selected width is saved and applied automatically on every startup.",
+      "gaps-tab": "Gaps",
+      "gaps-title": "Window Gaps",
+      "gaps-description": "Set the spacing between tiled windows.",
+      "gaps-label": "Gap size",
+      "gaps-note": "The selected gap size is saved and applied automatically on every startup.",
       "night-light-auto-schedule-description": "Based on the sunset and sunrise time in <i>{location}</i> — recommended.",
```

- [ ] **Step 2: Commit**

```bash
git add patches/13-en.json.patch
git commit -m "feat(i18n): add English translations for focus-ring and gaps settings"
```

---

### Task 10: Patch pt.json — Portuguese translations

**Files:**
- Create: `patches/14-pt.json.patch`

- [ ] **Step 1: Create the patch**

Add after the existing scale translation keys (added by patch 05):

```diff
--- a/Assets/Translations/pt.json
+++ b/Assets/Translations/pt.json
@@ -1085,6 +1085,16 @@
       "scale-note": "A escala selecionada é salva e aplicada automaticamente a cada inicialização.",
+      "focus-ring-tab": "Anel de Foco",
+      "focus-ring-title": "Anel de Foco",
+      "focus-ring-description": "Defina a largura do indicador de foco ao redor da janela ativa.",
+      "focus-ring-label": "Largura",
+      "focus-ring-note": "A largura selecionada é salva e aplicada automaticamente a cada inicialização.",
+      "gaps-tab": "Espaçamento",
+      "gaps-title": "Espaçamento entre Janelas",
+      "gaps-description": "Defina o espaçamento entre as janelas organizadas.",
+      "gaps-label": "Tamanho do espaçamento",
+      "gaps-note": "O espaçamento selecionado é salvo e aplicado automaticamente a cada inicialização.",
       "night-light-auto-schedule-description": "Baseado no horário do pôr do sol e do nascer do sol em <i>{location}</i> — recomendado.",
```

- [ ] **Step 2: Commit**

```bash
git add patches/14-pt.json.patch
git commit -m "feat(i18n): add Portuguese translations for focus-ring and gaps settings"
```
