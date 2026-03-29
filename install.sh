#!/bin/bash
set -e

REPO="$(cd "$(dirname "$0")" && pwd)"
SHELL_DIR="/etc/xdg/quickshell/noctalia-shell"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
skip() { echo -e "  ${YELLOW}→${NC} $1 (já existe)"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

# Helper: insere texto DEPOIS de uma linha que contém o padrão (primeira ocorrência)
# Uso: insert_after <arquivo> <padrão-grep> <texto-a-inserir>
insert_after() {
  local file="$1" pattern="$2" text="$3"
  sudo python3 -c "
import sys
lines = open('$file').readlines()
out = []
done = False
for line in lines:
    out.append(line)
    if not done and '$pattern' in line:
        out.append('$text\n')
        done = True
if not done:
    sys.exit(1)
open('$file', 'w').writelines(out)
" 2>/dev/null
}

# Helper: insere texto ANTES de uma linha que contém o padrão (primeira ocorrência)
insert_before() {
  local file="$1" pattern="$2" text="$3"
  sudo python3 -c "
import sys
lines = open('$file').readlines()
out = []
done = False
for line in lines:
    if not done and '$pattern' in line:
        out.append('$text\n')
        done = True
    out.append(line)
if not done:
    sys.exit(1)
open('$file', 'w').writelines(out)
" 2>/dev/null
}

echo "=== Instalando noctalia-display-scale ==="
echo ""

# ── 1. Copiar novos arquivos QML ──────────────────────────────────────────
echo ">> Copiando arquivos QML..."

for file in ScaleSubTab.qml FocusRingSubTab.qml GapsSubTab.qml; do
  dest="$SHELL_DIR/Modules/Panels/Settings/Tabs/Display/$file"
  if [ -f "$dest" ]; then
    skip "$file"
  else
    sudo cp "$REPO/display-scale/files/Modules/Panels/Settings/Tabs/Display/$file" "$dest"
    ok "$file"
  fi
done

dest="$SHELL_DIR/Modules/Bar/Extras/BarDragOverlay.qml"
if [ -f "$dest" ]; then
  skip "BarDragOverlay.qml"
else
  sudo mkdir -p "$SHELL_DIR/Modules/Bar/Extras/"
  sudo cp "$REPO/files/Modules/Bar/Extras/BarDragOverlay.qml" "$dest"
  ok "BarDragOverlay.qml"
fi

# ── 2. DisplayTab.qml — adicionar subtabs ────────────────────────────────
echo ""
echo ">> Patching DisplayTab.qml..."

TARGET="$SHELL_DIR/Modules/Panels/Settings/Tabs/Display/DisplayTab.qml"

if grep -q 'ScaleSubTab {}' "$TARGET" 2>/dev/null; then
  skip "SubTabs no NTabView"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Display/DisplayTab.qml") as f:
    content = f.read()

# Inserir os 3 subtabs depois do fechamento do NightLightSubTab no NTabView
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
    with open("/etc/xdg/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Display/DisplayTab.qml", "w") as f:
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
if grep -q 'display.scale-tab' "$TARGET" 2>/dev/null; then
  skip "NTabButtons (Scale, Focus Ring, Gaps)"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Display/DisplayTab.qml") as f:
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
    with open("/etc/xdg/quickshell/noctalia-shell/Modules/Panels/Settings/Tabs/Display/DisplayTab.qml", "w") as f:
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

if grep -q "applySavedScales" "$TARGET" 2>/dev/null; then
  skip "applySavedScales()"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/CompositorService.qml") as f:
    content = f.read()

# 3a0. Adicionar call applySavedScales() com check Settings.isLoaded
content = content.replace(
    "        backend.initialize();\n",
    "        backend.initialize();\n        if (Settings.isLoaded) { applySavedScales(); }\n"
)

# 3a0a. Adicionar Connections para resolver race condition
connections_block = """
  Connections {
    target: Settings
    function onSettingsLoaded() {
      if (backend) {
        applySavedScales();
      }
    }
  }
"""
content = content.replace(
    "  // Load display scales from ShellState",
    connections_block + "\n  // Load display scales from ShellState"
)

# 3a0b. Adicionar função applySavedScales (lê JSON string)
func_scales = """
  // Apply saved display scales on startup (reads JSON string)
  function applySavedScales() {
    try {
      var saved = {};
      try { saved = JSON.parse(Settings.data.display.outputScales || "{}"); } catch(e) { return; }

      const outputs = Object.keys(saved);
      if (outputs.length === 0)
        return;

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
    "  // Hyprland backend component",
    func_scales + "  // Hyprland backend component"
)

with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/CompositorService.qml", "w") as f:
    f.write(content)
PYEOF
  ok "applySavedScales() adicionado"
fi

if grep -q "applySavedLayoutSettings" "$TARGET" 2>/dev/null; then
  skip "applySavedLayoutSettings()"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/CompositorService.qml") as f:
    content = f.read()

# 3a. Adicionar call applySavedLayoutSettings() junto com applySavedScales()
content = content.replace(
    "        if (Settings.isLoaded) { applySavedScales(); }\n",
    "        if (Settings.isLoaded) { applySavedScales(); applySavedLayoutSettings(); }\n"
)

# 3a1. Atualizar Connections para incluir applySavedLayoutSettings
content = content.replace(
    "        applySavedScales();\n      }\n    }\n  }\n",
    "        applySavedScales();\n        applySavedLayoutSettings();\n      }\n    }\n  }\n"
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

with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/CompositorService.qml", "w") as f:
    f.write(content)
PYEOF
  ok "applySavedLayoutSettings() adicionado"
fi

if grep -qF "function setOutputScale" "$TARGET" 2>/dev/null; then
  skip "setOutputScale()"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/CompositorService.qml") as f:
    content = f.read()

func = """
  // Set display scale for a specific output and persist to settings
  function setOutputScale(outputName, scale) {
    if (backend && backend.setOutputScale) {
      backend.setOutputScale(outputName, scale);

      // Persist to settings as JSON string
      var saved = {};
      try { saved = JSON.parse(Settings.data.display.outputScales || "{}"); } catch(e) {}
      saved[outputName] = scale;
      Settings.data.display.outputScales = JSON.stringify(saved);
    } else {
      Logger.w("CompositorService", "Backend does not support setting output scale");
    }
  }

"""
content = content.replace(
    "  // Public function to get all display info",
    func + "  // Public function to get all display info"
)

with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/CompositorService.qml", "w") as f:
    f.write(content)
PYEOF
  ok "setOutputScale() adicionado"
fi

if grep -qF "function setFocusRingWidth" "$TARGET" 2>/dev/null; then
  skip "setFocusRingWidth() e setGaps()"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/CompositorService.qml") as f:
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

"""
content = content.replace(
    "  // Public function to get all display info",
    funcs + "  // Public function to get all display info"
)

with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/CompositorService.qml", "w") as f:
    f.write(content)
PYEOF
  ok "setFocusRingWidth() e setGaps() adicionados"
fi

# ── 4. NiriService.qml ───────────────────────────────────────────────────
echo ""
echo ">> Patching NiriService.qml..."

TARGET="$SHELL_DIR/Services/Compositor/NiriService.qml"

if grep -qF "function setOutputScale" "$TARGET" 2>/dev/null; then
  skip "setOutputScale() no NiriService"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/NiriService.qml") as f:
    content = f.read()

func = """
  function setOutputScale(outputName, scale) {
    try {
      Quickshell.execDetached(["niri", "msg", "output", outputName, "scale", scale.toString()]);
      Logger.i("NiriService", "Setting scale for " + outputName + " to " + scale);
    } catch (e) {
      Logger.e("NiriService", "Failed to set output scale:", e);
    }
  }

"""
content = content.replace(
    "  function spawn(command)",
    func + "  function spawn(command)"
)

with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/NiriService.qml", "w") as f:
    f.write(content)
PYEOF
  ok "setOutputScale() adicionado ao NiriService"
fi

if grep -qF "function setFocusRingWidth" "$TARGET" 2>/dev/null; then
  skip "funções focus-ring/gaps"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/NiriService.qml") as f:
    content = f.read()

funcs = r"""
  function setFocusRingWidth(width) {
    try {
      var cmd = "sed -i '/^\\s*focus-ring\\s*{/,/}/ s/^\\(\\s*\\)width [0-9]\\+/\\1width " + width + "/' ~/.config/niri/config.kdl && niri msg action load-config-file";
      Quickshell.execDetached(["sh", "-c", cmd]);
      Logger.i("NiriService", "Setting focus-ring width to " + width);
    } catch (e) {
      Logger.e("NiriService", "Failed to set focus-ring width:", e);
    }
  }

  function setGaps(gaps) {
    try {
      var cmd = "sed -i 's/^\\s*gaps [0-9]\\+/    gaps " + gaps + "/' ~/.config/niri/config.kdl && niri msg action load-config-file";
      Quickshell.execDetached(["sh", "-c", cmd]);
      Logger.i("NiriService", "Setting gaps to " + gaps);
    } catch (e) {
      Logger.e("NiriService", "Failed to set gaps:", e);
    }
  }

  function applyLayoutSettings(focusRingWidth, gaps) {
    try {
      var cmd = "sed -i -e 's/^\\s*gaps [0-9]\\+/    gaps " + gaps + "/' -e '/^\\s*focus-ring\\s*{/,/}/ s/^\\(\\s*\\)width [0-9]\\+/\\1width " + focusRingWidth + "/' ~/.config/niri/config.kdl && niri msg action load-config-file";
      Quickshell.execDetached(["sh", "-c", cmd]);
      Logger.i("NiriService", "Applied layout settings: focus-ring=" + focusRingWidth + " gaps=" + gaps);
    } catch (e) {
      Logger.e("NiriService", "Failed to apply layout settings:", e);
    }
  }

"""
content = content.replace(
    "  function spawn(command)",
    funcs + "  function spawn(command)"
)

with open("/etc/xdg/quickshell/noctalia-shell/Services/Compositor/NiriService.qml", "w") as f:
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
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Commons/Settings.qml") as f:
    content = f.read()

if "property var outputScales" in content:
    content = content.replace(
        "      property string outputScales: "{}"\n    }",
        "      property string outputScales: "{}"\n      property int focusRingWidth: 2\n      property int gaps: 8\n    }"
    )
else:
    content = content.replace(
        "    property JsonObject colorSchemes:",
        "    property JsonObject display: JsonObject {\n      property string outputScales: "{}"\n      property int focusRingWidth: 2\n      property int gaps: 8\n    }\n\n    property JsonObject colorSchemes:"
    )

with open("/etc/xdg/quickshell/noctalia-shell/Commons/Settings.qml", "w") as f:
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
  sudo python3 << 'PYEOF'
import json

with open("/etc/xdg/quickshell/noctalia-shell/Assets/settings-default.json") as f:
    data = json.load(f)

if "display" in data:
    data["display"]["focusRingWidth"] = 2
    data["display"]["gaps"] = 8
else:
    # Inserir display section
    new_data = {}
    for k, v in data.items():
        if k == "brightness":
            new_data["display"] = {"outputScales": {}, "focusRingWidth": 2, "gaps": 8}
        new_data[k] = v
    if "display" not in new_data:
        new_data["display"] = {"outputScales": {}, "focusRingWidth": 2, "gaps": 8}
    data = new_data

with open("/etc/xdg/quickshell/noctalia-shell/Assets/settings-default.json", "w") as f:
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
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Assets/Translations/en.json") as f:
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

with open("/etc/xdg/quickshell/noctalia-shell/Assets/Translations/en.json", "w") as f:
    f.write(content)
PYEOF
  ok "traduções scale (en.json)"
fi

if grep -q '"focus-ring-tab"' "$TARGET" 2>/dev/null; then
  skip "traduções focus-ring/gaps (en.json)"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Assets/Translations/en.json") as f:
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

with open("/etc/xdg/quickshell/noctalia-shell/Assets/Translations/en.json", "w") as f:
    f.write(content)
PYEOF
  ok "traduções focus-ring/gaps (en.json)"
fi

# ── 8. Traduções pt.json ─────────────────────────────────────────────────
TARGET="$SHELL_DIR/Assets/Translations/pt.json"

if grep -q '"scale-tab"' "$TARGET" 2>/dev/null; then
  skip "traduções scale (pt.json)"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Assets/Translations/pt.json") as f:
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

with open("/etc/xdg/quickshell/noctalia-shell/Assets/Translations/pt.json", "w") as f:
    f.write(content)
PYEOF
  ok "traduções scale (pt.json)"
fi

if grep -q '"focus-ring-tab"' "$TARGET" 2>/dev/null; then
  skip "traduções focus-ring/gaps (pt.json)"
else
  sudo python3 << 'PYEOF'
with open("/etc/xdg/quickshell/noctalia-shell/Assets/Translations/pt.json") as f:
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

with open("/etc/xdg/quickshell/noctalia-shell/Assets/Translations/pt.json", "w") as f:
    f.write(content)
PYEOF
  ok "traduções focus-ring/gaps (pt.json)"
fi

# ── 9. Bar Widget Drag ───────────────────────────────────────────────────
echo ""
echo ">> Patching Bar Widget Drag..."

TARGET="$SHELL_DIR/Modules/Bar/Extras/BarWidgetLoader.qml"
if grep -qE "DragHandler|dragActive|BarDragOverlay" "$TARGET" 2>/dev/null; then
  skip "Bar Widget Drag (já patcheado)"
else
  cd "$SHELL_DIR"
  for patch in "$REPO/patches/"*.patch; do
    name=$(basename "$patch")
    if sudo patch -p1 --forward < "$patch" 2>/dev/null; then
      ok "$name"
    else
      skip "$name"
    fi
  done
fi

# ── Limpeza ───────────────────────────────────────────────────────────────
echo ""
echo ">> Limpando rejects e backups..."
sudo find "$SHELL_DIR" -name "*.rej" -delete 2>/dev/null || true
sudo find "$SHELL_DIR" -name "*.orig" -delete 2>/dev/null || true
ok "Limpeza concluída"

echo ""
echo -e "${GREEN}=== Instalação concluída! ===${NC}"
echo "Reiniciando quickshell..."

# Rodar como o usuário real (não root)
REAL_USER="${SUDO_USER:-$USER}"
sudo -u "$REAL_USER" bash -c '
  pkill -9 qs 2>/dev/null || true
  pkill -9 quickshell 2>/dev/null || true
  sleep 1
  nohup qs -c noctalia-shell >/dev/null 2>&1 &
  disown
'
ok "Quickshell reiniciado"
