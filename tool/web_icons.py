"""Draws the web icons (favicon, PWA icons) from the Android launcher design.

The launcher icon (android/app/src/main/res/mipmap-*/ic_launcher.png) is a
maroon circle with a thin gold ring and a cream serif "R". It only exists up
to 192 px, so instead of upscaling it this script redraws the same design at
each size with Pillow, using the app's own Playfair Display font, and
supersamples for clean edges.

Run from the project root:  python tool/web_icons.py
Writes web/favicon.png and web/icons/Icon-{192,512}.png,
web/icons/Icon-maskable-{192,512}.png.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets" / "fonts" / "PlayfairDisplay.ttf"
WEB = ROOT / "web"

# Sampled from the launcher icon.
MAROON = (107, 21, 32, 255)  # #6B1520
GOLD = (203, 168, 110, 255)  # #CBA86E
CREAM = (243, 230, 210, 255)  # #F3E6D2

SUPERSAMPLE = 4


def draw_icon(size: int, maskable: bool = False) -> Image.Image:
    """One icon at [size] px.

    Regular icons match the launcher: a full-bleed circle on a transparent
    square. Maskable icons fill the whole square with maroon and keep the
    ring and letter inside the central safe zone (a circle of 40% of the
    size), so any launcher mask shape crops only plain background.
    """
    s = size * SUPERSAMPLE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2

    if maskable:
        d.rectangle([0, 0, s, s], fill=MAROON)
        radius = s * 0.40  # the "circle" the launcher design lives in
    else:
        radius = s / 2
        d.ellipse([0, 0, s - 1, s - 1], fill=MAROON)

    # Gold ring: centred at 87% of the radius, ~1.3% of the icon wide
    # (never thinner than ~1 px at the final size).
    ring_r = radius * 0.87
    ring_w = max(radius * 2 * 0.013, SUPERSAMPLE * 1.0)
    d.ellipse([c - ring_r - ring_w / 2, c - ring_r - ring_w / 2, c + ring_r + ring_w / 2, c + ring_r + ring_w / 2],
              outline=GOLD, width=round(ring_w))

    # Serif "R", 44% of the circle's diameter tall, optically centred
    # (the leg makes the glyph's box sit a touch right of centre).
    target_h = radius * 2 * 0.44
    probe = ImageFont.truetype(str(FONT), 1000)
    try:
        probe.set_variation_by_axes([500])
    except Exception:
        pass
    l, t, r, b = probe.getbbox("R")
    font_size = max(1, round(1000 * target_h / (b - t)))
    font = ImageFont.truetype(str(FONT), font_size)
    try:
        font.set_variation_by_axes([500])
    except Exception:
        pass
    l, t, r, b = font.getbbox("R")
    gw, gh = r - l, b - t
    cx = c + radius * 2 * 0.01
    cy = c - radius * 2 * 0.005
    d.text((cx - gw / 2 - l, cy - gh / 2 - t), "R", font=font, fill=CREAM)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    (WEB / "icons").mkdir(parents=True, exist_ok=True)
    outputs = {
        WEB / "favicon.png": draw_icon(64),
        WEB / "icons" / "Icon-192.png": draw_icon(192),
        WEB / "icons" / "Icon-512.png": draw_icon(512),
        WEB / "icons" / "Icon-maskable-192.png": draw_icon(192, maskable=True),
        WEB / "icons" / "Icon-maskable-512.png": draw_icon(512, maskable=True),
    }
    for path, img in outputs.items():
        img.save(path, optimize=True)
        print(f"wrote {path.relative_to(ROOT)} ({img.width}x{img.height})")


if __name__ == "__main__":
    main()
