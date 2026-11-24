import QtQuick
import QtQuick.Controls.Material as M
import Theme 1.0

M.Button {
    id: control
    topInset: 0
    bottomInset: 0
    leftPadding: 14
    rightPadding: 14
    topPadding: 7
    bottomPadding: 7
    // Set by our DialogButtonBox on the confirming button. Not "highlighted",
    // which the dialog resets when it opens.
    property bool primary: false
    readonly property bool filled: control.highlighted || control.primary
    M.Material.foreground: control.filled ? Theme.onLight : Theme.text

    background: Rectangle {
        implicitWidth: 64
        implicitHeight: 32
        radius: 8
        color: control.filled ? Theme.focus : (control.hovered || control.down ? Theme.chipHover : Theme.chip)
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.accent
    }
}
