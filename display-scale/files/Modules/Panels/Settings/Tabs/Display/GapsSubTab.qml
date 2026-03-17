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
