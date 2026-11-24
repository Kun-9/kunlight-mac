#include "statspanel.h"
#include "path.h"

#include <QMutex>
#include <QSettings>
#include <QString>

#include <SDL_ttf.h>

#include <cmath>
#include <cstdio>

namespace {

struct Rgba { Uint8 r, g, b, a; };

const Rgba kPanel   = {10, 12, 17, 184};
const Rgba kText    = {230, 235, 245, 255};
const Rgba kDim     = {154, 166, 192, 255};
const Rgba kMute    = {90, 96, 112, 255};
const Rgba kAccent  = {124, 140, 255, 255};
const Rgba kGrid    = {255, 255, 255, 20};
const Rgba kOk      = {62, 207, 142, 255};
const Rgba kWarn    = {224, 178, 82, 255};
const Rgba kBad     = {235, 87, 87, 255};

const int kHistory = 30;

struct Snapshot {
    bool valid = false;
    double fps = 0;
    unsigned rtt = 0;
    unsigned rttVar = 0;
    double lossPct = 0;
    double jitterDropPct = 0;
    double decodeMs = 0;
    double renderMs = 0;
    double mbps = 0;
    int width = 0;
    int height = 0;
    char codec[16] = {};
    unsigned rttHistory[kHistory] = {};
    int historyCount = 0;
};

QMutex g_Lock;
Snapshot g_Snap;

// Korean-capable system font on macOS; elsewhere the stock overlay font
// with English labels.
const char* kKoreanFontPath = "/System/Library/Fonts/AppleSDGothicNeo.ttc";

struct Fonts {
    TTF_Font* small = nullptr;
    TTF_Font* body = nullptr;
    TTF_Font* big = nullptr;
    bool korean = false;
    QByteArray fallbackData;

    ~Fonts() {
        if (small) TTF_CloseFont(small);
        if (body) TTF_CloseFont(body);
        if (big) TTF_CloseFont(big);
    }
};

int faceIndex(const char* wanted)
{
    // Look the face up by name once; the TTC order is not documented
    static int regular = -2, bold = -2;
    int* slot = strcmp(wanted, "Regular") == 0 ? &regular : &bold;
    if (*slot != -2) {
        return *slot;
    }
    *slot = 0;
    for (int i = 0; i < 16; i++) {
        TTF_Font* f = TTF_OpenFontIndex(kKoreanFontPath, 12, i);
        if (!f) {
            break;
        }
        const char* name = TTF_FontFaceStyleName(f);
        bool hit = name && strcmp(name, wanted) == 0;
        TTF_CloseFont(f);
        if (hit) {
            *slot = i;
            break;
        }
    }
    return *slot;
}

bool openFonts(Fonts& fonts, int k)
{
    if (TTF_WasInit() == 0) {
        return false;
    }

    fonts.small = TTF_OpenFontIndex(kKoreanFontPath, 11 * k, faceIndex("Regular"));
    fonts.body = TTF_OpenFontIndex(kKoreanFontPath, 12 * k, faceIndex("Regular"));
    fonts.big = TTF_OpenFontIndex(kKoreanFontPath, 22 * k, faceIndex("SemiBold"));
    if (fonts.small && fonts.body && fonts.big) {
        fonts.korean = true;
        return true;
    }

    if (fonts.small) { TTF_CloseFont(fonts.small); fonts.small = nullptr; }
    if (fonts.body) { TTF_CloseFont(fonts.body); fonts.body = nullptr; }
    if (fonts.big) { TTF_CloseFont(fonts.big); fonts.big = nullptr; }

    fonts.fallbackData = Path::readDataFile("ModeSeven.ttf");
    if (fonts.fallbackData.isEmpty()) {
        return false;
    }
    auto open = [&](int size) {
        return TTF_OpenFontRW(SDL_RWFromConstMem(fonts.fallbackData.constData(), fonts.fallbackData.size()), 1, size);
    };
    fonts.small = open(10 * k);
    fonts.body = open(11 * k);
    fonts.big = open(20 * k);
    return fonts.small && fonts.body && fonts.big;
}

// ---- pixel drawing on an ARGB8888 surface ----

void blendPixel(SDL_Surface* s, int x, int y, Rgba c, float coverage)
{
    if (x < 0 || y < 0 || x >= s->w || y >= s->h || coverage <= 0) {
        return;
    }
    Uint32* p = (Uint32*)((Uint8*)s->pixels + y * s->pitch) + x;
    float sa = (c.a / 255.0f) * SDL_min(coverage, 1.0f);
    float da = ((*p >> 24) & 0xFF) / 255.0f;
    float oa = sa + da * (1 - sa);
    if (oa <= 0) {
        return;
    }
    auto ch = [&](int shift, Uint8 sc) {
        float dc = ((*p >> shift) & 0xFF) / 255.0f;
        return (Uint32)SDL_clamp((int)(((sc / 255.0f) * sa + dc * da * (1 - sa)) / oa * 255.0f + 0.5f), 0, 255);
    };
    *p = ((Uint32)(oa * 255.0f + 0.5f) << 24) | (ch(16, c.r) << 16) | (ch(8, c.g) << 8) | ch(0, c.b);
}

void fillRoundRect(SDL_Surface* s, int x0, int y0, int w, int h, int radius, Rgba c)
{
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            // Distance outside the rounded corner, for a soft 1px edge
            float cx = x < radius ? radius - x - 0.5f : (x >= w - radius ? x - (w - radius) + 0.5f : 0);
            float cy = y < radius ? radius - y - 0.5f : (y >= h - radius ? y - (h - radius) + 0.5f : 0);
            float cov = 1.0f;
            if (cx > 0 && cy > 0) {
                cov = radius + 0.5f - std::sqrt(cx * cx + cy * cy);
            }
            blendPixel(s, x0 + x, y0 + y, c, cov);
        }
    }
}

