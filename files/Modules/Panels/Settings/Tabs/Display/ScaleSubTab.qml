import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  readonly property var scaleOptions: [
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

  NLabel {
    label: I18n.tr("panels.display.scale-title")
    description: I18n.tr("panels.display.scale-description")
    Layout.fillWidth: true
  }

  Repeater {
    model: Quickshell.screens || []
    delegate: NBox {
      Layout.fillWidth: true
      implicitHeight: Math.round(contentCol.implicitHeight + Style.margin2L)
      color: Color.mSurface

      readonly property real currentScale: {
        const info = CompositorService.displayScales[modelData.name];
        return (info && info.scale) ? info.scale : 1.0;
      }

      readonly property string currentScaleKey: {
        // Find the closest matching scale option
        var bestKey = currentScale.toString();
        var bestDiff = Infinity;
        for (var i = 0; i < scaleOptions.length; i++) {
          var diff = Math.abs(scaleOptions[i].scale - currentScale);
          if (diff < bestDiff) {
            bestDiff = diff;
            bestKey = scaleOptions[i].key;
          }
        }
        return bestKey;
      }

      ColumnLayout {
        id: contentCol
        width: parent.width - 2 * Style.marginL
        x: Style.marginL
        y: Style.marginL
        spacing: Style.marginS

        RowLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignBottom

          NText {
            text: modelData.name || "Unknown"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightSemiBold
            Layout.alignment: Qt.AlignBottom
          }

          NText {
            Layout.fillWidth: true
            text: {
              I18n.tr("system.monitor-description", {
                        "model": modelData.model,
                        "width": modelData.width * currentScale,
                        "height": modelData.height * currentScale,
                        "scale": currentScale
                      });
            }
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignBottom
          }
        }

        NComboBox {
          Layout.fillWidth: true
          label: I18n.tr("panels.display.scale-label")
          description: I18n.tr("panels.display.scale-item-description")
          model: scaleOptions
          currentKey: currentScaleKey
          onSelected: key => {
                        CompositorService.setOutputScale(modelData.name, key);
                      }
        }
      }
    }
  }

  NText {
    text: I18n.tr("panels.display.scale-note")
    pointSize: Style.fontSizeXS
    color: Color.mOnSurfaceVariant
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }
}
