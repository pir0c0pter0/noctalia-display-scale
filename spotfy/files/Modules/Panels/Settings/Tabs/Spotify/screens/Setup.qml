import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root

    property var service
    signal setupComplete()

    spacing: Style.marginS

    readonly property color textColor: Color.mOnSurface
    readonly property color promptColor: Color.mPrimary
    readonly property color dimColor: Color.mOnSurfaceVariant
    readonly property int fontSize: Style.fontSizeM

    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: I18n.tr("panels.spotify.setup-instruction-1")
    }

    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: I18n.tr("panels.spotify.setup-instruction-2")
    }

    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: I18n.tr("panels.spotify.setup-instruction-3")
    }

    Text {
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.textColor
        text: "  redirect_uri: http://localhost:8888/callback"
    }

    Item { Layout.preferredHeight: Style.marginM }

    // Client ID input
    Row {
        spacing: Style.marginXS
        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.promptColor
            text: "client_id>"
        }
        TextInput {
            id: clientIdInput
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.textColor
            width: 300
            clip: true
        }
    }

    // Client Secret input
    Row {
        spacing: Style.marginXS
        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.promptColor
            text: "client_secret>"
        }
        TextInput {
            id: clientSecretInput
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.textColor
            echoMode: TextInput.Password
            width: 300
            clip: true
        }
    }

    Item { Layout.preferredHeight: Style.marginS }

    Row {
        spacing: Style.marginL

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.promptColor
            text: "[" + I18n.tr("panels.spotify.save") + "]"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (clientIdInput.text.trim() && clientSecretInput.text.trim()) {
                        root.service.setup(clientIdInput.text.trim(), clientSecretInput.text.trim())
                    }
                }
            }
        }

        Text {
            font.family: "monospace"
            font.pixelSize: root.fontSize
            color: root.dimColor
            text: "[" + I18n.tr("panels.spotify.open-dashboard") + "]"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally("https://developer.spotify.com/dashboard")
            }
        }
    }

    // Status messages
    Text {
        id: statusText
        font.family: "monospace"
        font.pixelSize: root.fontSize
        color: root.dimColor
        text: ""
        visible: text !== ""
    }

    Connections {
        target: root.service
        function onCommandCompleted(command, result) {
            if (command === "setup") {
                statusText.text = I18n.tr("panels.spotify.setup-ok")
                statusText.color = root.promptColor
                // Now trigger auth
                root.service.auth()
            }
            if (command === "auth") {
                root.service.authenticated = true
                root.service.premium = result.premium || false
                root.service.userName = result.user || ""
                root.setupComplete()
            }
        }
        function onCommandError(command, code, message) {
            statusText.text = "[ERR] " + message
            statusText.color = Color.mError
        }
    }
}
