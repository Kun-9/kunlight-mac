#include "mactitlebar.h"

#include <QWindow>

#import <AppKit/AppKit.h>

namespace MacTitlebar {

static void style(QWindow* window)
{
    NSView* view = (__bridge NSView*)reinterpret_cast<void*>(window->winId());
    NSWindow* nsWindow = view.window;
    if (nsWindow == nil || nsWindow.toolbar != nil) {
        return;
    }

    NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"MoonlightTitlebar"];
    toolbar.showsBaselineSeparator = NO;
    nsWindow.toolbar = toolbar;
    nsWindow.toolbarStyle = NSWindowToolbarStyleUnified;
    nsWindow.titleVisibility = NSWindowTitleHidden;
    nsWindow.titlebarAppearsTransparent = YES;
    nsWindow.styleMask |= NSWindowStyleMaskFullSizeContentView;
}

void apply(QWindow* window)
{
    if (window == nullptr) {
        return;
    }
    if (window->isVisible()) {
        style(window);
    }
    // The NSWindow only exists once shown
    QObject::connect(window, &QWindow::visibleChanged, window, [window](bool visible) {
        if (visible) {
            style(window);
        }
    });
}

}
