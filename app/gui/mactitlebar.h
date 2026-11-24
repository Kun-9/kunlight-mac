#pragma once

class QWindow;

// Personal build: gives the main window a tall unified title bar (an empty
// NSToolbar) so the traffic lights sit centered in a ~52px row that the QML
// top bar shares.
namespace MacTitlebar {
void apply(QWindow* window);
}
