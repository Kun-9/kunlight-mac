import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Material as M

M.DialogButtonBox {
    alignment: Qt.AlignRight
    spacing: 8
    leftPadding: 22
    rightPadding: 22
    topPadding: 2
    bottomPadding: 20
    background: Item {}
    delegate: Button {}

    // The confirming button (OK/Yes/Save) is the white one
    function markPrimary() {
        var roles = [T.Dialog.Ok, T.Dialog.Yes, T.Dialog.Save, T.Dialog.Apply]
        for (var i = 0; i < roles.length; i++) {
            var b = standardButton(roles[i])
            if (b && b.primary !== undefined) {
                b.primary = true
                return
            }
        }
    }
    onCountChanged: Qt.callLater(markPrimary)
    Component.onCompleted: Qt.callLater(markPrimary)
}
