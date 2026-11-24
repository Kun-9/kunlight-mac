import QtQuick
import QtQuick.Templates as T
import Theme 1.0

// Drawn from scratch: Material's floating placeholder sat on the border
T.TextField {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            placeholder.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    topPadding: 9
    bottomPadding: 9
    leftPadding: 12
    rightPadding: 12
    font.pointSize: 13
    color: Theme.text
    selectionColor: Theme.accent
    selectedTextColor: Theme.onLight
    placeholderTextColor: Theme.textMute
    verticalAlignment: TextInput.AlignVCenter

    Text {
        id: placeholder
        x: control.leftPadding
        y: control.topPadding
        width: control.width - (control.leftPadding + control.rightPadding)
        height: control.height - (control.topPadding + control.bottomPadding)
        text: control.placeholderText
        font: control.font
        color: control.placeholderTextColor
        verticalAlignment: control.verticalAlignment
        elide: Text.ElideRight
        visible: !control.length && !control.preeditText
    }

    background: Rectangle {
        implicitWidth: 240
        implicitHeight: 38
        radius: 8
        color: Theme.chipHover
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.accent
    }
}