void fillCircle(SDL_Surface* s, float cx, float cy, float r, Rgba c)
{
    for (int y = (int)(cy - r - 1); y <= (int)(cy + r + 1); y++) {
        for (int x = (int)(cx - r - 1); x <= (int)(cx + r + 1); x++) {
            float d = std::sqrt((x + 0.5f - cx) * (x + 0.5f - cx) + (y + 0.5f - cy) * (y + 0.5f - cy));
            blendPixel(s, x, y, c, r + 0.5f - d);
        }
    }
}

void drawLine(SDL_Surface* s, float x0, float y0, float x1, float y1, float width, Rgba c)
{
    float len = std::sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
    int steps = SDL_max(1, (int)(len * 2));
    for (int i = 0; i <= steps; i++) {
        float t = (float)i / steps;
        fillCircle(s, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, width / 2, c);
    }
}

int textWidth(TTF_Font* f, const QString& text)
{
    int w = 0, h = 0;
    TTF_SizeUTF8(f, text.toUtf8().constData(), &w, &h);
    return w;
}

// Returns the drawn width
int drawText(SDL_Surface* s, TTF_Font* f, const QString& text, int x, int y, Rgba c)
{
    SDL_Surface* t = TTF_RenderUTF8_Blended(f, text.toUtf8().constData(), {c.r, c.g, c.b, c.a});
    if (!t) {
        return 0;
    }
    SDL_SetSurfaceBlendMode(t, SDL_BLENDMODE_BLEND);
    SDL_Rect dst = {x, y, t->w, t->h};
    SDL_BlitSurface(t, nullptr, s, &dst);
    int w = t->w;
    SDL_FreeSurface(t);
    return w;
}

int drawTextRight(SDL_Surface* s, TTF_Font* f, const QString& text, int right, int y, Rgba c)
{
    return drawText(s, f, text, right - textWidth(f, text), y, c);
}

SDL_Surface* newSurface(int w, int h)
{
    SDL_Surface* s = SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL_PIXELFORMAT_ARGB8888);
    if (s) {
        SDL_FillRect(s, nullptr, 0);
    }
    return s;
}

// ---- content ----

enum Health { Good, Fair, Poor };

Health health(const Snapshot& s)
{
    if (s.lossPct >= 5 || s.rtt >= 80) return Poor;
    if (s.lossPct >= 1 || s.rtt >= 40 || s.jitterDropPct >= 2) return Fair;
    return Good;
}

Rgba healthColor(Health h)
{
    return h == Good ? kOk : (h == Fair ? kWarn : kBad);
}

QString healthText(Health h, bool korean)
{
    if (korean) {
        return h == Good ? "연결 좋음" : (h == Fair ? "연결 보통" : "연결 나쁨");
    }
    return h == Good ? "Good" : (h == Fair ? "Fair" : "Poor");
}

