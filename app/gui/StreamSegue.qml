import QtQuick 2.0
import QtQuick.Controls 2.2
import QtQuick.Window 2.2
import QtQuick.Effects

import SdlGamepadKeyNavigation 1.0
import Session 1.0
import SystemProperties 1.0

Item {
    id: segueRoot
    readonly property bool ownsTopBar: true
    property Session session
    property string appName
    // Personal build: cover shown blurred behind and small in the middle
    property string boxart: ""
    property string stageText : isResume ? qsTr("Resuming %1...").arg(appName) :
                                           qsTr("Starting %1...").arg(appName)
    property bool isResume : false
    property bool quitAfter : false

    // Personal build: keep "<app> 시작 중" as the headline and show the
    // connection step underneath, in Korean
    property string stageDetail: ""
    readonly property var stageNamesKo: ({
        "platform initialization": "준비",
        "name resolution": "주소 찾기",
        "audio stream initialization": "소리 준비",
        "RTSP handshake": "연결 약속",
        "control stream initialization": "제어 준비",
        "video stream initialization": "화면 준비",
        "input stream initialization": "입력 준비",
        "control stream establishment": "제어 연결",
        "video stream establishment": "화면 연결",
        "audio stream establishment": "소리 연결",
        "input stream establishment": "입력 연결"
    })

    function stageStarting(stage)
    {
        stageDetail = stageNamesKo[stage] || stage
    }

    function stageFailed(stage, errorCode, failingPorts)
    {
        // Display the error dialog after Session::exec() returns
        streamSegueErrorDialog.text = qsTr("Starting %1 failed: Error %2").arg(stage).arg(errorCode)

        if (failingPorts) {
            streamSegueErrorDialog.text += "\n\n" + qsTr("Check your firewall and port forwarding rules for port(s): %1").arg(failingPorts)
        }
    }

    function connectionStarted()
    {
        // Hide the UI contents so the user doesn't
        // see them briefly when we pop off the StackView
        stageSpinner.visible = false
        stageLabel.visible = false
        hintText.visible = false

        // Hide the window now that streaming has begun
        window.visible = false
    }

    function displayLaunchError(text)
    {
        // Display the error dialog after Session::exec() returns
        streamSegueErrorDialog.text = text
        console.error(text)
    }

    function quitStarting()
    {
        // Avoid the push transition animation
        var component = Qt.createComponent("QuitSegue.qml")
        stackView.replace(stackView.currentItem, component.createObject(stackView, {"appName": appName}), StackView.Immediate)

        // Show the Qt window again to show quit segue
        window.visible = true
    }

    function sessionFinished(portTestResult)
    {
        if (portTestResult !== 0 && portTestResult !== -1 && streamSegueErrorDialog.text) {
            streamSegueErrorDialog.text += "\n\n" + qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
        }

        // Re-enable GUI gamepad usage now
        SdlGamepadKeyNavigation.enable()

        // Pop the StreamSegue off the stack if this is a GUI-based app launch
        if (!quitAfter) {
            stackView.pop()
        }

        if (quitAfter && !streamSegueErrorDialog.text) {
            // If this was a CLI launch without errors, exit now
            Qt.quit()
        }
        else {
            // Show the Qt window again after streaming
            window.visible = true

            // Display any launch errors. We do this after
            // the Qt UI is visible again to prevent losing
            // focus on the dialog which would impact gamepad
            // users.
            if (streamSegueErrorDialog.text) {
                streamSegueErrorDialog.quitAfter = quitAfter
                streamSegueErrorDialog.open()
            }
        }
    }

    function sessionReadyForDeletion()
    {
        // Garbage collect the Session object since it's pretty heavyweight
        // and keeps other libraries (like SDL_TTF) around until it is deleted.
        session = null
        gc()
    }

    StackView.onDeactivating: {
        // Re-enable GUI gamepad usage now
        SdlGamepadKeyNavigation.enable()
    }

    StackView.onActivated: {
        // Hook up our signals
        session.stageStarting.connect(stageStarting)
        session.stageFailed.connect(stageFailed)
        session.connectionStarted.connect(connectionStarted)
        session.displayLaunchError.connect(displayLaunchError)
        session.quitStarting.connect(quitStarting)
        session.sessionFinished.connect(sessionFinished)
        session.readyForDeletion.connect(sessionReadyForDeletion)

        // Ensure the SystemProperties async thread is finished,
        // since it may currently be using the SDL video subsystem
        SystemProperties.waitForAsyncLoad()

        // Kick off the stream
        streamLoader.active = true
    }

    Timer {
        id: startSessionTimer
        onTriggered: {
            // Garbage collect QML stuff before we start streaming,
            // since we'll probably be streaming for a while and we
            // won't be able to GC during the stream.
            gc()

            // Run the streaming session to completion
            session.start()
        }
    }

    Loader {
        id: streamLoader
        active: false
        asynchronous: true

        onLoaded: {
            // Set the hint text. We do this here rather than
            // in the hintText control itself to synchronize
            // with Session.exec() which requires no concurrent
            // gamepad usage.
            hintText.text = qsTr("Tip:") + " " + qsTr("Press %1 to disconnect your session").arg(SdlGamepadKeyNavigation.getConnectedGamepads() > 0 ?
                                                  qsTr("Start+Select+L1+R1") :
                                                  (Qt.platform.os === "osx" ? "Ctrl+Option+Shift+Q" : qsTr("Ctrl+Alt+Shift+Q")))

            // Stop GUI gamepad usage now
            SdlGamepadKeyNavigation.disable()

            // Initialize the session and probe for host/client capabilities
            if (!session.initialize(window)) {
                sessionFinished(0);
                sessionReadyForDeletion();
                return;
            }

            // This spinner is shown only after session.initialize() has completed
            // to prevent active animations from running during decoder probing,
            // which causes re-entrant event loop livelocks with libdecor-gtk.
            stageSpinner.visible = true

            // Don't wait unless we have toasts to display
            startSessionTimer.interval = 0

            // Display the toasts together in a vertical centered arrangement
            var yOffset = 0
            for (var i = 0; i < session.launchWarnings.length; i++) {
                var text = session.launchWarnings[i]
                console.warn(text)

                // Show the tooltip for 3 seconds
                var toast = Qt.createQmlObject('import QtQuick.Controls 2.2; ToolTip {}', parent, '')
                toast.timeout = 3000
                toast.text = text
                toast.y += yOffset
                toast.visible = true

                // Offset the next toast below the previous one
                yOffset = toast.y + toast.padding + toast.height

                // Allow an extra 500 ms for the tooltip's fade-out animation to finish
                startSessionTimer.interval = toast.timeout + 500;
            }

            // Start the timer to wait for toasts (or start the session immediately)
            startSessionTimer.start()
        }

        sourceComponent: Item {}
    }

    Image {
        id: segueArt
        anchors.fill: parent
        source: boxart
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 32
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: segueArt
        visible: boxart !== ""
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        brightness: -0.3
        opacity: 0.5
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 10
        spacing: 22

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: boxart !== ""
            // Sized from the window so the cover is the main thing on screen
            height: Math.min(segueRoot.height * 0.5, 460)
            width: height * 3 / 4

            Image {
                id: segueCover
                anchors.fill: parent
                source: boxart
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            Item {
                id: segueCoverMask
                anchors.fill: parent
                layer.enabled: true
                visible: false
                Rectangle { anchors.fill: parent; radius: 18 }
            }
            // Drawn separately: a shadow on the masked effect pads it and
            // pushes the rounded corners out of view
            RectangularShadow {
                anchors.fill: parent
                radius: 18
                blur: 40
                offset.y: 16
                color: "#b3000000"
            }
            MultiEffect {
                anchors.fill: parent
                source: segueCover
                maskEnabled: true
                maskSource: segueCoverMask
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            BusyIndicator {
                id: stageSpinner
                running: visible
                visible: false
                width: 28
                height: 28
            }

            Label {
                id: stageLabel
                height: stageSpinner.height
                text: stageText
                font.pointSize: 15
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter

                wrapMode: Text.Wrap
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: stageLabel.visible && stageDetail !== ""
            text: stageDetail
            font.pointSize: 11
            opacity: 0.55
        }
    }

    Label {
        id: hintText
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        anchors.horizontalCenter: parent.horizontalCenter
        font.pointSize: 12
        opacity: 0.55
        verticalAlignment: Text.AlignVCenter

        wrapMode: Text.Wrap
    }
}
