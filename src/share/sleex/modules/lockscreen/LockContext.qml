import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root
    signal shouldReFocus()
    signal unlocked()
    signal failed()
    signal animate()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool forcePassword: false
    property bool awaitingPassword: false
    property var pendingPamMessage: null
    property bool autoSubmit: false
    property bool enableFaceAuth: Config.options.lockscreen.enableFaceAuth
    
    Timer {
        id: passwordClearTimer
        interval: 10000
        onTriggered: {
            root.currentText = "";
        }
    }

    onCurrentTextChanged: {
        if (currentText.length > 0) {
            showFailure = false;
            GlobalStates.screenUnlockFailed = false;
        }
        GlobalStates.screenLockContainsCharacters = currentText.length > 0;
        passwordClearTimer.restart();
    }

    function startAuth() {
        if (!unlockInProgress) {
            root.unlockInProgress = true;
            root.awaitingPassword = false;
            root.showFailure = false;
            root.autoSubmit = false;
            root.forcePassword = !root.enableFaceAuth;             
            pam.start();
        }
    }

    function submitPassword() {
        if (root.awaitingPassword) {
            root.awaitingPassword = false;
            pam.respond(root.currentText);
        } else if (root.unlockInProgress && root.forcePassword) {
            root.autoSubmit = true;
            root.forcePassword = false; 
        } else if (!root.unlockInProgress) {
            startAuth();
        }
    }

    PamContext {
        id: pam
        configDirectory: "pam"
        config: root.enableFaceAuth ? "password_face.conf" : "password.conf"

        onPamMessage: {
            if (this.responseRequired) {
                if (root.autoSubmit) {
                    root.autoSubmit = false;
                    this.respond(root.currentText);
                } else {
                    root.awaitingPassword = true;
                }
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.animate()
            } else {
                root.showFailure = true;
                GlobalStates.screenUnlockFailed = true;
            }

            root.currentText = "";
            root.unlockInProgress = false;
            root.awaitingPassword = false;
            root.forcePassword = false;
            root.autoSubmit = false;
        }
    }
}