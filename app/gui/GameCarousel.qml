import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Effects
import QtQuick.Shapes

import AppModel 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0
import Theme 1.0

// Console-style carousel: covers sit on one row, the current one is large
// with its title above it. Used embedded in PcView and pushed alone for
// "View All Apps".
ListView {
    property int computerIndex
    property AppModel appModel : createModel()
    property bool activated
    property bool showHiddenGames
    property bool showGames
    property bool embedded: false

    // Covers grow with the window; room is kept above for the title and buttons
    readonly property int bigCoverWidth: Math.round(Math.max(240, Math.min((height - 240) * 0.75, 420)))
    readonly property int coverWidth: Math.round(bigCoverWidth * 0.625)

    // Box art of the selected game, for HomeView's blurred backdrop
    readonly property string currentBoxart: currentItem && currentItem.hasArt ? currentItem.boxart : ""

    id: appGrid
    property int dragFrom: -1
    property int dragTo: -1
    property real dragGap: 0
    property bool dragAnim: false
    focus: true
    activeFocusOnTab: true
    orientation: ListView.Horizontal
    spacing: 18
    clip: false
    // The selected cover always sits in the middle
    highlightRangeMode: ListView.StrictlyEnforceRange
    preferredHighlightBegin: (width - bigCoverWidth) / 2
    preferredHighlightEnd: (width + bigCoverWidth) / 2
    // No animations while the list fills in, so a freshly loaded row
    // appears in place instead of growing and sliding into position
    property bool settled: false
    highlightMoveDuration: settled ? 220 : 0

    Timer {
        id: settleTimer
        interval: 300
        onTriggered: appGrid.settled = true
    }
    boundsBehavior: Flickable.StopAtBounds

    function computerLost()
    {
        // Go back to the PC view on PC loss
        if (!embedded) {
            stackView.pop()
        }
    }

    // Start on the running game, otherwise the first one
    function pickStartIndex()
    {
        if (count === 0) {
            return
        }
        var runningIndex = appModel.getRunningAppIndex()
        currentIndex = runningIndex >= 0 ? runningIndex : 0
    }

    function onShown()
    {
        appModel.computerLost.connect(computerLost)
        activated = true
        pickStartIndex()

        if (!showGames && !showHiddenGames) {
            // Check if there's a direct launch app
            var directLaunchAppIndex = model.getDirectLaunchAppIndex();
            if (directLaunchAppIndex >= 0) {
                currentIndex = directLaunchAppIndex
                currentItem.launchOrResumeSelectedApp(false)

                // Set showGames so we will not loop when the stream ends
                showGames = true
            }
        }
    }

    function onHidden()
    {
        appModel.computerLost.disconnect(computerLost)
        activated = false
    }

    function launchDesktop()
    {
        var desktopIndex = appModel.getDesktopAppIndex()
        if (desktopIndex < 0) {
            noDesktopDialog.open()
            return
        }
        currentIndex = desktopIndex
        currentItem.launchOrResumeSelectedApp(true)
    }

    Component.onCompleted: {
        if (embedded) {
            onShown()
        }
    }
    Component.onDestruction: {
        if (embedded && activated) {
            onHidden()
        }
    }

    StackView.onActivated: onShown()
    StackView.onDeactivating: onHidden()

    onCountChanged: {
        if (!settled) {
            settleTimer.restart()
        }
        if (currentIndex < 0 || appModel.getRunningAppIndex() >= 0) {
            pickStartIndex()
        }
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import AppModel 1.0; AppModel {}', parent, '')
        model.initialize(ComputerManager, computerIndex, showHiddenGames)
        return model
    }

    model: appModel

    delegate: ItemDelegate {
        id: card
        readonly property bool isCurrent: ListView.isCurrentItem
        readonly property bool focused: isCurrent && appGrid.activeFocus
        readonly property string boxart: model.boxart
        readonly property bool hasArt: !cover.isPlaceholder && !cover.isStockDesktop

        width: isCurrent ? appGrid.bigCoverWidth : appGrid.coverWidth
        height: appGrid.height
        padding: 0
        background: null
        opacity: model.hidden ? 0.4 : (isCurrent ? 1.0 : 0.7)

        Behavior on width { enabled: appGrid.settled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { enabled: appGrid.settled; NumberAnimation { duration: 180 } }

        property alias appContextMenu: appContextMenuLoader.item

        // Long-press and drag to reorder (right click opens the menu)
        property bool dragging: false
        property real dragStartX: 0
        property real dragOffset: 0
        z: dragging ? 10 : 1
        // Others slide aside live while one is dragged
        property real shift: {
            var f = appGrid.dragFrom, t = appGrid.dragTo
            if (f < 0 || index === f) return 0
            if (f < t && index > f && index <= t) return -appGrid.dragGap
            if (f > t && index >= t && index < f) return appGrid.dragGap
            return 0
        }
        Behavior on shift { enabled: appGrid.dragAnim; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        transform: Translate { x: card.dragging ? card.dragOffset : card.shift }
        scale: dragging ? 1.04 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }
        onPressXChanged: {
            if (!dragging) return
            dragOffset += pressX - dragStartX
            var t = appGrid.indexAt(x + width / 2 + dragOffset, height / 2)
            if (t >= 0) appGrid.dragTo = t
        }
        onReleased: finishDrag()
        onCanceled: finishDrag()
        function finishDrag() {
            if (!dragging) {
                return
            }
            var target = appGrid.dragTo
            dragging = false
            dragOffset = 0
            appGrid.interactive = true
            // clear the slide without animation, then move: the slid items already sit where the move puts them
            appGrid.dragAnim = false
            appGrid.dragFrom = -1
            appGrid.dragTo = -1
            if (target >= 0 && target !== index) {
                // Keep the selected cover selected so the row does not re-center
                var from = index, cur = appGrid.currentIndex, wasCurrent = isCurrent
                var moved = appModel.moveApp(from, target - from)
                if (wasCurrent) {
                    cur = moved
                }
                else if (from < cur && moved >= cur) {
                    cur--
                }
                else if (from > cur && moved <= cur) {
                    cur++
                }
                appGrid.currentIndex = cur
            }
        }

        Item {
            id: cover
            width: parent.width
            height: width * 4 / 3
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 18

            property bool isPlaceholder: false
            readonly property bool isStockDesktop: model.appid === 881448767

            Rectangle {
                anchors.fill: parent
                radius: 18
                color: Theme.surfaceHigh
            }

            Image {
                id: appIcon
                anchors.fill: parent
                source: model.boxart
                fillMode: Image.PreserveAspectCrop
                visible: false

                onStatusChanged: {
                    if (status !== Image.Ready) {
                        return
                    }
                    var w = implicitWidth, h = implicitHeight
                    // Same placeholder sizes the stock grid detects
                    cover.isPlaceholder = !model.isAppCollectorGame &&
                        ((w === 130 && h === 180) || (w === 628 && h === 888) || (w === 200 && h === 266))
                }
            }

            Item {
                id: coverMask
                anchors.fill: parent
                layer.enabled: true
                visible: false
                Rectangle { anchors.fill: parent; radius: 18 }
            }

            MultiEffect {
                anchors.fill: parent
                source: appIcon
                maskEnabled: true
                maskSource: coverMask
                visible: !cover.isPlaceholder && !cover.isStockDesktop
            }

            // Sunshine's stock Desktop art (same app id on every host): drawn
            // here as a lit color field with the PC name instead
            Item {
                id: desktopArt
                anchors.fill: parent
                visible: false
                layer.enabled: cover.isStockDesktop

                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeWidth: 0
                        fillGradient: RadialGradient {
                            centerX: desktopArt.width * 0.2
                            centerY: desktopArt.height * 0.1
                            centerRadius: desktopArt.height * 1.1
                            focalX: centerX
                            focalY: centerY
                            // Muted so it sits in the window background
                            GradientStop { position: 0.0; color: "#3a4466" }
                            GradientStop { position: 0.5; color: "#1f2536" }
                            GradientStop { position: 1.0; color: "#141822" }
                        }
                        startX: 0; startY: 0
                        PathLine { x: desktopArt.width; y: 0 }
                        PathLine { x: desktopArt.width; y: desktopArt.height }
                        PathLine { x: 0; y: desktopArt.height }
                        PathLine { x: 0; y: 0 }
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: card.isCurrent ? 16 : 12
                    spacing: 2
                    Label {
                        text: appGrid.objectName
                        font.pointSize: card.isCurrent ? 10 : 8
                        color: "#99ffffff"
                    }
                    Label {
                        text: "데스크탑"
                        font.pointSize: card.isCurrent ? 17 : 13
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: desktopArt
                maskEnabled: true
                maskSource: coverMask
                visible: cover.isStockDesktop
            }

            Label {
                anchors.fill: parent
                visible: cover.isPlaceholder && !cover.isStockDesktop
                text: model.name
                font.pointSize: card.isCurrent ? 18 : 14
                padding: 14
                color: Theme.text
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            // Running: a plain green dot
            Rectangle {
                visible: model.running
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 10
                width: 10
                height: 10
                radius: 5
                color: Theme.ok
                border.width: 2
                border.color: "#59000000"
            }

            // Hairline edge on the cover itself, a little brighter when focused
            Rectangle {
                anchors.fill: parent
                radius: 18
                color: "transparent"
                border.width: 1
                border.color: card.isCurrent && (card.focused || card.hovered) ? "#38ffffff" : "#14ffffff"
                Behavior on border.color { ColorAnimation { duration: 180 } }
            }
        }

        Column {
            visible: card.isCurrent
            // Soft shadow keeps the title readable over bright backdrops
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#e6000000"
                shadowBlur: 0.7
                shadowVerticalOffset: 1
                shadowHorizontalOffset: 0
            }
            anchors.horizontalCenter: cover.horizontalCenter
            anchors.bottom: cover.top
            anchors.bottomMargin: 16
            spacing: 4

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: model.name
                font.pointSize: 22
                font.bold: true
                color: Theme.focus
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 6
                spacing: 8

                // Main action: white pill, Enter does the same
                Rectangle {
                    width: mainLabel.implicitWidth + 32
                    height: 32
                    radius: 16
                    color: mainMouse.pressed ? "#d9ffffff" : "white"
                    Label {
                        id: mainLabel
                        anchors.centerIn: parent
                        text: model.running ? "이어 하기" : "시작"
                        font.pointSize: 12
                        font.bold: true
                        color: Theme.onLight
                    }
                    MouseArea {
                        id: mainMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: launchOrResumeSelectedApp(true)
                    }
                }

                Rectangle {
                    visible: model.running
                    width: quitLabel.implicitWidth + 32
                    height: 32
                    radius: 16
                    color: quitMouse.pressed ? "#40ffffff" : quitMouse.containsMouse ? "#33ffffff" : "#24ffffff"
                    Label {
                        id: quitLabel
                        anchors.centerIn: parent
                        text: "끝내기"
                        font.pointSize: 12
                        color: "white"
                    }
                    MouseArea {
                        id: quitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: doQuitGame()
                    }
                }
            }
        }

        ToolTip.text: model.name
        ToolTip.delay: 1000
        ToolTip.timeout: 5000
        ToolTip.visible: hovered && !isCurrent

        // A running game always wins: picking any other game resumes the
        // running one instead of starting a second session.
        function launchOrResumeSelectedApp(quitExistingApp)
        {
            var runningId = appModel.getRunningAppId()
            var targetIndex = index
            var targetName = model.name

            if (runningId !== 0 && runningId !== model.appid) {
                var runningIndex = appModel.getRunningAppIndex()
                if (runningIndex < 0) {
                    // Running app is hidden from this grid, so it cannot be resumed here
                    if (quitExistingApp) {
                        quitAppDialog.appName = appModel.getRunningAppName()
                        quitAppDialog.segueToStream = true
                        quitAppDialog.nextAppName = model.name
                        quitAppDialog.nextAppIndex = index
                        quitAppDialog.open()
                    }
                    return
                }
                targetIndex = runningIndex
                targetName = appModel.getRunningAppName()
                appGrid.currentIndex = runningIndex
            }

            var target = appGrid.itemAtIndex(targetIndex)
            var component = Qt.createComponent("StreamSegue.qml")
            var segue = component.createObject(stackView, {
                                                   "appName": targetName,
                                                   "boxart": target && target.hasArt ? target.boxart : "",
                                                   "session": appModel.createSessionForApp(targetIndex),
                                                   "isResume": runningId !== 0
                                               })
            stackView.push(segue)
        }

        onClicked: {
            if (!isCurrent) {
                appGrid.currentIndex = index
                appGrid.forceActiveFocus()
                return
            }
            launchOrResumeSelectedApp(true)
        }

        onPressAndHold: {
            dragging = true
            dragStartX = pressX
            appGrid.dragGap = width + appGrid.spacing
            appGrid.dragAnim = true
            appGrid.dragFrom = index
            appGrid.dragTo = index
            appGrid.interactive = false
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton;
            onClicked: {
                if (card.appContextMenu.popup) {
                    card.appContextMenu.popup()
                }
                else {
                    card.appContextMenu.open()
                }
            }
        }

        Keys.onLeftPressed: appGrid.decrementCurrentIndex()
        Keys.onRightPressed: appGrid.incrementCurrentIndex()
        Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
        Keys.onReturnPressed: launchOrResumeSelectedApp(true)
        Keys.onEnterPressed: launchOrResumeSelectedApp(true)
        Keys.onMenuPressed: appContextMenu.open()

        function doQuitGame() {
            quitAppDialog.appName = appModel.getRunningAppName()
            quitAppDialog.segueToStream = false
            quitAppDialog.open()
        }

        Loader {
            id: appContextMenuLoader
            asynchronous: true
            sourceComponent: NavigableMenu {
                id: appContextMenu
                initiator: appContextMenuLoader.parent
                NavigableMenuItem {
                    text: model.running ? qsTranslate("AppView", "Resume Game") : qsTranslate("AppView", "Launch Game")
                    onTriggered: launchOrResumeSelectedApp(true)
                }
                NavigableMenuItem {
                    text: qsTranslate("AppView", "Quit Game")
                    onTriggered: doQuitGame()
                    visible: model.running
                }
                NavigableMenuItem {
                    checkable: true
                    checked: model.directLaunch
                    text: qsTranslate("AppView", "Direct Launch")
                    onTriggered: appModel.setAppDirectLaunch(model.index, !model.directLaunch)
                    enabled: !model.hidden
                }
                NavigableMenuItem {
                    text: "왼쪽으로 옮기기"
                    enabled: model.index > 0
                    onTriggered: appGrid.currentIndex = appModel.moveApp(model.index, -1)
                }
                NavigableMenuItem {
                    text: "오른쪽으로 옮기기"
                    enabled: model.index < appGrid.count - 1
                    onTriggered: appGrid.currentIndex = appModel.moveApp(model.index, 1)
                }
                NavigableMenuItem {
                    checkable: true
                    checked: model.hidden
                    text: qsTranslate("AppView", "Hide Game")
                    onTriggered: appModel.setAppHidden(model.index, !model.hidden)
                    enabled: model.hidden || (!model.running && !model.directLaunch)
                }
            }
        }
    }

    // Keyboard focus lands on the list itself, so route keys to the current card
    Keys.onLeftPressed: decrementCurrentIndex()
    Keys.onRightPressed: incrementCurrentIndex()
    Keys.onReturnPressed: if (currentItem) currentItem.launchOrResumeSelectedApp(true)
    Keys.onEnterPressed: if (currentItem) currentItem.launchOrResumeSelectedApp(true)
    Keys.onMenuPressed: if (currentItem) currentItem.appContextMenu.open()
    Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)

    Label {
        anchors.centerIn: parent
        visible: appGrid.count === 0
        text: qsTranslate("AppView", "This computer doesn't seem to have any applications or some applications are hidden")
        font.pointSize: 16
        color: Theme.textDim
        wrapMode: Text.Wrap
    }

    NavigableMessageDialog {
        id: noDesktopDialog
        text: "이 PC에 Desktop 앱이 없어요. Sunshine 의 Applications 에 Desktop 을 추가하세요."
        standardButtons: Dialog.Ok
    }

    NavigableMessageDialog {
        id: quitAppDialog
        property string appName : ""
        property bool segueToStream : false
        property string nextAppName: ""
        property int nextAppIndex: 0
        text:qsTranslate("AppView", "Are you sure you want to quit %1? Any unsaved progress will be lost.").arg(appName)
        standardButtons: Dialog.Yes | Dialog.No

        function quitApp() {
            var component = Qt.createComponent("QuitSegue.qml")
            var params = {"appName": appName, "quitRunningAppFn": function() { appModel.quitRunningApp() }}
            if (segueToStream) {
                params.nextAppName = nextAppName
                params.nextSession = appModel.createSessionForApp(nextAppIndex)
            }
            else {
                params.nextAppName = null
                params.nextSession = null
            }

            stackView.push(component.createObject(stackView, params))
        }

        onAccepted: quitApp()
    }
}
