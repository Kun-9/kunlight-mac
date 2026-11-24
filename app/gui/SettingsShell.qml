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

                Settings {
                    id: statsSettings
                    property int statsStyle: 1
                    property string statsKey: "S"
                    property string statsStyleKey: "T"
                    property int hangulKey: 110
                }

                // Ctrl+Option+Shift + one letter; letters other shortcuts use are left out
                readonly property var freeLetters: "ABFGHIJNOPRSTUWY".split("")

                Column {
                    id: statsColumn
                    width: parent.width
                    spacing: 6

                Row {
                    width: parent.width
                    spacing: 12

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
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
                        text: "한영 키"
                        font.pointSize: 12
                    }

                    // SDL scancodes; F19 is what the Karabiner rule sends
                    ComboBox {
                        id: hangulBox
                        width: 220
                        readonly property var codes: [110, 230, 231, 228, 57]
                        model: ["F19 (Karabiner 한영 키)", "오른쪽 Option", "오른쪽 Command", "오른쪽 Control", "Caps Lock"]
                        currentIndex: Math.max(0, codes.indexOf(statsSettings.hangulKey))
                        onActivated: statsSettings.hangulKey = codes[currentIndex]
                    }
                }

                Repeater {
                    model: [
                        { label: "통계 켜고 끄기", key: "statsKey" },
                        { label: "카드·한 줄 띠 바꾸기", key: "statsStyleKey" }
                    ]

                    Row {
                        width: parent.width
                        spacing: 12

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 150
                            text: modelData.label
                            font.pointSize: 12
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.platform.os === "osx" ? "⌃ ⌥ ⇧ +" : "Ctrl + Alt + Shift +"
                            font.pointSize: 12
                            opacity: 0.7
                        }

                        ComboBox {
                            width: 80
                            model: statsSection.freeLetters
                            currentIndex: Math.max(0, model.indexOf(statsSettings[modelData.key]))
                            onActivated: statsSettings[modelData.key] = model[currentIndex]
                        }
                    }
                }
                }
            }
        }
    }
}
