#!/bin/bash
set -e

REPO="$(cd "$(dirname "$0")" && pwd)"
SHELL_DIR="$HOME/.config/quickshell/noctalia-shell"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
skip() { echo -e "  ${YELLOW}→${NC} $1 (já existe)"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

echo "=== Instalando noctalia-display-scale (Fedora) ==="
echo ""

if [ ! -d "$SHELL_DIR" ]; then
  echo -e "${RED}Erro: noctalia-shell não encontrado em $SHELL_DIR${NC}"
  exit 1
fi

# ── 1. Copiar novos arquivos QML ──────────────────────────────────────────
echo ">> Copiando arquivos QML..."

for file in ScaleSubTab.qml FocusRingSubTab.qml GapsSubTab.qml; do
  dest="$SHELL_DIR/Modules/Panels/Settings/Tabs/Display/$file"
  if [ -f "$dest" ]; then
    skip "$file"
  else
    cp "$REPO/display-scale/files/Modules/Panels/Settings/Tabs/Display/$file" "$dest"
    ok "$file"
  fi
done

# ── 2. DisplayTab.qml — adicionar subtabs ────────────────────────────────
echo ""
echo ">> Patching DisplayTab.qml..."

TARGET="$SHELL_DIR/Modules/Panels/Settings/Tabs/Display/DisplayTab.qml"

if grep -q 'ScaleSubTab {}' "$TARGET" 2>/dev/null; then
  skip "SubTabs no NTabView"
else
  export SHELL_DIR
  python3 << 'PYEOF'
import os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Modules/Panels/Settings/Tabs/Display/DisplayTab.qml")

with open(target) as f:
    content = f.read()

old = """    NightLightSubTab {
      timeOptions: timeOptions
      onCheckWlsunset: wlsunsetCheck.running = true
    }
  }
}"""
new = """    NightLightSubTab {
      timeOptions: timeOptions
      onCheckWlsunset: wlsunsetCheck.running = true
    }
    ScaleSubTab {}
    FocusRingSubTab {}
    GapsSubTab {}
  }
}"""

if old in content:
    content = content.replace(old, new)
    with open(target, "w") as f:
        f.write(content)
    print("OK")
else:
    print("FAIL")
    exit(1)
PYEOF
  if [ $? -eq 0 ]; then
    ok "SubTabs adicionados ao NTabView"
  else
    fail "SubTabs no NTabView — edite manualmente"
  fi
fi

# ── 2b. DisplayTab.qml — adicionar NTabButtons ──────────────────────────
if grep -q 'panels.display.scale-tab' "$TARGET" 2>/dev/null; then
  skip "NTabButtons (Scale, Focus Ring, Gaps)"
else
  export SHELL_DIR
  python3 << 'PYEOF'
import os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Modules/Panels/Settings/Tabs/Display/DisplayTab.qml")

with open(target) as f:
    content = f.read()

old = '''    NTabButton {
      text: I18n.tr("common.night-light")
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
  }'''

new = '''    NTabButton {
      text: I18n.tr("common.night-light")
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
    NTabButton {
      text: I18n.tr("panels.display.scale-tab")
      tabIndex: 2
      checked: subTabBar.currentIndex === 2
    }
    NTabButton {
      text: I18n.tr("panels.display.focus-ring-tab")
      tabIndex: 3
      checked: subTabBar.currentIndex === 3
    }
    NTabButton {
      text: I18n.tr("panels.display.gaps-tab")
      tabIndex: 4
      checked: subTabBar.currentIndex === 4
    }
  }'''

if old in content:
    content = content.replace(old, new)
    with open(target, "w") as f:
        f.write(content)
    print("OK")
else:
    print("FAIL - NTabButtons not found (may already be patched)")
    exit(1)
PYEOF
  if [ $? -eq 0 ]; then
    ok "NTabButtons (Scale, Focus Ring, Gaps) adicionados"
  else
    fail "NTabButtons — edite manualmente"
  fi
fi

# ── 3. CompositorService.qml ─────────────────────────────────────────────
echo ""
echo ">> Patching CompositorService.qml..."

TARGET="$SHELL_DIR/Services/Compositor/CompositorService.qml"

if grep -q "applySavedLayoutSettings" "$TARGET" 2>/dev/null; then
  skip "applySavedLayoutSettings()"
else
  python3 << 'PYEOF'
import os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Services/Compositor/CompositorService.qml")

with open(target) as f:
    content = f.read()

# 3a. Substituir backendLoader.onLoaded para verificar Settings.isLoaded
# e adicionar Connections para resolver race condition
old_loader = """    onLoaded: {
      if (item) {
        if (isScroll) {
          item.msgCommand = "scrollmsg";
        }
        root.backend = item;
        setupBackendConnections();
        backend.initialize();
      }
    }
  }"""
new_loader = """    onLoaded: {
      if (item) {
        if (isScroll) {
          item.msgCommand = "scrollmsg";
        }
        root.backend = item;
        setupBackendConnections();
        backend.initialize();
        // Apply settings now if already loaded, otherwise wait for signal
        if (Settings.isLoaded) {
          applySavedScales();
          applySavedLayoutSettings();
        }
      }
    }
  }

  Connections {
    target: Settings
    function onSettingsLoaded() {
      if (backend) {
        applySavedScales();
        applySavedLayoutSettings();
      }
    }
  }"""

if old_loader in content:
    content = content.replace(old_loader, new_loader)
else:
    # fallback: just add calls after initialize()
    content = content.replace(
        "        backend.initialize();\n",
        "        backend.initialize();\n        if (Settings.isLoaded) { applySavedScales(); applySavedLayoutSettings(); }\n"
    )

# 3b. Adicionar função antes de "// Hyprland backend component"
func = """
  // Apply saved layout settings (gaps, focus-ring) on startup
  function applySavedLayoutSettings() {
    try {
      var focusRingWidth = Settings.data.display.focusRingWidth ?? 2;
      var gaps = Settings.data.display.gaps ?? 8;
      if (backend && backend.applyLayoutSettings) {
        Logger.i("CompositorService", "Restoring layout: focus-ring=" + focusRingWidth + " gaps=" + gaps);
        backend.applyLayoutSettings(focusRingWidth, gaps);
      }
    } catch (error) {
      Logger.e("CompositorService", "Failed to apply saved layout settings:", error);
    }
  }

"""
content = content.replace(
    "  // Hyprland backend component",
    func + "  // Hyprland backend component"
)

with open(target, "w") as f:
    f.write(content)
PYEOF
  ok "applySavedLayoutSettings() + Connections adicionados"
fi

if grep -qF "function setFocusRingWidth" "$TARGET" 2>/dev/null; then
  skip "setFocusRingWidth(), setGaps(), setOutputScale(), applySavedScales()"
else
  python3 << 'PYEOF'
import os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Services/Compositor/CompositorService.qml")

with open(target) as f:
    content = f.read()

funcs = """
  function setFocusRingWidth(width) {
    if (backend && backend.setFocusRingWidth) {
      backend.setFocusRingWidth(width);
      Settings.data.display.focusRingWidth = width;
    }
  }

  function setGaps(gaps) {
    if (backend && backend.setGaps) {
      backend.setGaps(gaps);
      Settings.data.display.gaps = gaps;
    }
  }

  // Set display scale and persist as JSON string (property string serializes correctly)
  function setOutputScale(outputName, scale) {
    if (backend && backend.setOutputScale) {
      backend.setOutputScale(outputName, scale);
      var saved = {};
      try { saved = JSON.parse(Settings.data.display.outputScales || "{}"); } catch(e) {}
      saved[outputName] = scale;
      Settings.data.display.outputScales = JSON.stringify(saved);
    } else {
      Logger.w("CompositorService", "Backend does not support setting output scale");
    }
  }

  // Apply saved display scales on startup (reads JSON string)
  function applySavedScales() {
    try {
      var saved = {};
      try { saved = JSON.parse(Settings.data.display.outputScales || "{}"); } catch(e) { return; }
      const outputs = Object.keys(saved);
      if (outputs.length === 0) return;
      for (var i = 0; i < outputs.length; i++) {
        const outputName = outputs[i];
        const scale = saved[outputName];
        if (scale && backend && backend.setOutputScale) {
          Logger.i("CompositorService", "Restoring scale for " + outputName + ": " + scale);
          backend.setOutputScale(outputName, scale);
        }
      }
    } catch (error) {
      Logger.e("CompositorService", "Failed to apply saved scales:", error);
    }
  }

"""
content = content.replace(
    "  // Public function to get all display info",
    funcs + "  // Public function to get all display info"
)

with open(target, "w") as f:
    f.write(content)
PYEOF
  ok "setFocusRingWidth(), setGaps(), setOutputScale(), applySavedScales() adicionados"
fi

# ── 4. NiriService.qml ───────────────────────────────────────────────────
echo ""
echo ">> Patching NiriService.qml..."

TARGET="$SHELL_DIR/Services/Compositor/NiriService.qml"

if grep -qF "function setFocusRingWidth" "$TARGET" 2>/dev/null; then
  skip "funções focus-ring/gaps"
else
  python3 << 'PYEOF'
import os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Services/Compositor/NiriService.qml")

with open(target) as f:
    content = f.read()

funcs = r"""
  function setFocusRingWidth(width) {
    try {
      // Find which file has focus-ring, or add it to layout config
      var cmd = 'NIRI_DIR="$HOME/.config/niri"; '
        + 'FR_FILE=$(grep -rl "focus-ring" "$NIRI_DIR" --include="*.kdl" | head -1); '
        + 'if [ -z "$FR_FILE" ]; then '
        + '  LAYOUT_FILE=$(grep -rl "^\\s*layout" "$NIRI_DIR" --include="*.kdl" | head -1); '
        + '  [ -z "$LAYOUT_FILE" ] && LAYOUT_FILE="$NIRI_DIR/config.kdl"; '
        + '  sed -i "/^\\s*layout\\s*{/a\\    focus-ring {\\n        width ' + width + '\\n    }" "$LAYOUT_FILE"; '
        + 'else '
        + '  sed -i "/^\\s*focus-ring\\s*{/,/}/ s/\\(\\s*\\)width [0-9]\\+/\\1width ' + width + '/" "$FR_FILE"; '
        + 'fi; '
        + 'niri msg action load-config-file';
      Quickshell.execDetached(["sh", "-c", cmd]);
      Logger.i("NiriService", "Setting focus-ring width to " + width);
    } catch (e) {
      Logger.e("NiriService", "Failed to set focus-ring width:", e);
    }
  }

  function setGaps(gaps) {
    try {
      // Find which file has gaps inside layout block
      var cmd = 'NIRI_DIR="$HOME/.config/niri"; '
        + 'GAP_FILE=$(grep -rl "gaps" "$NIRI_DIR" --include="*.kdl" | head -1); '
        + '[ -z "$GAP_FILE" ] && GAP_FILE="$NIRI_DIR/config.kdl"; '
        + 'sed -i "s/^\\(\\s*\\)gaps [0-9]\\+/\\1gaps ' + gaps + '/" "$GAP_FILE"; '
        + 'niri msg action load-config-file';
      Quickshell.execDetached(["sh", "-c", cmd]);
      Logger.i("NiriService", "Setting gaps to " + gaps);
    } catch (e) {
      Logger.e("NiriService", "Failed to set gaps:", e);
    }
  }

  function applyLayoutSettings(focusRingWidth, gaps) {
    try {
      setGaps(gaps);
      setFocusRingWidth(focusRingWidth);
    } catch (e) {
      Logger.e("NiriService", "Failed to apply layout settings:", e);
    }
  }

"""
content = content.replace(
    "  function spawn(command)",
    funcs + "  function spawn(command)"
)

with open(target, "w") as f:
    f.write(content)
PYEOF
  ok "funções focus-ring/gaps adicionadas"
fi

# ── 5. Settings.qml ──────────────────────────────────────────────────────
echo ""
echo ">> Patching Settings.qml..."

TARGET="$SHELL_DIR/Commons/Settings.qml"

if grep -q "focusRingWidth" "$TARGET" 2>/dev/null; then
  skip "propriedades display"
else
  python3 << 'PYEOF'
import os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Commons/Settings.qml")

with open(target) as f:
    content = f.read()

# Use property string for outputScales so JsonAdapter persists it correctly
if "property var outputScales" in content:
    content = content.replace(
        "      property var outputScales: ({})\n    }",
        "      property string outputScales: \"{}\"\n      property int focusRingWidth: 2\n      property int gaps: 8\n    }"
    )
else:
    content = content.replace(
        "    property JsonObject colorSchemes:",
        "    property JsonObject display: JsonObject {\n      property string outputScales: \"{}\"\n      property int focusRingWidth: 2\n      property int gaps: 8\n    }\n\n    property JsonObject colorSchemes:"
    )

with open(target, "w") as f:
    f.write(content)
PYEOF
  ok "propriedades display adicionadas"
fi

# ── 6. settings-default.json ─────────────────────────────────────────────
echo ""
echo ">> Patching settings-default.json..."

TARGET="$SHELL_DIR/Assets/settings-default.json"

if grep -q '"focusRingWidth"' "$TARGET" 2>/dev/null; then
  skip "display section"
else
  python3 << 'PYEOF'
import json, os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Assets/settings-default.json")

with open(target) as f:
    data = json.load(f)

# outputScales stored as JSON string, not object
if "display" in data:
    data["display"]["outputScales"] = "{}"
    data["display"]["focusRingWidth"] = 2
    data["display"]["gaps"] = 8
else:
    new_data = {}
    for k, v in data.items():
        if k == "brightness":
            new_data["display"] = {"outputScales": "{}", "focusRingWidth": 2, "gaps": 8}
        new_data[k] = v
    if "display" not in new_data:
        new_data["display"] = {"outputScales": "{}", "focusRingWidth": 2, "gaps": 8}
    data = new_data

with open(target, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF
  ok "display section adicionada"
fi

# ── 7. Traduções en.json ─────────────────────────────────────────────────
echo ""
echo ">> Patching traduções..."

TARGET="$SHELL_DIR/Assets/Translations/en.json"

if grep -q '"scale-tab"' "$TARGET" 2>/dev/null; then
  skip "traduções scale (en.json)"
else
  python3 << 'PYEOF'
import os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Assets/Translations/en.json")

with open(target) as f:
    content = f.read()

anchor = '"monitors-title": "Per-monitor settings",'
insert = """      "monitors-title": "Per-monitor settings",
      "scale-tab": "Scale",
      "scale-title": "Display Scale",
      "scale-description": "Change the size of text, apps, and other items on each display.",
      "scale-label": "Scale",
      "scale-item-description": "Choose a percentage to resize everything on this display.",
      "scale-note": "The selected scale is saved and applied automatically on every startup.","""

content = content.replace(anchor, insert)

with open(target, "w") as f:
    f.write(content)
PYEOF
  ok "traduções scale (en.json)"
fi

if grep -q '"focus-ring-tab"' "$TARGET" 2>/dev/null; then
  skip "traduções focus-ring/gaps (en.json)"
else
  python3 << 'PYEOF'
import os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Assets/Translations/en.json")

with open(target) as f:
    content = f.read()

anchor = '"scale-note": "The selected scale is saved and applied automatically on every startup.",'
insert = """      "scale-note": "The selected scale is saved and applied automatically on every startup.",
      "focus-ring-tab": "Focus Ring",
      "focus-ring-title": "Focus Ring",
      "focus-ring-description": "Set the width of the focus indicator around the active window.",
      "focus-ring-label": "Width",
      "focus-ring-note": "The selected width is saved and applied automatically on every startup.",
      "gaps-tab": "Gaps",
      "gaps-title": "Window Gaps",
      "gaps-description": "Set the spacing between tiled windows.",
      "gaps-label": "Gap size",
      "gaps-note": "The selected gap size is saved and applied automatically on every startup.","""

content = content.replace(anchor, insert)

with open(target, "w") as f:
    f.write(content)
PYEOF
  ok "traduções focus-ring/gaps (en.json)"
fi

# ── 8. Traduções pt.json ─────────────────────────────────────────────────
TARGET="$SHELL_DIR/Assets/Translations/pt.json"

if grep -q '"scale-tab"' "$TARGET" 2>/dev/null; then
  skip "traduções scale (pt.json)"
else
  python3 << 'PYEOF'
import os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Assets/Translations/pt.json")

with open(target) as f:
    content = f.read()

anchor = '"monitors-title": "Configurações por monitor",'
insert = """      "monitors-title": "Configurações por monitor",
      "scale-tab": "Escala",
      "scale-title": "Escala da Tela",
      "scale-description": "Altere o tamanho do texto, dos aplicativos e de outros itens em cada tela.",
      "scale-label": "Escala",
      "scale-item-description": "Escolha uma porcentagem para redimensionar tudo nesta tela.",
      "scale-note": "A escala selecionada é salva e aplicada automaticamente a cada inicialização.","""

content = content.replace(anchor, insert)

with open(target, "w") as f:
    f.write(content)
PYEOF
  ok "traduções scale (pt.json)"
fi

if grep -q '"focus-ring-tab"' "$TARGET" 2>/dev/null; then
  skip "traduções focus-ring/gaps (pt.json)"
else
  python3 << 'PYEOF'
import os
SD = os.environ["SHELL_DIR"]
target = os.path.join(SD, "Assets/Translations/pt.json")

with open(target) as f:
    content = f.read()

anchor = 'scale-note": "A escala selecionada é salva e aplicada automaticamente a cada inicialização.",'
insert = """scale-note": "A escala selecionada é salva e aplicada automaticamente a cada inicialização.",
      "focus-ring-tab": "Anel de Foco",
      "focus-ring-title": "Anel de Foco",
      "focus-ring-description": "Defina a largura do indicador de foco ao redor da janela ativa.",
      "focus-ring-label": "Largura",
      "focus-ring-note": "A largura selecionada é salva e aplicada automaticamente a cada inicialização.",
      "gaps-tab": "Espaçamento",
      "gaps-title": "Espaçamento entre Janelas",
      "gaps-description": "Defina o espaçamento entre as janelas organizadas.",
      "gaps-label": "Tamanho do espaçamento",
      "gaps-note": "O espaçamento selecionado é salvo e aplicado automaticamente a cada inicialização.","""

content = content.replace(anchor, insert)

with open(target, "w") as f:
    f.write(content)
PYEOF
  ok "traduções focus-ring/gaps (pt.json)"
fi

# ── Limpeza ───────────────────────────────────────────────────────────────
echo ""
echo ">> Limpando rejects e backups..."
find "$SHELL_DIR" -name "*.rej" -delete 2>/dev/null || true
find "$SHELL_DIR" -name "*.orig" -delete 2>/dev/null || true
ok "Limpeza concluída"

# ── Fix niri functions (modular config) ──────────────────────────────────
echo ""
echo ">> Corrigindo funções Niri (config modular)..."
if [ -f "$REPO/fix-niri-functions-fedora.py" ]; then
  python3 "$REPO/fix-niri-functions-fedora.py" && ok "Funções Niri corrigidas" || skip "Funções Niri (já corrigidas ou não aplicável)"
fi

echo ""
echo -e "${GREEN}=== Instalação concluída! (Fedora) ===${NC}"
echo "Reiniciando quickshell..."

pkill -x quickshell 2>/dev/null || true
while pgrep -x quickshell >/dev/null 2>&1; do sleep 0.2; done
nohup quickshell -c noctalia-shell >/dev/null 2>&1 &
disown
ok "Quickshell reiniciado"
