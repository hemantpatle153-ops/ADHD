"""Draws the Brightday app icon and Play Store graphics.

Run: python3 tool/make_icons.py   (needs Pillow)
Then: dart run flutter_launcher_icons
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 4  # supersampling

BG_TOP = (246, 168, 112)
BG_BOTTOM = (232, 120, 82)
SUN = (255, 248, 236)
BARS = [(201, 228, 197), (191, 221, 245), (226, 209, 247)]


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(BG_TOP[i] * (1 - t) + BG_BOTTOM[i] * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    return img


def draw_mark(d, cx, cy, size):
    """Rising sun over three timeline bars. size = width of the mark."""
    r = size * 0.22
    sun_cy = cy - size * 0.08
    # rays
    for i in range(7):
        a = math.pi + i * math.pi / 6
        x1 = cx + math.cos(a) * r * 1.35
        y1 = sun_cy + math.sin(a) * r * 1.35
        x2 = cx + math.cos(a) * r * 1.75
        y2 = sun_cy + math.sin(a) * r * 1.75
        d.line([(x1, y1), (x2, y2)], fill=SUN, width=int(size * 0.045))
        for (x, y) in ((x1, y1), (x2, y2)):
            rr = size * 0.0225
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=SUN)
    # half sun
    d.pieslice([cx - r, sun_cy - r, cx + r, sun_cy + r], 180, 360, fill=SUN)
    # bars (timeline blocks)
    bar_h = size * 0.11
    gap = size * 0.05
    widths = [0.86, 0.62, 0.74]
    y = sun_cy + gap
    for i, w in enumerate(widths):
        x0 = cx - size * 0.43
        d.rounded_rectangle([x0, y, x0 + size * w, y + bar_h], radius=bar_h / 2, fill=BARS[i])
        y += bar_h + gap * 0.8


def app_icon(px=1024):
    w = px * S
    img = gradient(w, w)
    d = ImageDraw.Draw(img)
    draw_mark(d, w / 2, w / 2, w * 0.62)
    return img.resize((px, px), Image.LANCZOS)


def adaptive_foreground(px=1024):
    # flutter_launcher_icons adds a 16% inset, which keeps this in the safe zone.
    w = px * S
    img = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_mark(d, w / 2, w * 0.53, w * 0.68)
    return img.resize((px, px), Image.LANCZOS)


def feature_graphic():
    W, H = 1024 * S, 500 * S
    img = gradient(W, H)
    d = ImageDraw.Draw(img)
    draw_mark(d, W * 0.2, H * 0.52, H * 0.62)
    bold = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 88 * S)
    reg = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 38 * S)
    d.text((W * 0.4, H * 0.30), "Brightday", font=bold, fill=SUN)
    d.text((W * 0.4, H * 0.55), "A visual day planner", font=reg, fill=SUN)
    d.text((W * 0.4, H * 0.66), "for ADHD brains", font=reg, fill=SUN)
    return img.resize((1024, 500), Image.LANCZOS)


if __name__ == "__main__":
    app_icon().save(f"{ROOT}/assets/icon/icon.png")
    adaptive_foreground().save(f"{ROOT}/assets/icon/foreground.png")
    app_icon(512).save(f"{ROOT}/store/icon-512.png")
    feature_graphic().save(f"{ROOT}/store/feature-graphic-1024x500.png")
    print("ok")