QString ms(double v) { return QString::number(v, 'f', v < 10 ? 1 : 0) + " ms"; }
QString pct(double v) { return QString::number(v, 'f', 2) + "%"; }

SDL_Surface* renderCard(const Snapshot& snap, const Fonts& f, int k)
{
    const bool ko = f.korean;
    const int margin = 14 * k, pad = 14 * k, w = 250 * k;
    const int rowH = 20 * k, rows = 5;
    const int sparkY = 92 * k, sparkH = 30 * k;
    const int rowsY = sparkY + sparkH + 10 * k;
    const int h = rowsY + rows * rowH + pad - 4 * k;

    SDL_Surface* s = newSurface(margin + w, margin + h);
    if (!s) {
        return nullptr;
    }
    const int x0 = margin, y0 = margin, right = x0 + w - pad;
    fillRoundRect(s, x0, y0, w, h, 12 * k, kPanel);

    // Header: status dot and text, codec and resolution on the right
    Health hl = health(snap);
    int hy = y0 + pad;
    fillCircle(s, x0 + pad + 3.5f * k, hy + 7.5f * k, 3.5f * k, healthColor(hl));
    drawText(s, f.body, healthText(hl, ko), x0 + pad + 13 * k, hy, kDim);
    QString spec = QString("%1 · %2x%3").arg(snap.codec).arg(snap.width).arg(snap.height);
    drawTextRight(s, f.small, spec, right, hy + 1 * k, kDim);

    // Two big numbers
    int by = y0 + 40 * k;
    int col2 = x0 + pad + (w - 2 * pad) / 2;
    drawText(s, f.small, ko ? "프레임" : "FPS", x0 + pad, by, kDim);
    drawText(s, f.small, ko ? "네트워크 지연" : "Latency", col2, by, kDim);
    int nw = drawText(s, f.big, QString::number(qRound(snap.fps)), x0 + pad, by + 14 * k, kText);
    drawText(s, f.small, "fps", x0 + pad + nw + 4 * k, by + 24 * k, kDim);
    nw = drawText(s, f.big, QString::number(snap.rtt), col2, by + 14 * k, kText);
    drawText(s, f.small, "ms", col2 + nw + 4 * k, by + 24 * k, kDim);

    // Latency sparkline over the last ~30 seconds
    int sx0 = x0 + pad, sx1 = right, sy = y0 + sparkY;
    drawLine(s, sx0, sy + sparkH - 1, sx1, sy + sparkH - 1, 1.0f * k, kGrid);
    if (snap.historyCount > 1) {
        unsigned maxV = 20;
        for (int i = 0; i < snap.historyCount; i++) maxV = SDL_max(maxV, snap.rttHistory[i]);
        float step = (float)(sx1 - sx0) / (kHistory - 1);
        int start = kHistory - snap.historyCount;
        for (int i = 1; i < snap.historyCount; i++) {
            float ya = sy + sparkH - 2 - (float)snap.rttHistory[i - 1] / maxV * (sparkH - 4);
            float yb = sy + sparkH - 2 - (float)snap.rttHistory[i] / maxV * (sparkH - 4);
            drawLine(s, sx0 + (start + i - 1) * step, ya, sx0 + (start + i) * step, yb, 1.6f * k, kAccent);
        }
    }

    // Detail rows
    struct { const char* ko; const char* en; QString value; } items[rows] = {
        {"떨어진 프레임", "Dropped frames", pct(snap.lossPct + snap.jitterDropPct)},
        {"흔들림", "Jitter", QString::number(snap.rttVar) + " ms"},
        {"디코딩", "Decode", ms(snap.decodeMs)},
        {"화면 출력", "Render", ms(snap.renderMs)},
        {"비트레이트", "Bitrate", QString::number(snap.mbps, 'f', 1) + " Mbps"},
    };
    for (int i = 0; i < rows; i++) {
        int ry = y0 + rowsY + i * rowH;
        drawText(s, f.body, ko ? items[i].ko : items[i].en, x0 + pad, ry, kDim);
        drawTextRight(s, f.body, items[i].value, right, ry, kText);
    }
    return s;
}

