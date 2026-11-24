import QtQuick
import QtQuick.Controls.Material as M
import Theme 1.0

M.ComboBox {
    id: control
    topInset: 0
    bottomInset: 0
    implicitHeight: 34
    M.Material.elevation: 0

    background: Rectangle {
        implicitWidth: 120
        implicitHeight: 34
        radius: 8
        color: control.hovered || control.pressed ? Theme.chipHover : Theme.chip
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.focus
    }

    // Wrapped in an Item: AutoResizingComboBox assigns popup.background.color
    // on Material 3, and an Item quietly ignores that.
    popup.background: Item {
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.surfaceHigh
        }
    }
}
