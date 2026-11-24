import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Effects

import ComputerModel 1.0

import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0
import Theme 1.0

// Home screen: PCs as chips on top, the selected PC's games below.
FocusScope {
    property ComputerModel computerModel : createModel()
    property bool userPicked: false
    readonly property bool ownsTopBar: true
    property real windowOffset: 0
    function measureOffset() { windowOffset = pcView.mapToItem(null, 0, 0).y }
    onYChanged: measureOffset()
    onHeightChanged: measureOffset()
    Component.onCompleted: Qt.callLater(measureOffset)

    id: pcView
    objectName: ""

    readonly property Item selected: pcList.currentItem
    readonly property bool selectedReady: selected !== null && selected.pcOnline && selected.pcPaired &&
                                          selected.pcSupported && !selected.pcUnknown

    StackView.onActivated: {
        ComputerManager.computerAddCompleted.connect(addComplete)
        focusApps()
    }

    StackView.onDeactivating: {
        ComputerManager.computerAddCompleted.disconnect(addComplete)
    }

    function focusApps()
    {
        if (appsLoader.item) {
            appsLoader.item.forceActiveFocus()
        }
        else {
            pcList.forceActiveFocus()
        }
    }

    function launchDesktop()
    {
        if (appsLoader.item) {
            appsLoader.item.launchDesktop()
        }
    }

    function loadApps()
    {
        if (selectedReady) {
            appsLoader.setSource("GameCarousel.qml", {"computerIndex": pcList.currentIndex,
                                                 "embedded": true,
                                                 "objectName": selected.pcName})
        }
        else {
            appsLoader.source = ""
        }
    }

    // Switching PCs slides the old row out and the new one in, in the
    // direction of the move, instead of popping the covers in place
    property int shownPc: -1
    function reloadApps()
    {
        var dir = pcList.currentIndex >= shownPc ? 1 : -1
        shownPc = pcList.currentIndex
        if (!appsLoader.item) {
            loadApps()
            return
        }
        swapApps.stop()
        swapApps.dir = dir
        swapApps.start()
    }

    SequentialAnimation {
        id: swapApps
        property int dir: 1
        ParallelAnimation {
            NumberAnimation { target: appsLoader; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad }
            NumberAnimation { target: appsShift; property: "x"; to: -24 * swapApps.dir; duration: 120; easing.type: Easing.InQuad }
        }
        ScriptAction { script: { appsShift.x = 24 * swapApps.dir; loadApps() } }
        ParallelAnimation {
            NumberAnimation { target: appsLoader; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: appsShift; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }
    }

    onSelectedReadyChanged: reloadApps()
    Connections {
        target: pcList
        function onCurrentIndexChanged() { reloadApps() }
    }

    function pairingComplete(error)
    {
        // Close the PIN dialog
        pairDialog.close()

        // Display a failed dialog if we got an error
        if (error !== undefined) {
            errorDialog.text = error
            errorDialog.helpText = ""
            errorDialog.open()
        }
    }

    function addComplete(success, detectedPortBlocking)
    {
        if (!success) {
            errorDialog.text = qsTranslate("PcView", "Unable to connect to the specified PC.")

            if (detectedPortBlocking) {
                errorDialog.text += "\n\n" + qsTranslate("PcView", "This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
            }
            else {
                errorDialog.helpText = qsTranslate("PcView", "Click the Help button for possible solutions.")
            }

            errorDialog.open()
        }
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', parent, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingComplete)
        model.connectionTestCompleted.connect(testConnectionDialog.connectionTestComplete)
        model.modelReset.connect(reloadApps)
        return model
    }

    // Blurred box art of the selected game behind everything, faded into
    // the window background. Two layers crossfade when the selection moves.
    Item {
        id: backdrop
        // Reach up under the transparent toolbar so there is no seam
        anchors.fill: parent
        anchors.topMargin: -80

        readonly property string art: appsLoader.item ? appsLoader.item.currentBoxart : ""
        property bool showA: true

        onArtChanged: {
            if (showA) {
                artB.source = art
            }
            else {
                artA.source = art
            }
            showA = !showA
        }

        Image {
            id: artA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            // Tiny decode size: cheap, and the upscale adds to the blur
            sourceSize.width: 32
            visible: false
        }
        Image {
            id: artB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 32
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: artA
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            saturation: -0.1
            // Darkened so titles over bright art stay readable
            brightness: -0.25
            opacity: backdrop.showA && artA.source != "" ? 0.5 : 0
            Behavior on opacity { NumberAnimation { duration: 350 } }
        }
        MultiEffect {
            anchors.fill: parent
            source: artB
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            saturation: -0.1
            // Darkened so titles over bright art stay readable
            brightness: -0.25
            opacity: !backdrop.showA && artB.source != "" ? 0.5 : 0
            Behavior on opacity { NumberAnimation { duration: 350 } }
        }

        // Fade the edges back into the window colors so it blends in
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.bgTop }
                GradientStop { position: 0.3; color: "transparent" }
                GradientStop { position: 0.7; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.bgBottom }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#cc0a0c11" }
                GradientStop { position: 0.3; color: "transparent" }
                GradientStop { position: 0.7; color: "transparent" }
                GradientStop { position: 1.0; color: "#cc0a0c11" }
            }
        }
    }

    // The window has no title bar (content runs under it), so the empty
    // part of the top row moves the window instead
    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        y: -windowOffset
        height: topRow.y + topRow.height + 8 + windowOffset
        acceptedButtons: Qt.LeftButton
        onPressed: window.startSystemMove()
    }

    RowLayout {
        id: topRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // Same line as the macOS traffic lights, clear of them
        anchors.leftMargin: Qt.platform.os === "osx" ? 92 : 20
        anchors.rightMargin: 16
        // Pull up past where the hidden window toolbar would start, so the
        // row sits level with the traffic lights at the window's top edge
        // Centered on the traffic lights (about 14px down), with room above
        anchors.topMargin: 10 - windowOffset
        height: 32
        spacing: 10

        ListView {
            id: pcList
            property int dragFrom: -1
            property int dragTo: -1
            property real dragGap: 0
            property bool dragAnim: false
            // Only as wide as the chips, so the rest of the row can drag the window
            Layout.preferredWidth: Math.min(contentWidth, topRow.width - 100)
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            focus: true
            activeFocusOnTab: true
            model: computerModel
            currentIndex: -1
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds

            onCountChanged: {
                if (currentIndex < 0 && count > 0) {
                    currentIndex = 0
                }
            }

            Keys.onDownPressed: focusApps()
            Keys.onReturnPressed: if (currentItem) currentItem.clicked()
            Keys.onEnterPressed: if (currentItem) currentItem.clicked()
            Keys.onMenuPressed: if (currentItem) currentItem.pcContextMenu.open()
            Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)

            delegate: ItemDelegate {
                id: chip
                readonly property bool isCurrent: ListView.isCurrentItem
                readonly property string pcName: model.name
                readonly property bool pcOnline: model.online
                readonly property bool pcPaired: model.paired
                readonly property bool pcUnknown: model.statusUnknown
                readonly property bool pcSupported: model.serverSupported
                readonly property bool pcWakeable: model.wakeable
                readonly property bool pcReady: pcOnline && pcPaired && pcSupported && !pcUnknown

                property alias pcContextMenu : pcContextMenuLoader.item

                // Long-press and drag to reorder
                property bool dragging: false
                property real dragStartX: 0
                property real dragOffset: 0
                z: dragging ? 10 : 1
                // Others slide aside live while one is dragged
                property real shift: {
                    var f = pcList.dragFrom, t = pcList.dragTo
                    if (f < 0 || index === f) return 0
                    if (f < t && index > f && index <= t) return -pcList.dragGap
                    if (f > t && index >= t && index < f) return pcList.dragGap
                    return 0
                }
                Behavior on shift { enabled: pcList.dragAnim; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                transform: Translate { x: chip.dragging ? chip.dragOffset : chip.shift }
                scale: dragging ? 1.06 : 1.0
                Behavior on scale { NumberAnimation { duration: 120 } }
                onPressXChanged: {
                    if (!dragging) return
                    dragOffset += pressX - dragStartX
                    var t = pcList.indexAt(x + width / 2 + dragOffset, height / 2)
                    if (t >= 0) pcList.dragTo = t
                }
                onReleased: finishDrag()
                onCanceled: finishDrag()
                function finishDrag() {
                    if (!dragging) {
                        return
                    }
                    var target = pcList.dragTo
                    dragging = false
                    dragOffset = 0
                    pcList.interactive = true
                    // clear the slide without animation, then move: the slid items already sit where the move puts them
                    pcList.dragAnim = false
                    pcList.dragFrom = -1
                    pcList.dragTo = -1
                    if (target >= 0 && target !== index) {
                        pcView.userPicked = true
                        pcList.currentIndex = computerModel.moveComputer(index, target)
                    }
                }

                // Jump to the first PC that is ready until the user picks one
                onPcReadyChanged: {
                    if (pcReady && !pcView.userPicked && !(pcView.selected && pcView.selected.pcReady)) {
                        pcList.currentIndex = index
                    }
                }

                height: pcList.height
                leftPadding: 14
                rightPadding: 16
                topPadding: 0
                bottomPadding: 0

                background: Rectangle {
                    radius: height / 2
                    color: chip.isCurrent ? Theme.focus : (chip.hovered ? Theme.chipHover : Theme.chip)
                    border.width: chip.isCurrent && pcList.activeFocus ? 2 : 0
                    border.color: Theme.accent
                }

                contentItem: Row {
                    spacing: 8
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: chip.pcUnknown ? Theme.textDim : (!chip.pcOnline ? Theme.textMute : (chip.pcPaired ? Theme.ok : Theme.warn))
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.pcName
                        font.pointSize: 12
                        color: chip.isCurrent ? Theme.onLight : Theme.text
                    }
                }

                Loader {
                    id: pcContextMenuLoader
                    asynchronous: true
                    sourceComponent: NavigableMenu {
                        id: pcContextMenu
                        initiator: pcContextMenuLoader.parent
                        MenuItem {
                            text: qsTranslate("PcView", "PC Status: %1").arg(model.online ? qsTranslate("PcView", "Online") : qsTranslate("PcView", "Offline"))
                            font.bold: true
                            enabled: false
                        }
                        NavigableMenuItem {
                            text: qsTranslate("PcView", "View All Apps")
                            onTriggered: {
                                var component = Qt.createComponent("GameCarousel.qml")
                                var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name, "showHiddenGames": true})
                                stackView.push(appView)
                            }
                            visible: model.online && model.paired
                        }
                        NavigableMenuItem {
                            text: qsTranslate("PcView", "Wake PC")
                            onTriggered: computerModel.wakeComputer(index)
                            visible: !model.online && model.wakeable
                        }
                        NavigableMenuItem {
                            text: qsTranslate("PcView", "Test Network")
                            onTriggered: {
                                computerModel.testConnectionForComputer(index)
                                testConnectionDialog.open()
                            }
                        }
        
                        NavigableMenuItem {
                            text: qsTranslate("PcView", "Rename PC")
                            onTriggered: {
                                renamePcDialog.pcIndex = index
                                renamePcDialog.originalName = model.name
                                renamePcDialog.open()
                            }
                        }
                        NavigableMenuItem {
                            text: qsTranslate("PcView", "Delete PC")
                            onTriggered: {
                                deletePcDialog.pcIndex = index
                                deletePcDialog.pcName = model.name
                                deletePcDialog.open()
                            }
                        }
                        NavigableMenuItem {
                            text: qsTranslate("PcView", "View Details")
                            onTriggered: {
                                showPcDetailsDialog.pcDetails = model.details
                                showPcDetailsDialog.open()
                            }
                        }
                    }
                }

                onClicked: {
                    pcView.userPicked = true
                    var wasCurrent = isCurrent
                    pcList.currentIndex = index

                    if (pcUnknown) {
                        return
                    }
                    if (!pcOnline) {
                        pcContextMenu.open()
                    }
                    else if (!pcSupported) {
                        errorDialog.text = qsTranslate("PcView", "The version of GeForce Experience on %1 is not supported by this build of Moonlight. You must update Moonlight to stream from %1.").arg(pcName)
                        errorDialog.helpText = ""
                        errorDialog.open()
                    }
                    else if (!pcPaired) {
                        var pin = computerModel.generatePinString()
                        computerModel.pairComputer(index, pin)
                        pairDialog.pin = pin
                        pairDialog.open()
                    }
                    else if (wasCurrent) {
                        focusApps()
                    }
                }

                onPressAndHold: {
                    dragging = true
                    dragStartX = pressX
                    pcList.dragGap = width + pcList.spacing
                    pcList.dragAnim = true
                    pcList.dragFrom = index
                    pcList.dragTo = index
                    pcList.interactive = false
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton;
                    onClicked: {
                        if (chip.pcContextMenu.popup) {
                            chip.pcContextMenu.popup()
                        }
                        else {
                            chip.pcContextMenu.open()
                        }
                    }
                }

                Keys.onDeletePressed: {
                    deletePcDialog.pcIndex = index
                    deletePcDialog.pcName = model.name
                    deletePcDialog.open()
                }
            }
        }

        Item { Layout.fillWidth: true }

        // The window toolbar is hidden on this screen; these replace it
        NavigableToolButton {
            iconSource: "qrc:/res/custom/plus.svg"
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            icon.width: 20
            icon.height: 20
            onClicked: addPcDialog.open()
            ToolTip.text: qsTranslate("main", "Add PC manually")
            ToolTip.delay: 1000
            ToolTip.visible: hovered
        }
        NavigableToolButton {
            iconSource: "qrc:/res/custom/gear.svg"
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            icon.width: 20
            icon.height: 20
            onClicked: navigateTo("qrc:/gui/SettingsShell.qml", SettingsShell)
        }
    }

    // Cmd+Shift+[ / ] switch PCs (Ctrl on other systems)
    function stepPc(delta)
    {
        var next = Math.max(0, Math.min(pcList.count - 1, pcList.currentIndex + delta))
        if (next !== pcList.currentIndex) {
            userPicked = true
            pcList.currentIndex = next
        }
    }
    // Matched by key code: the shifted bracket differs per keyboard layout
    Keys.onPressed: (event) => {
        if (!(event.modifiers & Qt.ControlModifier) || !(event.modifiers & Qt.ShiftModifier)) {
            return
        }
        if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BraceLeft) {
            stepPc(-1)
            event.accepted = true
        }
        else if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_BraceRight) {
            stepPc(1)
            event.accepted = true
        }
    }

    // The Desktop tile is in the game row; Ctrl+D still jumps straight to it
    Shortcut {
        sequence: "Ctrl+D"
        onActivated: if (pcView.selectedReady) launchDesktop()
    }

    Loader {
        id: appsLoader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topRow.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 16
        transform: Translate { id: appsShift }
        onLoaded: if (pcView.activeFocus || pcList.activeFocus === false) item.forceActiveFocus()
    }

    // What to show when the selected PC has no games to list
    Column {
        anchors.centerIn: appsLoader
        spacing: 14
        visible: !pcView.selectedReady

        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pcList.count === 0 ? StreamingPreferences.enableMdns : (pcView.selected !== null && pcView.selected.pcUnknown)
            running: visible
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pointSize: 16
            color: Theme.text
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            width: Math.min(implicitWidth, pcView.width - 80)
            text: {
                var pc = pcView.selected
                if (pcList.count === 0 || pc === null) {
                    return StreamingPreferences.enableMdns ? qsTranslate("PcView", "Searching for compatible hosts on your local network...")
                                                           : qsTranslate("PcView", "Automatic PC discovery is disabled. Add your PC manually.")
                }
                if (pc.pcUnknown) return "연결 확인 중"
                if (!pc.pcOnline) return pc.pcName + " 꺼져 있음"
                if (!pc.pcSupported) return "지원하지 않는 호스트 버전"
                if (!pc.pcPaired) return pc.pcName + " 페어링 필요"
                return ""
            }
        }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property var pc: pcView.selected
            visible: pc !== null && !pc.pcUnknown && ((!pc.pcOnline && pc.pcWakeable) || (pc.pcOnline && !pc.pcPaired))
            text: pc !== null && pc.pcOnline ? "페어링" : "깨우기"
            onClicked: {
                if (pc.pcOnline) {
                    pc.clicked()
                }
                else {
                    computerModel.wakeComputer(pcList.currentIndex)
                }
            }
        }
    }

    ErrorMessageDialog {
        id: errorDialog

        // Using Setup-Guide here instead of Troubleshooting because it's likely that users
        // will arrive here by forgetting to enable GameStream or not forwarding ports.
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide"
    }

    NavigableMessageDialog {
        id: pairDialog
        closePolicy: Popup.CloseOnEscape

        // don't allow edits to the rest of the window while open
        property string pin : "0000"
        text:qsTranslate("PcView", "Please enter %1 on your host PC. This dialog will close when pairing is completed.").arg(pin)+"\n\n"+
             qsTranslate("PcView", "If your host PC is running Sunshine, navigate to the Sunshine web UI to enter the PIN.")
        standardButtons: Dialog.Cancel
        onRejected: {
            // FIXME: We should interrupt pairing here
        }
    }

    NavigableMessageDialog {
        id: deletePcDialog
        // don't allow edits to the rest of the window while open
        property int pcIndex : -1
        property string pcName : ""
        text: qsTranslate("PcView", "Are you sure you want to remove '%1'?").arg(pcName)
        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            computerModel.deleteComputer(pcIndex)
        }
    }

    NavigableMessageDialog {
        id: testConnectionDialog
        closePolicy: Popup.CloseOnEscape
        standardButtons: Dialog.Ok

        onAboutToShow: {
            testConnectionDialog.text = qsTranslate("PcView", "Moonlight is testing your network connection to determine if any required ports are blocked.") + "\n\n" + qsTranslate("PcView", "This may take a few seconds…")
            showSpinner = true
        }

        function connectionTestComplete(result, blockedPorts)
        {
            if (result === -1) {
                text = qsTranslate("PcView", "The network test could not be performed because none of Moonlight's connection testing servers were reachable from this PC. Check your Internet connection or try again later.")
                imageSrc = "qrc:/res/baseline-warning-24px.svg"
            }
            else if (result === 0) {
                text = qsTranslate("PcView", "This network does not appear to be blocking Moonlight. If you still have trouble connecting, check your PC's firewall settings.") + "\n\n" + qsTranslate("PcView", "If you are trying to stream over the Internet, install the Moonlight Internet Hosting Tool on your gaming PC and run the included Internet Streaming Tester to check your gaming PC's Internet connection.")
                imageSrc = "qrc:/res/baseline-check_circle_outline-24px.svg"
            }
            else {
                text = qsTranslate("PcView", "Your PC's current network connection seems to be blocking Moonlight. Streaming over the Internet may not work while connected to this network.") + "\n\n" + qsTranslate("PcView", "The following network ports were blocked:") + "\n"
                text += blockedPorts
                imageSrc = "qrc:/res/baseline-error_outline-24px.svg"
            }

            // Stop showing the spinner and show the image instead
            showSpinner = false
        }
    }

    NavigableDialog {
        id: renamePcDialog
        property string label: qsTranslate("PcView", "Enter the new name for this PC:")
        property string originalName
        property int pcIndex : -1;

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            editText.forceActiveFocus()
        }

        onClosed: {
            editText.clear()
        }

        onAccepted: {
            if (editText.text) {
                computerModel.renameComputer(pcIndex, editText.text)
            }
        }

        ColumnLayout {
            Label {
                text: renamePcDialog.label
                font.bold: true
            }

            TextField {
                id: editText
                placeholderText: renamePcDialog.originalName
                Layout.fillWidth: true
                focus: true

                Keys.onReturnPressed: {
                    renamePcDialog.accept()
                }

                Keys.onEnterPressed: {
                    renamePcDialog.accept()
                }
            }
        }
    }

    NavigableMessageDialog {
        id: showPcDetailsDialog
        property string pcDetails : "";
        text: showPcDetailsDialog.pcDetails
        imageSrc: "qrc:/res/baseline-help_outline-24px.svg"
        standardButtons: Dialog.Ok
    }
}
