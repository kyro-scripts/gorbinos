"""Collage stickers: the ransom-note words and halftone bursts that get
slapped onto the screen when things die (FISH x Cruelty Squad: cheap
magazine cut-outs pasted over the action).

  stk_<word>.png    a word made of mismatched cut-out letters, with a white
                    snipped paper border and a hard shadow
  stk_burst_*.png   jagged cut-out bursts with halftone dots

Run: python3 tools/gen_collage.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from texlib import ROOT, font

OUT = os.path.join(ROOT, "assets", "sprites")
FONTS = [("Anton-Regular.ttf", 40), ("Bungee-Regular.ttf", 30), ("Silkscreen-Bold.ttf", 26), ("VT323-Regular.ttf", 44)]
CHIPS = [(250, 30, 130), (255, 230, 20), (20, 200, 255), (30, 30, 30), (250, 245, 230), (120, 255, 60),
         (255, 110, 20), (150, 60, 255), (230, 20, 30), (255, 180, 200)]


def contrast(c):
    return (15, 10, 15) if sum(c) > 380 else (250, 248, 240)


def halftone(img, color, cell=6, rng=None):
    d = ImageDraw.Draw(img)
    w, h = img.size
    for y in range(0, h + cell, cell):
        for x in range(0, w + cell, cell):
            r = cell * 0.36 * (0.6 + 0.4 * ((x * 7 + y * 13) % 5) / 4)
            ox = (y // cell % 2) * cell / 2
            d.ellipse([x + ox - r, y - r, x + ox + r, y + r], fill=color)


def cutout(img, border=5, seed=0):
    """White snipped-paper border round whatever's opaque, plus a hard shadow."""
    r = np.random.default_rng(seed)
    a = np.asarray(img.split()[3]).astype(np.float32) / 255.0
    m = Image.fromarray((a > 0.3).astype(np.uint8) * 255)
    grown = m.filter(ImageFilter.MaxFilter(border * 2 + 1))
    # jag the edge a bit, like scissors
    g = np.asarray(grown).astype(np.float32) / 255.0
    noise = r.random(g.shape) < 0.12
    edge = (g > 0.5) & ~(np.asarray(m) > 0)
    g[edge & noise] = 0
    paper = Image.new("RGBA", img.size, (0, 0, 0, 0))
    paper.paste(Image.new("RGBA", img.size, (248, 244, 230, 255)), mask=Image.fromarray((g * 255).astype(np.uint8)))
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", img.size, (20, 0, 25, 200)), (4, 5), Image.fromarray((g * 255).astype(np.uint8)))
    out = Image.alpha_composite(shadow, paper)
    return Image.alpha_composite(out, img)


def word(text, seed):
    r = np.random.default_rng(seed)
    W, H = 300, 120
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    chips = []
    for k, ch in enumerate(text):
        if ch == " ":
            chips.append(None)
            continue
        fname, fs = FONTS[r.integers(0, len(FONTS))]
        fs = int(fs * r.uniform(0.85, 1.15))
        f = font(fname, fs)
        bg = CHIPS[r.integers(0, len(CHIPS))]
        bb = f.getbbox(ch)
        cw, chh = bb[2] - bb[0] + 10, bb[3] - bb[1] + 10
        chip = Image.new("RGBA", (cw, chh), bg + (255,))
        if r.random() < 0.35:
            halftone(chip, tuple(max(0, c - 60) for c in bg) + (255,), 5)
        ImageDraw.Draw(chip).text((5 - bb[0], 5 - bb[1]), ch, font=f, fill=contrast(bg))
        chip = chip.rotate(r.uniform(-12, 12), resample=Image.BICUBIC, expand=True)
        chips.append(chip)
    total = sum((c.width - 4) if c else 14 for c in chips)
    scale = min(1.0, (W - 30) / max(total, 1))
    x = (W - total * scale) / 2
    for c in chips:
        if c is None:
            x += 14 * scale
            continue
        if scale < 1.0:
            c = c.resize((max(1, int(c.width * scale)), max(1, int(c.height * scale))), Image.BICUBIC)
        y = (H - c.height) / 2 + r.uniform(-6, 6)
        canvas.alpha_composite(c, (int(x), int(y)))
        x += c.width - 4 * scale
    return cutout(canvas, 6, seed)


def burst(seed, col):
    r = np.random.default_rng(seed)
    S = 128
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pts = []
    n = 14
    for k in range(n * 2):
        a = k / (n * 2) * 2 * np.pi
        rad = (S * 0.44 if k % 2 == 0 else S * 0.22) * r.uniform(0.8, 1.1)
        pts.append((S / 2 + np.cos(a) * rad, S / 2 + np.sin(a) * rad))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    fill = Image.new("RGBA", (S, S), col + (255,))
    halftone(fill, tuple(max(0, c - 80) for c in col) + (255,), 7)
    img.paste(fill, mask=mask)
    return cutout(img, 5, seed)


if __name__ == "__main__":
    words = ["SPLORT!", "GORB!", "BLAMMO", "SQUELCH", "BYE BYE", "OOPS", "MEAT!", "LOL", "YUM", "POP!", "DEAD", "WOW"]
    for i, w in enumerate(words):
        name = "stk_" + "".join(ch for ch in w.lower() if ch.isalnum())
        word(w, 500 + i).save(os.path.join(OUT, name + ".png"))
        print("wrote", name)
    for i, c in enumerate([(255, 230, 20), (250, 30, 130), (20, 200, 255)]):
        burst(600 + i, c).save(os.path.join(OUT, "stk_burst_%d.png" % i))
        print("wrote stk_burst_%d" % i)
