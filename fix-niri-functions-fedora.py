#!/usr/bin/env python3
"""Fix NiriService.qml functions to work with modular niri config (includes).
Fedora version - uses ~/.config/quickshell/noctalia-shell/
"""

import os

SD = os.path.expanduser("~/.config/quickshell/noctalia-shell")
TARGET = os.path.join(SD, "Services/Compositor/NiriService.qml")

with open(TARGET) as f:
    content = f.read()

# Replace all 3 broken functions with working versions
OLD_FUNCS = '''  function setFocusRingWidth(width) {
    try {
      var cmd = "sed -i '/^\\\\s*focus-ring\\\\s*{/,/}/ s/^\\\\(\\\\s*\\\\)width [0-9]\\\\+/\\\\1width " + width + "/' ~/.config/niri/config.kdl && niri msg action load-config-file";
      Quickshell.execDetached(["sh", "-c", cmd]);
      Logger.i("NiriService", "Setting focus-ring width to " + width);
    } catch (e) {
      Logger.e("NiriService", "Failed to set focus-ring width:", e);
    }
  }

  function setGaps(gaps) {
    try {
      var cmd = "sed -i 's/^\\\\s*gaps [0-9]\\\\+/    gaps " + gaps + "/' ~/.config/niri/config.kdl && niri msg action load-config-file";
      Quickshell.execDetached(["sh", "-c", cmd]);
      Logger.i("NiriService", "Setting gaps to " + gaps);
    } catch (e) {
      Logger.e("NiriService", "Failed to set gaps:", e);
    }
  }

  function applyLayoutSettings(focusRingWidth, gaps) {
    try {
      var cmd = "sed -i -e 's/^\\\\s*gaps [0-9]\\\\+/    gaps " + gaps + "/' -e '/^\\\\s*focus-ring\\\\s*{/,/}/ s/^\\\\(\\\\s*\\\\)width [0-9]\\\\+/\\\\1width " + focusRingWidth + "/' ~/.config/niri/config.kdl && niri msg action load-config-file";
      Quickshell.execDetached(["sh", "-c", cmd]);
      Logger.i("NiriService", "Applied layout settings: focus-ring=" + focusRingWidth + " gaps=" + gaps);
    } catch (e) {
      Logger.e("NiriService", "Failed to apply layout settings:", e);
    }
  }'''

# New functions that:
# 1. Search all .kdl files recursively for the right content
# 2. Handle focus-ring not existing (create it in layout.kdl)
# 3. Handle gaps inside layout {} block properly
NEW_FUNCS = r'''  function setFocusRingWidth(width) {
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
  }'''

if OLD_FUNCS in content:
    content = content.replace(OLD_FUNCS, NEW_FUNCS)
    with open(TARGET, "w") as f:
        f.write(content)
    print("OK - funções corrigidas")
else:
    print("WARN - funções antigas não encontradas exatamente, tentando busca flexível")
    import re
    pattern = r'(  function setFocusRingWidth\(width\) \{.*?  \}\n\n  function setGaps\(gaps\) \{.*?  \}\n\n  function applyLayoutSettings\(focusRingWidth, gaps\) \{.*?  \})'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        content = content[:match.start()] + NEW_FUNCS + content[match.end():]
        with open(TARGET, "w") as f:
            f.write(content)
        print("OK - funções corrigidas (fallback)")
    else:
        print("FAIL - não encontrou as funções para substituir")
        exit(1)
