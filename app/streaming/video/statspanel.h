#pragma once

#include "decoder.h"

// Personal build: draws the performance overlay (Ctrl+Alt+Shift+S) as a card
// or a one-line strip instead of the stock yellow text. The look is picked in
// Settings > 통계 and stored under the "statsStyle" key.
namespace StatsPanel {

enum Style {
    StyleText = 0,
    StyleCard = 1,
    StyleStrip = 2,
};

// Current style from settings
int style();

// Feed the latest one-second stats; headerText is the stock overlay text,
// whose first line names the resolution and codec.
void update(const VIDEO_STATS& stats, const char* headerText);

// Builds the overlay surface for the current style, or nullptr on failure
// (the caller then falls back to the stock text).
SDL_Surface* render();

}
