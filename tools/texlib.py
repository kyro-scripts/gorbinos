"""Shared helpers for Gorbino's Quest procedural art generation.

Everything here is deterministic (seeded) so re-running the generators
produces identical assets.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_DIR = os.path.join(ROOT, "assets", "fonts")


def rng(seed):
    return np.random.default_rng(seed)


# ---------------------------------------------------------------- palette
def _ramp(c0, c1, n):
    c0 = np.array(c0, float)
    c1 = np.array(c1, float)
    return [tuple((c0 + (c1 - c0) * (i / (n - 1))).astype(int)) for i in range(n)]


def build_palette():
    """GORBPAL: the 256 colour palette every texture is quantised to."""
    ramps = [
        ((8, 8, 10), (244, 240, 230), 24),      # greys
        ((20, 6, 4), (255, 214, 190), 16),      # flesh
        ((40, 0, 8), (255, 40, 60), 16),        # red
        ((40, 14, 0), (255, 160, 40), 16),      # orange
        ((36, 30, 0), (255, 240, 80), 16),      # yellow / ochre
        ((10, 30, 0), (190, 255, 40), 16),      # acid lime
        ((0, 20, 8), (60, 230, 120), 16),       # green
        ((0, 24, 26), (80, 240, 220), 16),      # teal / cyan
        ((4, 8, 40), (120, 170, 255), 16),      # blue
        ((20, 0, 40), (200, 120, 255), 16),     # violet
        ((40, 0, 30), (255, 90, 230), 16),      # magenta
        ((30, 16, 6), (200, 150, 100), 16),     # brown
        ((20, 22, 6), (170, 180, 90), 16),      # olive
        ((30, 20, 30), (230, 200, 220), 16),    # mauve / pastel
        ((10, 20, 30), (200, 230, 230), 16),    # cold steel
        ((255, 255, 255), (255, 255, 255), 8),  # (padding)
    ]
    pal = []
    for a, b, n in ramps:
        pal += _ramp(a, b, n)
    pal = pal[:256]
    while len(pal) < 256:
        pal.append((0, 0, 0))
    return pal


PALETTE = build_palette()
_PAL_IMG = Image.new("P", (1, 1))
_PAL_IMG.putpalette([c for rgb in PALETTE for c in rgb])


def quantize(arr, dither=True):
    """Quantise float [0..1] or uint8 HxWx3 array to GORBPAL with dithering."""
    if arr.dtype != np.uint8:
        arr = (np.clip(arr, 0, 1) * 255).astype(np.uint8)
    im = Image.fromarray(arr[:, :, :3], "RGB")
    q = im.quantize(palette=_PAL_IMG, dither=Image.Dither.FLOYDSTEINBERG if dither else Image.Dither.NONE)
    return np.asarray(q.convert("RGB")).astype(np.float32) / 255.0


# ---------------------------------------------------------------- noise
def value_noise(size, cells, seed, octaves=4, persistence=0.5):
    """Tileable fractal value noise in [0,1], shape (size,size)."""
    r = rng(seed)
    out = np.zeros((size, size), np.float32)
    amp = 1.0
    total = 0.0
    c = cells
    for _ in range(octaves):
        grid = r.random((c, c)).astype(np.float32)
        # bilinear wrap-upsample
        coords = np.arange(size) * (c / size)
        i0 = np.floor(coords).astype(int) % c
        i1 = (i0 + 1) % c
        f = coords - np.floor(coords)
        f = f * f * (3 - 2 * f)
        a = grid[i0][:, i0] * (1 - f)[None, :] + grid[i0][:, i1] * f[None, :]
        b = grid[i1][:, i0] * (1 - f)[None, :] + grid[i1][:, i1] * f[None, :]
        layer = a * (1 - f)[:, None] + b * f[:, None]
        out += layer * amp
        total += amp
        amp *= persistence
        c = min(c * 2, size)
    return out / total


def white(size, seed, h=None):
    r = rng(seed)
    return r.random((h or size, size)).astype(np.float32)


def worley(size, n, seed):
    """Tileable worley (cellular) noise: returns (dist1, dist2, cell_id)."""
    r = rng(seed)
    pts = r.random((n, 2)) * size
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    d1 = np.full((size, size), 1e9, np.float32)
    d2 = np.full((size, size), 1e9, np.float32)
    ids = np.zeros((size, size), int)
    for i, (px, py) in enumerate(pts):
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d = np.hypot(xx - (px + ox), yy - (py + oy))
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                ids = np.where(closer, i, ids)
                d1 = np.where(closer, d, d1)
    return d1, d2, ids


def col(*c):
    return np.array(c, np.float32) / 255.0


def lerp(a, b, t):
    t = np.asarray(t, np.float32)
    if t.ndim == 2:
        t = t[:, :, None]
    return a + (b - a) * t


def gradmap(t, stops):
    """Map scalar field t in [0,1] through colour stops [(pos,(r,g,b)),...]."""
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,), np.float32)
    for (p0, c0), (p1, c1) in zip(stops[:-1], stops[1:]):
        m = (t >= p0) & (t <= p1)
        k = ((t - p0) / max(p1 - p0, 1e-6))[..., None]
        out = np.where(m[..., None], col(*c0) + (col(*c1) - col(*c0)) * k, out)
    return out


def shade(img, amount):
    """Multiply brightness by field (H,W)."""
    return np.clip(img * amount[..., None], 0, 1)


def bevel_rect(img, x0, y0, x1, y1, light=0.25, dark=0.3, w=1):
    """Draw a raised bevel on a rectangle region (inclusive-exclusive)."""
    img[y0:y0 + w, x0:x1] = np.clip(img[y0:y0 + w, x0:x1] + light, 0, 1)
    img[y0:y1, x0:x0 + w] = np.clip(img[y0:y1, x0:x0 + w] + light, 0, 1)
    img[y1 - w:y1, x0:x1] *= (1 - dark)
    img[y0:y1, x1 - w:x1] *= (1 - dark)


def to_image(arr, q=True, dither=True):
    if q:
        arr = quantize(arr, dither)
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGB")


def font(name, size):
    return ImageFont.truetype(os.path.join(FONT_DIR, name), size)


def text_layer(size_wh, text, fnt, fill=255, anchor_xy=None, spacing=0):
    """Render text into a float mask (H,W)."""
    w, h = size_wh
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    if anchor_xy is None:
        bb = d.multiline_textbbox((0, 0), text, font=fnt, spacing=spacing, align="center")
        tw, th = bb[2] - bb[0], bb[3] - bb[1]
        anchor_xy = ((w - tw) // 2 - bb[0], (h - th) // 2 - bb[1])
    d.multiline_text(anchor_xy, text, font=fnt, fill=fill, spacing=spacing, align="center")
    return np.asarray(im).astype(np.float32) / 255.0


def paste_mask(img, mask, color):
    c = np.array(color, np.float32)
    if c.max() > 1.0:
        c = c / 255.0
    return img * (1 - mask[..., None]) + c * mask[..., None]


def outline(mask, r=1):
    m = mask > 0.5
    o = np.zeros_like(m)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            o |= np.roll(np.roll(m, dy, 0), dx, 1)
    return (o & ~m).astype(np.float32)
