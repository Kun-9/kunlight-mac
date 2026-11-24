import QtQuick
import QtQuick.Controls.Material as M
import Theme 1.0

// Plain card; the section name lives in the settings sidebar instead
M.GroupBox {
    id: control
    padding: 18
    label: Item {}

    background: Rectangle {
        x: 0
        y: 0
        width: control.width
        height: control.height
        radius: 12
        color: Theme.card
    }
}
