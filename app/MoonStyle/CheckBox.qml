import QtQuick
import QtQuick.Controls.Material as M
import Theme 1.0

// Settings toggles read as a row: label on the left, switch on the right
M.CheckBox {
    id: control
    spacing: 12
    topPadding: 10
    bottomPadding: 10
    leftPadding: 4
    rightPadding: 4
    background: Item {}

    indicator: Rectangle {
        implicitWidth: 34
        implicitHeight: 20
        x: control.width - width - control.rightPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        radius: height / 2
        color: control.checked ? Theme.accent : Theme.track
        opacity: control.enabled ? 1 : 0.4
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.focus

        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 2
            x: control.checked ? parent.width - width - 2 : 2
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 120 } }
        }
    }

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? Theme.text : Theme.textMute
        rightPadding: control.indicator.width + control.spacing
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
    }
}
