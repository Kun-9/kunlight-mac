import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Material as M
import Theme 1.0

M.Dialog {
    id: control
    padding: 22
    topPadding: 22
    bottomPadding: 14
    implicitWidth: Math.max(340, implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding,
                            implicitHeaderWidth, implicitFooterWidth)

    background: Rectangle {
        radius: 14
        color: Theme.surface
    }

    // Our button row (Material's own has a separate tinted band)
    footer: DialogButtonBox {
        visible: count > 0
    }

    T.Overlay.modal: Rectangle {
        color: "#b3050609"
    }
}