SDL_Surface* renderStrip(const Snapshot& snap, const Fonts& f, int k, int areaWidth)
{
    const bool ko = f.korean;
    const int pad = 16 * k, gap = 16 * k, h = 30 * k, top = 12 * k;
    Health hl = health(snap);

    struct Item { QString label; QString value; };
    Item items[] = {
        {ko ? "프레임" : "FPS", QString::number(qRound(snap.fps))},
        {ko ? "지연" : "Latency", QString::number(snap.rtt) + " ms"},
        {ko ? "손실" : "Loss", QString::number(snap.lossPct + snap.jitterDropPct, 'f', snap.lossPct + snap.jitterDropPct < 1 ? 1 : 0) + "%"},
        {ko ? "디코딩" : "Decode", ms(snap.decodeMs)},
    };
    const int labelGap = 5 * k;

    int w = pad + 13 * k + textWidth(f.body, healthText(hl, ko));
    for (const Item& it : items) {
        w += gap + textWidth(f.body, it.label) + labelGap + textWidth(f.body, it.value);
    }
    w += pad;

    int left = areaWidth > w ? (areaWidth - w) / 2 : 12 * k;
    SDL_Surface* s = newSurface(left + w, top + h);
    if (!s) {
        return nullptr;
    }
    fillRoundRect(s, left, top, w, h, h / 2, kPanel);

    int ty = top + (h - TTF_FontHeight(f.body)) / 2;
    int x = left + pad;
    fillCircle(s, x + 3.5f * k, top + h / 2.0f, 3.5f * k, healthColor(hl));
    x += 13 * k;
    x += drawText(s, f.body, healthText(hl, ko), x, ty, kDim);
    for (const Item& it : items) {
        x += gap;
        x += drawText(s, f.body, it.label, x, ty, kDim) + labelGap;
        x += drawText(s, f.body, it.value, x, ty, kText);
    }
    return s;
}

}

namespace StatsPanel {

int style()
{
    return QSettings().value("statsStyle", StyleCard).toInt();
}

void update(const VIDEO_STATS& st, const char* headerText)
{
    QMutexLocker lock(&g_Lock);
    Snapshot& s = g_Snap;
    s.valid = st.renderedFrames != 0;
    s.fps = st.renderedFps;
    s.rtt = st.lastRtt;
    s.rttVar = st.lastRttVariance;
    s.lossPct = st.totalFrames ? (double)st.networkDroppedFrames / st.totalFrames * 100 : 0;
    s.jitterDropPct = st.decodedFrames ? (double)st.pacerDroppedFrames / st.decodedFrames * 100 : 0;
    s.decodeMs = st.decodedFrames ? (st.totalDecodeTimeUs / 1000.0) / st.decodedFrames : 0;
    s.renderMs = st.renderedFrames ? (st.totalRenderTimeUs / 1000.0) / st.renderedFrames : 0;
    s.mbps = st.videoMegabitsPerSec;

    double ignoredFps;
    if (headerText == nullptr ||
            sscanf(headerText, "Video stream: %dx%d %lf FPS (Codec: %15[^)])", &s.width, &s.height, &ignoredFps, s.codec) != 4) {
        s.codec[0] = '\0';
    }

    if (st.lastRtt != 0) {
        if (s.historyCount == kHistory) {
            memmove(s.rttHistory, s.rttHistory + 1, sizeof(unsigned) * (kHistory - 1));
            s.historyCount--;
        }
        s.rttHistory[s.historyCount++] = st.lastRtt;
    }
}

SDL_Surface* render()
{
    Snapshot snap;
    {
        QMutexLocker lock(&g_Lock);
        snap = g_Snap;
    }
    if (!snap.valid) {
        return nullptr;
    }

    // shortcut: assumes a 2x (Retina) drawable on macOS and 1x elsewhere,
    // since the overlay is drawn in drawable pixels; read the real scale if
    // this runs on non-Retina screens.
#ifdef Q_OS_DARWIN
    const int k = 2;
#else
    const int k = 1;
#endif

    Fonts fonts;
    if (!openFonts(fonts, k)) {
        return nullptr;
    }

    if (style() == StyleStrip) {
        int winW = 0, winH = 0;
        if (SDL_Window* win = SDL_GetKeyboardFocus()) {
            SDL_GetWindowSize(win, &winW, &winH);
        }
        return renderStrip(snap, fonts, k, winW * k);
    }
    return renderCard(snap, fonts, k);
}

}
