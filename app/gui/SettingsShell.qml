import QtQuick 2.9
import QtQuick.Controls 2.2
import QtCore

import StreamingPreferences 1.0
import SdlGamepadKeyNavigation 1.0
import Theme 1.0

// Settings with a category sidebar. The stock SettingsView is loaded hidden
// and its section cards are moved here, so every upstream setting and its
// logic keep working untouched; new upstream settings show up on their own.
Item {
    id: shell
    objectName: "설정"

    property var sections: []
    property int current: 0

    StackView.onActivated: {
        SdlGamepadKeyNavigation.setUiNavMode(true)
        sideList.forceActiveFocus()
    }

    StackView.onDeactivating: {
        SdlGamepadKeyNavigation.setUiNavMode(false)
        StreamingPreferences.save()
    }

    function sectionName(title)
    {
        return title.replace(/<[^>]*>/g, "").replace(/\s*(설정|Settings)$/, "")
    }

    function findByText(node, text)
    {
        if (node.text === text) {
            return node
        }
        var kids = node.children || []
        for (var i = 0; i < kids.length; i++) {
            var hit = findByText(kids[i], text)
            if (hit) {
                return hit
            }
        }
        if (node.contentItem && node.contentItem !== node) {
            return findByText(node.contentItem, text)
        }
        return null
    }

    function show(index)
    {
        current = index
        for (var i = 0; i < sections.length; i++) {
            sections[i].visible = (i === index)
        }
        content.contentY = 0
    }

    Loader {
        id: stock
        source: "SettingsView.qml"
        // Must stay "visible": some stock controls skip setup when hidden.
        // It is empty once its cards move out, so it is just transparent.
        anchors.fill: parent
        opacity: 0
        enabled: false

        onLoaded: {
            var found = []
            var columns = item.contentItem.children
            for (var c = 0; c < columns.length; c++) {
                var kids = columns[c].children
                for (var k = 0; k < kids.length; k++) {
                    if (kids[k] instanceof GroupBox) {
                        found.push(kids[k])
                    }
                }
            }
            for (var i = 0; i < found.length; i++) {
                found[i].parent = cards
            }
            found.push(statsSection)

            // Move the stock "show stats" toggle under 통계 (same control, same pref)
            var toggle = findByText(cards, qsTranslate("SettingsView", "Show performance stats while streaming"))
            if (toggle) {
                toggle.parent = statsColumn
            }
            sections = found
            show(0)
        }
    }

    ListView {
        id: sideList
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        // Sidebar and cards form one block centered in the window
        anchors.leftMargin: Math.max(16, (shell.width - 172 - 20 - 720) / 2)
        anchors.topMargin: 8
        width: 172
        spacing: 2
        model: sections.length
        currentIndex: shell.current
        activeFocusOnTab: true
        keyNavigationEnabled: true
        onCurrentIndexChanged: if (currentIndex !== shell.current) show(currentIndex)

        Keys.onRightPressed: cards.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)

        delegate: ItemDelegate {
            width: sideList.width
            height: 38
            leftPadding: 14
            readonly property bool isCurrent: index === shell.current
            background: Rectangle {
                radius: 8
                color: isCurrent ? Theme.chipHover : (parent.hovered ? Theme.chip : "transparent")
            }
            contentItem: Text {
                text: sectionName(shell.sections[index].title)
                font.pointSize: 13
                color: isCurrent ? Theme.text : Theme.textDim
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: show(index)
        }
    }

    Flickable {
        id: content
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: sideList.right
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: Math.max(16, (shell.width - 172 - 20 - 720) / 2)
        contentHeight: cards.height + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {}

        Column {
            id: cards
            y: 8
            width: Math.min(content.width - 12, 720)
            spacing: 12

            // Our own section; read by StatsPanel in C++ via the same key
            GroupBox {
                id: statsSection
                title: "통계"
                visible: false
                width: parent.width

                // Shortcuts are stored as "<mods>:<SDL scancode>" (mods: 1 Control, 2 Option/Alt,
                // 4 Shift, 8 Command/Win), read by the stream's keyboard handler
                Settings {
                    id: statsSettings
                    property int statsStyle: 1
                    property string statsBinding: "7:22"
                    property string statsStyleBinding: "7:23"
                    property int hangulKey: 110
                }

                // Qt key -> SDL scancode (USB HID usage), for the keys worth binding
                function scancodeFor(event) {
                    var k = event.key
                    if (Qt.platform.os === "osx") {
                        // Left and right modifiers only differ by the Mac virtual key
                        var mac = { 59: 224, 56: 225, 58: 226, 55: 227, 62: 228, 60: 229, 61: 230, 54: 231, 57: 57 }
                        if (mac[event.nativeVirtualKey] !== undefined) return mac[event.nativeVirtualKey]
                    }
                    if (k >= Qt.Key_A && k <= Qt.Key_Z) return 4 + k - Qt.Key_A
                    if (k >= Qt.Key_1 && k <= Qt.Key_9) return 30 + k - Qt.Key_1
                    if (k === Qt.Key_0) return 39
                    if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return 58 + k - Qt.Key_F1
                    if (k >= Qt.Key_F13 && k <= Qt.Key_F24) return 104 + k - Qt.Key_F13
                    var named = {}
                    named[Qt.Key_Return] = 40; named[Qt.Key_Backspace] = 42; named[Qt.Key_Tab] = 43
                    named[Qt.Key_Space] = 44; named[Qt.Key_Minus] = 45; named[Qt.Key_Equal] = 46
                    named[Qt.Key_BracketLeft] = 47; named[Qt.Key_BracketRight] = 48; named[Qt.Key_Backslash] = 49
                    named[Qt.Key_Semicolon] = 51; named[Qt.Key_Apostrophe] = 52; named[Qt.Key_QuoteLeft] = 53
                    named[Qt.Key_Comma] = 54; named[Qt.Key_Period] = 55; named[Qt.Key_Slash] = 56
                    named[Qt.Key_CapsLock] = 57; named[Qt.Key_Insert] = 73; named[Qt.Key_Home] = 74
                    named[Qt.Key_PageUp] = 75; named[Qt.Key_Delete] = 76; named[Qt.Key_End] = 77
                    named[Qt.Key_PageDown] = 78; named[Qt.Key_Right] = 79; named[Qt.Key_Left] = 80
                    named[Qt.Key_Down] = 81; named[Qt.Key_Up] = 82
                    named[Qt.Key_Control] = 224; named[Qt.Key_Shift] = 225; named[Qt.Key_Alt] = 226; named[Qt.Key_Meta] = 227
                    return named[k] !== undefined ? named[k] : -1
                }

                function isModifierScancode(sc) { return sc >= 224 && sc <= 231 }

                function keyName(sc) {
                    var mac = Qt.platform.os === "osx"
                    if (sc >= 4 && sc <= 29) return String.fromCharCode(65 + sc - 4)
                    if (sc >= 30 && sc <= 38) return String(sc - 29)
                    if (sc === 39) return "0"
                    if (sc >= 58 && sc <= 69) return "F" + (sc - 57)
                    if (sc >= 104 && sc <= 115) return "F" + (sc - 91)
                    var n = { 40: "Return", 42: "Backspace", 43: "Tab", 44: "Space", 45: "-", 46: "=", 47: "[", 48: "]",
                              49: "\\", 51: ";", 52: "'", 53: "`", 54: ",", 55: ".", 56: "/", 57: "Caps Lock",
                              73: "Insert", 74: "Home", 75: "Page Up", 76: "Delete", 77: "End", 78: "Page Down",
                              79: "→", 80: "←", 81: "↓", 82: "↑",
                              224: "왼쪽 " + (mac ? "Control" : "Ctrl"), 225: "왼쪽 Shift", 226: "왼쪽 " + (mac ? "Option" : "Alt"),
                              227: "왼쪽 " + (mac ? "Command" : "Win"), 228: "오른쪽 " + (mac ? "Control" : "Ctrl"),
                              229: "오른쪽 Shift", 230: "오른쪽 " + (mac ? "Option" : "Alt"), 231: "오른쪽 " + (mac ? "Command" : "Win") }
                    return n[sc] !== undefined ? n[sc] : "키 " + sc
                }

                function bindingText(binding) {
                    var parts = String(binding).split(":")
                    var mods = parseInt(parts[0]), sc = parseInt(parts[1])
                    var mac = Qt.platform.os === "osx"
                    var s = ""
                    if (mods & 1) s += mac ? "⌃" : "Ctrl + "
                    if (mods & 2) s += mac ? "⌥" : "Alt + "
                    if (mods & 4) s += mac ? "⇧" : "Shift + "
                    if (mods & 8) s += mac ? "⌘" : "Win + "
                    return s + (mac && mods ? " " : "") + keyName(sc)
                }

                // Click, then press the key (with any modifiers); Esc cancels
                component KeyRecorder: Button {
                    id: rec
                    property bool singleKey: false
                    property string value
                    signal recorded(string binding)
                    property bool listening: false
                    width: 200
                    text: listening ? "키를 누르세요" : value
                    onClicked: { listening = true; forceActiveFocus() }
                    onActiveFocusChanged: if (!activeFocus) listening = false
                    Keys.onPressed: (event) => {
                        if (!listening) return
                        event.accepted = true
                        if (event.key === Qt.Key_Escape) { listening = false; return }
                        var sc = statsSection.scancodeFor(event)
                        if (sc < 0) return
                        if (singleKey) { recorded("0:" + sc); listening = false; return }
                        // A shortcut needs a non-modifier key; keep waiting while only modifiers are down
                        if (statsSection.isModifierScancode(sc)) return
                        var m = event.modifiers, mods = 0
                        var mac = Qt.platform.os === "osx"
                        // On macOS Qt reports Command as Control and Control as Meta
                        if (m & (mac ? Qt.MetaModifier : Qt.ControlModifier)) mods |= 1
                        if (m & Qt.AltModifier) mods |= 2
                        if (m & Qt.ShiftModifier) mods |= 4
                        if (m & (mac ? Qt.ControlModifier : Qt.MetaModifier)) mods |= 8
                        recorded(mods + ":" + sc)
                        listening = false
                    }
                }

                Column {
                    id: statsColumn
                    width: parent.width
                    spacing: 6

                Row {
                    width: parent.width
                    spacing: 12

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        text: "통계 모양"
                        font.pointSize: 12
                    }

                    ComboBox {
                        width: 160
                        model: ["기본 글자", "카드", "한 줄 띠"]
                        currentIndex: statsSettings.statsStyle
                        onActivated: statsSettings.statsStyle = currentIndex
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        text: "통계 켜고 끄기"
                        font.pointSize: 12
                    }

                    KeyRecorder {
                        value: statsSection.bindingText(statsSettings.statsBinding)
                        onRecorded: (b) => statsSettings.statsBinding = b
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        text: "카드·한 줄 띠 바꾸기"
                        font.pointSize: 12
                    }

                    KeyRecorder {
                        value: statsSection.bindingText(statsSettings.statsStyleBinding)
                        onRecorded: (b) => statsSettings.statsStyleBinding = b
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        text: "한영 키"
                        font.pointSize: 12
                    }

                    // One key sends the Korean Han/Eng toggle; F19 is what the Karabiner rule sends
                    KeyRecorder {
                        singleKey: true
                        value: statsSection.keyName(statsSettings.hangulKey)
                        onRecorded: (b) => statsSettings.hangulKey = parseInt(b.split(":")[1])
                    }
                }
                }
            }
        }
    }
}
