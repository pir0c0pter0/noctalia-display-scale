import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
    id: root

    property string prompt: "spotfy@noctalia:~$"
    property alias contentItem: contentArea.data

    implicitHeight: outerColumn.implicitHeight
    implicitWidth: outerColumn.implicitWidth

    readonly property string borderColor: Color.mOutline
    readonly property string bgColor: Color.mSurface
    readonly property string textColor: Color.mOnSurface
    readonly property string promptColor: Color.mPrimary
    readonly property int fontSize: Style.fontSizeM

    ColumnLayout {
        id: outerColumn
        anchors.fill: parent
        spacing: 0

        // Top border
        Text {
            Layout.fillWidth: true
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.borderColor
            text: "╔" + "═".repeat(Math.max(0, Math.floor(root.width / charWidth()) - 2)) + "╗"

            function charWidth() {
                return font.pixelSize * 0.6
            }
        }

        // Content area with side borders
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.borderColor
                text: "║"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Style.marginS
                spacing: Style.marginXS

                // Prompt line
                Row {
                    spacing: Style.marginXS

                    Text {
                        font.family: "monospace"
                        font.pixelSize: root.fontSize
                        color: root.promptColor
                        text: root.prompt
                    }

                    // Blinking cursor
                    Text {
                        font.family: "monospace"
                        font.pixelSize: root.fontSize
                        color: root.promptColor
                        text: "█"
                        visible: cursorTimer.cursorVisible

                        Timer {
                            id: cursorTimer
                            property bool cursorVisible: true
                            interval: 500
                            repeat: true
                            running: root.visible
                            onTriggered: cursorVisible = !cursorVisible
                        }
                    }
                }

                // User content goes here
                Item {
                    id: contentArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }

            Text {
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: root.borderColor
                text: "║"
            }
        }

        // Bottom border
        Text {
            Layout.fillWidth: true
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.borderColor
            text: "╚" + "═".repeat(Math.max(0, Math.floor(root.width / charWidth()) - 2)) + "╝"

            function charWidth() {
                return font.pixelSize * 0.6
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgColor
        opacity: 0.95
        z: -1
        radius: Style.radiusS
    }
}
