#!/usr/bin/env python3
"""Generate the app / PWA icon set from a single source image.

Source: tool/icon_source.png (a square, e.g. 1024x1024 artwork that sits on a
white field). Standard ("any") icons use the full image. Maskable icons scale
the art into the Android safe zone on a matching white background so platform
masking never crops important content (the "OFFLINE" text or the offline badge).

Outputs: web/icons/Icon-{192,512}.png, web/icons/Icon-maskable-{192,512}.png,
and web/favicon.png. Re-run after replacing tool/icon_source.png.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tool", "icon_source.png")
ICONS = os.path.join(ROOT, "web", "icons")
FAVICON = os.path.join(ROOT, "web", "favicon.png")

# The artwork sits on white, so extend white for maskable padding (seamless).
MASK_BG = (255, 255, 255, 255)
# Fraction of the canvas the art occupies inside the maskable safe zone.
SAFE = 0.80


def _load():
    return Image.open(SRC).convert("RGBA")


def standard(size):
    return _load().resize((size, size), Image.LANCZOS)


def maskable(size):
    canvas = Image.new("RGBA", (size, size), MASK_BG)
    inner = int(size * SAFE)
    art = _load().resize((inner, inner), Image.LANCZOS)
    off = (size - inner) // 2
    canvas.alpha_composite(art, (off, off))
    return canvas


def main():
    os.makedirs(ICONS, exist_ok=True)
    standard(192).save(os.path.join(ICONS, "Icon-192.png"))
    standard(512).save(os.path.join(ICONS, "Icon-512.png"))
    maskable(192).save(os.path.join(ICONS, "Icon-maskable-192.png"))
    maskable(512).save(os.path.join(ICONS, "Icon-maskable-512.png"))
    standard(64).save(FAVICON)
    print("Icons written from", SRC)


if __name__ == "__main__":
    main()
