#!/usr/bin/env python3
"""Generate Scrabble-tile PWA icons into web/icons and web/favicon.png."""
from PIL import Image, ImageDraw, ImageFont

GREEN = (27, 94, 32, 255)        # #1B5E20 board green
CREAM_TOP = (246, 226, 179, 255) # tile gloss top
CREAM = (233, 200, 131, 255)     # tile body
BORDER = (181, 150, 90, 255)     # tile border
INK = (58, 46, 20, 255)          # letter color
INK2 = (90, 74, 34, 255)         # value color
BADGE = (198, 40, 40, 255)       # offline badge red
WHITE = (255, 255, 255, 255)
FONT = "assets/fonts/Roboto-Variable.ttf"


def rounded(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_offline_badge(d, cx, cy, r):
    """A round 'no Wi-Fi' badge asserting the offline build."""
    # Badge disc with a soft shadow + white ring.
    d.ellipse((cx - r + r * 0.08, cy - r + r * 0.10,
               cx + r + r * 0.08, cy + r + r * 0.10), fill=(0, 0, 0, 80))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=BADGE,
              outline=WHITE, width=max(2, int(r * 0.12)))

    # Wi-Fi fan (dot + arcs) pointing up.
    base_y = cy + r * 0.40
    w = max(2, int(r * 0.13))
    dot = r * 0.11
    d.ellipse((cx - dot, base_y - dot, cx + dot, base_y + dot), fill=WHITE)
    for rad in (r * 0.34, r * 0.56, r * 0.78):
        d.arc((cx - rad, base_y - rad, cx + rad, base_y + rad),
              start=218, end=322, fill=WHITE, width=w)

    # Diagonal slash = "no signal".
    sl = r * 0.72
    d.line((cx - sl, cy - sl, cx + sl, cy + sl), fill=WHITE,
           width=max(3, int(r * 0.18)))


def make_icon(size, tile_frac, bg=True):
    img = Image.new("RGBA", (size, size), GREEN if bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    t = int(size * tile_frac)
    x0 = (size - t) // 2
    y0 = (size - t) // 2
    x1, y1 = x0 + t, y0 + t
    r = int(t * 0.16)

    # Soft drop shadow.
    sh = int(t * 0.05)
    rounded(d, (x0 + sh, y0 + sh, x1 + sh, y1 + sh), r, (0, 0, 0, 90))

    # Tile body + border.
    rounded(d, (x0, y0, x1, y1), r, CREAM, outline=BORDER, width=max(2, t // 40))

    # Top gloss highlight (upper ~45%).
    gloss = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gh = int(t * 0.46)
    gd.rounded_rectangle((x0, y0, x1, y0 + gh), radius=r, fill=(255, 255, 255, 70))
    img = Image.alpha_composite(img, gloss)
    d = ImageDraw.Draw(img)

    # Letter "S" (shifted down-left to make room for the offline badge).
    letter_font = ImageFont.truetype(FONT, int(t * 0.52))
    d.text((x0 + t * 0.40, y0 + t * 0.54), "S", font=letter_font, fill=INK,
           anchor="mm")

    # Value "1" bottom-right.
    val_font = ImageFont.truetype(FONT, int(t * 0.2))
    d.text((x1 - t * 0.12, y1 - t * 0.10), "1", font=val_font, fill=INK2,
           anchor="mm")

    # Offline badge, upper-right, kept inside the tile (safe for masking).
    draw_offline_badge(d, x0 + t * 0.74, y0 + t * 0.26, t * 0.20)
    return img


def main():
    # Standard icons: tile fills most of the canvas.
    make_icon(192, 0.78).save("web/icons/Icon-192.png")
    make_icon(512, 0.78).save("web/icons/Icon-512.png")
    # Maskable: keep the tile inside the safe zone (~60%).
    make_icon(192, 0.60).save("web/icons/Icon-maskable-192.png")
    make_icon(512, 0.60).save("web/icons/Icon-maskable-512.png")
    # Favicon.
    make_icon(64, 0.82).save("web/favicon.png")
    print("icons written")


if __name__ == "__main__":
    main()
