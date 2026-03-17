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
