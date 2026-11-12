import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ═══════════════════════════════════════════════════════════════════════════
// equisdots · login — minimalist static SDDM theme
//
// Black screen; only the remembered user and a password field with a white
// underline. No palette dependency and no runtime writes: the theme is
// installed once (install.sh, one-time sudo) and never needs elevated
// permissions again.
//
// Animations: soft intro, underline expands on focus, shake + red on a failed
// login and a cross-fade when switching users (Tab / Backtab).
// ═══════════════════════════════════════════════════════════════════════════
Rectangle {
    id: root
    color: "#000000"

    // Static monochrome palette (no Colors.qml / no sync)
    readonly property color fg: "#ffffff"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.30)
    readonly property color err: "#e64553"

    property int currentUserIndex: 0
    property int pendingUserIndex: 0
    property string currentUserName: userModel.count > 0
        ? userModel.data(userModel.index(currentUserIndex, 0), 257)
        : "user"
    property bool loginFailed: false

    Component.onCompleted: {
        // Remember the last logged-in user (as before).
        var idx = 0;
        if (userModel.lastUser !== "") {
            for (var i = 0; i < userModel.count; ++i) {
                if (userModel.data(userModel.index(i, 0), 257) === userModel.lastUser) {
                    idx = i;
                    break;
                }
            }
        }
        currentUserIndex = idx;
        pendingUserIndex = idx;
        passwordField.forceActiveFocus();
    }

    function nextUser() { if (userModel.count > 1) switchToUser((currentUserIndex + 1) % userModel.count); }
    function prevUser() { if (userModel.count > 1) switchToUser((currentUserIndex - 1 + userModel.count) % userModel.count); }

    function switchToUser(idx) {
        if (idx === currentUserIndex) return;
        pendingUserIndex = idx;
        userSwitchAnim.restart();
    }

    // Cross-fade when switching users.
    SequentialAnimation {
        id: userSwitchAnim
        NumberAnimation { target: userColumn; property: "opacity"; to: 0.0; duration: 130; easing.type: Easing.InSine }
        ScriptAction {
            script: {
                root.currentUserIndex = root.pendingUserIndex;
                passwordField.text = "";
                root.loginFailed = false;
                errorMessage.opacity = 0.0;
            }
        }
        NumberAnimation { target: userColumn; property: "opacity"; to: 1.0; duration: 200; easing.type: Easing.OutQuart }
    }

    // Minimal circular button used by the power row.
    component PowerButton: Rectangle {
        id: pb
        property string glyph: ""
        signal clicked()
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: 17
        color: pbMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        border.width: 1
        border.color: pbMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }
        Text {
            anchors.centerIn: parent
            text: pb.glyph
            font.family: "Hack Nerd Font"
            font.pixelSize: 17
            color: pbMa.containsMouse ? root.fg : root.dim
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        MouseArea {
            id: pbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    // ── The only content: user + password + session/power row ─────────────
    ColumnLayout {
        id: userColumn
        anchors.centerIn: parent
        width: 280
        spacing: 26
        opacity: 0.0
        transform: Translate { id: introTranslate; y: 12 }

        ParallelAnimation {
            id: introAnim
            NumberAnimation { target: userColumn; property: "opacity"; to: 1.0; duration: 420; easing.type: Easing.OutQuart }
            NumberAnimation { target: introTranslate; property: "y"; to: 0; duration: 420; easing.type: Easing.OutQuart }
        }
        Component.onCompleted: introAnim.start()

        // Remembered user
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.currentUserName
            color: root.fg
            font.family: "Hack Nerd Font"
            font.pixelSize: 18
            font.weight: Font.Bold
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Password field with an animated underline
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
            Layout.preferredHeight: 46
            transform: Translate { id: shakeTranslate; x: 0 }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -8; duration: 110; easing.type: Easing.InOutSine }
                NumberAnimation { target: shakeTranslate; property: "x"; from: -8; to: 8; duration: 110; easing.type: Easing.InOutSine }
                NumberAnimation { target: shakeTranslate; property: "x"; from: 8; to: 0; duration: 110; easing.type: Easing.InOutSine }
            }

            TextInput {
                id: passwordField
                anchors.fill: parent
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                font.family: "Hack Nerd Font"
                font.pixelSize: 20
                color: root.loginFailed ? root.err : root.fg
                clip: true
                selectByMouse: true
                Behavior on color { ColorAnimation { duration: 220 } }

                Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "password"
                    color: root.dim
                    font: passwordField.font
                    visible: !passwordField.text && !passwordField.inputMethodComposing
                    Behavior on color { ColorAnimation { duration: 220 } }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Tab) { root.nextUser(); event.accepted = true; }
                    else if (event.key === Qt.Key_Backtab) { root.prevUser(); event.accepted = true; }
                }
                onAccepted: {
                    if (text !== "") {
                        errorMessage.opacity = 0.0;
                        sddm.login(root.currentUserName, text, sessionPicker.currentIndex);
                    }
                }
                onTextChanged: {
                    if (root.loginFailed) {
                        root.loginFailed = false;
                        errorMessage.opacity = 0.0;
                    }
                }
            }

            // Underline: grows from the center when the field is focused.
            Rectangle {
                id: underline
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: 2
                radius: 1
                width: passwordField.activeFocus ? parent.width : 210
                color: root.loginFailed ? root.err
                     : (passwordField.activeFocus ? root.fg : Qt.rgba(1, 1, 1, 0.28))
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 220 } }
            }
        }

        Text {
            id: errorMessage
            Layout.alignment: Qt.AlignHCenter
            text: "login failed"
            color: root.err
            font.family: "Hack Nerd Font"
            font.pixelSize: 12
            opacity: 0.0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }
        }

        // Session selector + power off / reboot, centered below the login.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            spacing: 18

            ComboBox {
                id: sessionPicker
                Layout.alignment: Qt.AlignVCenter
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex
                font.family: "Hack Nerd Font"
                font.pixelSize: 13
                implicitHeight: 30
                implicitWidth: sessionRow.implicitWidth + 26

                contentItem: Row {
                    id: sessionRow
                    spacing: 7
                    Text {
                        text: "󰧨"
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 14
                        color: sessionPicker.hovered || sessionPicker.popup.visible ? root.fg : root.dim
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    Text {
                        text: sessionPicker.currentText
                        font: sessionPicker.font
                        color: sessionPicker.hovered || sessionPicker.popup.visible ? root.fg : root.dim
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }
                background: null
                indicator: Text {
                    x: sessionPicker.width - width
                    anchors.verticalCenter: parent.verticalCenter
                    text: sessionPicker.popup.visible ? "󰅃" : "󰅀"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 12
                    color: sessionPicker.hovered || sessionPicker.popup.visible ? root.fg : root.dim
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                popup: Popup {
                    y: -(height + 8)
                    width: sessionPicker.width + 40
                    padding: 6
                    background: Rectangle {
                        color: "#0b0b0b"
                        radius: 10
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                    }
                    contentItem: ListView {
                        clip: true
                        implicitHeight: Math.min(contentHeight, 180)
                        model: sessionPicker.popup.visible ? sessionPicker.delegateModel : null
                    }
                }

                delegate: ItemDelegate {
                    width: sessionPicker.popup.width - 12
                    padding: 8
                    contentItem: Text {
                        text: model.name
                        color: hovered ? "#000000" : root.fg
                        font: sessionPicker.font
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 7
                        color: hovered ? root.fg : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                }
            }

            PowerButton {
                glyph: "󰐥"
                onClicked: sddm.powerOff()
            }
            PowerButton {
                glyph: "󰜉"
                onClicked: sddm.reboot()
            }
        }
    }

    // SDDM tells us when a login attempt failed.
    Connections {
        target: sddm
        function onLoginFailed() {
            passwordField.text = "";
            root.loginFailed = true;
            errorMessage.opacity = 1.0;
            shakeAnim.restart();
        }
    }

    // Clicking anywhere brings the focus back to the field.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: passwordField.forceActiveFocus()
    }
}
