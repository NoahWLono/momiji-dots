import QtQuick 2.15
import QtQuick.Window 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#09100d"
    focus: true

    property string backgroundFile: valueOr("Background", "background.png")
    property string avatarFile: valueOr("Avatar", "avatar.png")
    property string titleText: valueOr("Title", "Maple Nekokami")
    property string subtitleText: valueOr("Subtitle", "Welcome home, Noah :3")
    property string promptText: valueOr("Prompt", "Enter your Momiji password")
    property string buttonText: valueOr("ButtonText", "Unlock Momiji")
    property string footerText: valueOr("Footer", "Encrypted at rest. Protected in session.")
    property string fontFamily: valueOr("FontFamily", "JetBrains Mono")
    property color accent: valueOr("Accent", "#D4A017")
    property color accentAlt: valueOr("AccentAlt", "#9A3F24")
    property color leaf: valueOr("Leaf", "#4F7A3A")
    property color panelColor: valueOr("Panel", "#D9101714")
    property color textColor: valueOr("Text", "#FFF8E8")
    property color mutedColor: valueOr("Muted", "#C9D7C9")
    property color errorColor: valueOr("Error", "#FFB4AB")
    property bool panelOnRight: valueOr("PanelSide", "left").toLowerCase() === "right"
    property string loginUser: userModel.lastUser && userModel.lastUser.length > 0
                               ? userModel.lastUser : "noah"
    property int loginSession: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool authenticating: false
    property string statusText: ""

    function valueOr(key, fallback) {
        var value = config.stringValue(key)
        return value && value.length > 0 ? value : fallback
    }

    function tryLogin() {
        if (authenticating || passwordInput.text.length === 0)
            return
        authenticating = true
        statusText = "Checking credentials…"
        sddm.login(loginUser, passwordInput.text, loginSession)
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.statusText = "Welcome home :3"
        }

        function onLoginFailed() {
            root.authenticating = false
            root.statusText = "That password did not work. Try again."
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
            failurePulse.restart()
        }

        function onInformationMessage(message) {
            if (message && message.length > 0)
                root.statusText = message
        }
    }

    Image {
        id: background
        anchors.fill: parent
        source: Qt.resolvedUrl(root.backgroundFile)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#52060b09"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: root.panelOnRight ? "#16000000" : "#B5000000"
            }
            GradientStop {
                position: 0.58
                color: "#2A000000"
            }
            GradientStop {
                position: 1.0
                color: root.panelOnRight ? "#B5000000" : "#16000000"
            }
        }
    }

    Column {
        id: clockColumn
        anchors.top: parent.top
        anchors.topMargin: Math.max(34, parent.height * 0.045)
        anchors.right: parent.right
        anchors.rightMargin: Math.max(42, parent.width * 0.045)
        spacing: 3

        Text {
            id: clockText
            anchors.right: parent.right
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Math.max(36, root.height * 0.054)
            font.weight: Font.DemiBold
            text: Qt.formatTime(new Date(), "h:mm AP")
        }

        Text {
            anchors.right: parent.right
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Math.max(15, root.height * 0.021)
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clockText.text = Qt.formatTime(new Date(), "h:mm AP")
        }
    }

    Rectangle {
        id: panel
        width: Math.min(510, root.width * 0.39)
        height: Math.min(760, root.height * 0.79)
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.panelOnRight ? undefined : parent.left
        anchors.right: root.panelOnRight ? parent.right : undefined
        anchors.leftMargin: root.panelOnRight ? 0 : Math.max(42, root.width * 0.055)
        anchors.rightMargin: root.panelOnRight ? Math.max(42, root.width * 0.055) : 0
        radius: 32
        color: root.panelColor
        border.width: 1
        border.color: "#44FFFFFF"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 31
            color: "#1CFFFFFF"
        }

        Column {
            anchors.fill: parent
            anchors.leftMargin: Math.max(34, panel.width * 0.085)
            anchors.rightMargin: Math.max(34, panel.width * 0.085)
            anchors.topMargin: Math.max(32, panel.height * 0.055)
            anchors.bottomMargin: Math.max(26, panel.height * 0.045)
            spacing: 16

            Item {
                width: parent.width
                height: 172

                Rectangle {
                    id: avatarFrame
                    width: 152
                    height: 152
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 34
                    color: "#28101714"
                    border.width: 4
                    border.color: root.accent
                    scale: failurePulse.running ? 1.03 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 120 }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 8
                        source: Qt.resolvedUrl(root.avatarFile)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        color: root.leaf
                        border.width: 3
                        border.color: root.textColor

                        Text {
                            anchors.centerIn: parent
                            text: "ฅ"
                            color: root.textColor
                            font.pixelSize: 19
                            font.bold: true
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: root.titleText
                color: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(29, panel.width * 0.069)
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                text: root.subtitleText
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Math.max(15, panel.width * 0.037)
                horizontalAlignment: Text.AlignHCenter
            }

            Item { width: 1; height: 4 }

            Text {
                width: parent.width
                text: root.loginUser + "@" + sddm.hostName
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(14, panel.width * 0.032)
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                id: passwordBox
                width: parent.width
                height: 58
                radius: 16
                color: passwordInput.activeFocus ? "#E617211D" : "#B8121B17"
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: passwordInput.activeFocus ? root.accent : "#56FFFFFF"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    visible: passwordInput.text.length === 0
                    text: root.promptText
                    color: "#87FFFFFF"
                    font.family: root.fontFamily
                    font.pixelSize: 15
                }

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.textColor
                    selectionColor: root.accentAlt
                    selectedTextColor: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: 18
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    enabled: !root.authenticating
                    focus: true
                    Keys.onReturnPressed: root.tryLogin()
                    Keys.onEnterPressed: root.tryLogin()
                }
            }

            Text {
                width: parent.width
                height: 22
                text: keyboard.capsLock ? "CAPS LOCK IS ON" : root.statusText
                color: keyboard.capsLock ? root.accent :
                       root.statusText.indexOf("did not work") >= 0 ? root.errorColor : root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Rectangle {
                id: loginButton
                width: parent.width
                height: 58
                radius: 16
                color: loginMouse.pressed ? root.accentAlt : root.accent
                opacity: root.authenticating || passwordInput.text.length === 0 ? 0.58 : 1.0

                Text {
                    anchors.centerIn: parent
                    text: root.authenticating ? "Unlocking…" : root.buttonText
                    color: "#181108"
                    font.family: root.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    enabled: !root.authenticating && passwordInput.text.length > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tryLogin()
                }
            }

            Item { width: 1; height: 4 }

            Text {
                width: parent.width
                text: "ฅ^•ﻌ•^ฅ  harvest • code • purr • repeat"
                color: root.leaf
                font.family: root.fontFamily
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                text: root.footerText
                color: root.mutedColor
                opacity: 0.78
                font.family: root.fontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Math.max(34, parent.width * 0.035)
        anchors.bottomMargin: Math.max(28, parent.height * 0.035)
        spacing: 14

        Rectangle {
            width: 112
            height: 42
            radius: 14
            color: rebootMouse.containsMouse ? "#5C9A3F24" : "#38101714"
            border.width: 1
            border.color: "#40FFFFFF"
            visible: sddm.canReboot

            Text {
                anchors.centerIn: parent
                text: "Reboot"
                color: root.textColor
                font.family: root.fontFamily
                font.pixelSize: 14
            }

            MouseArea {
                id: rebootMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.reboot()
            }
        }

        Rectangle {
            width: 112
            height: 42
            radius: 14
            color: powerMouse.containsMouse ? "#5C9A3F24" : "#38101714"
            border.width: 1
            border.color: "#40FFFFFF"
            visible: sddm.canPowerOff

            Text {
                anchors.centerIn: parent
                text: "Power off"
                color: root.textColor
                font.family: root.fontFamily
                font.pixelSize: 14
            }

            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.powerOff()
            }
        }
    }

    SequentialAnimation {
        id: failurePulse
        running: false
        NumberAnimation { target: panel; property: "scale"; to: 0.985; duration: 70 }
        NumberAnimation { target: panel; property: "scale"; to: 1.0; duration: 110 }
    }

    Component.onCompleted: passwordInput.forceActiveFocus()
}
