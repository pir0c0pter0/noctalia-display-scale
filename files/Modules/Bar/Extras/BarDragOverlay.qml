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
