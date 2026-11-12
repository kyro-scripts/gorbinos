"""'Pre-rendered clay' UI art: shiny lumpy sculptures shaded from height
fields (metaballs, bevelled text). Produces the HUD health lump, the DEATH
sculpture, menu tiles, rank letters, the logo, cursor and the app icon.

Run: python3 tools/gen_clay.py -> assets/ui/*.png, icon.png
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from texlib import value_noise, worley, gradmap, rng, ROOT, font

UI = os.path.join(ROOT, "assets", "ui")
os.makedirs(UI, exist_ok=True)


# ------------------------------------------------------------------ core shading
def shade_height(h, base_rgb, mask=None, light=(-0.45, -0.6, 0.66), spec=0.9, shin=30, amb=0.32, rim=0.35, scale=1.0, sss=None):
    """h: height field (H,W) >= 0. base_rgb: (H,W,3) or tuple. Returns RGBA float."""
    H, W = h.shape
    gy, gx = np.gradient(h * scale)
    n = np.dstack([-gx, -gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    L = np.array(light, np.float32)
    L /= np.linalg.norm(L)
    ndl = np.clip((n * L).sum(-1), 0, 1)
    Hv = L + np.array([0, 0, 1.0])
    Hv /= np.linalg.norm(Hv)
    sp = np.clip((n * Hv).sum(-1), 0, 1) ** shin * spec
    rm = (1 - np.clip(n[..., 2], 0, 1)) ** 2 * rim
    if not isinstance(base_rgb, np.ndarray):
        base_rgb = np.ones((H, W, 3), np.float32) * np.array(base_rgb, np.float32) / 255.0
    col = base_rgb * (amb + ndl[..., None] * 0.85) + sp[..., None] + rm[..., None] * np.array([0.6, 0.7, 0.9])
    if sss is not None:
        col += sss
    a = (h > 0.001).astype(np.float32) if mask is None else mask
    return np.dstack([np.clip(col, 0, 1), a])


def metaballs(W, H, balls, noise_amp=0.0, seed=0, thresh=1.0):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    f = np.zeros((H, W), np.float32)
    for (cx, cy, r) in balls:
        f += r * r / ((xx - cx) ** 2 + (yy - cy) ** 2 + 1e-3)
    if noise_amp:
        f *= 1.0 + (value_noise(max(W, H), 8, seed, 4)[:H, :W] - 0.5) * noise_amp
    h = np.sqrt(np.clip(f - thresh, 0, None))
    return h


def text_mask(W, H, text, fname, size, pos=None, spacing=0):
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    f = font(fname, size)
    bb = d.multiline_textbbox((0, 0), text, font=f, spacing=spacing, align="center")
    if pos is None:
        pos = ((W - (bb[2] - bb[0])) // 2 - bb[0], (H - (bb[3] - bb[1])) // 2 - bb[1])
    d.multiline_text(pos, text, font=f, fill=255, spacing=spacing, align="center")
    return np.asarray(im).astype(np.float32) / 255.0


def bevel(mask, radius=6.0):
    """Height field that rises smoothly inside a mask (a rounded bevel)."""
    m = Image.fromarray((mask * 255).astype(np.uint8))
    acc = np.zeros(mask.shape, np.float32)
    for r in np.linspace(1, radius, 6):
        acc += np.asarray(m.filter(ImageFilter.GaussianBlur(float(r)))).astype(np.float32) / 255.0
    acc /= 6.0
    return acc * mask * radius * 0.35


def save(arr, name, size=None):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    if size:
        im = im.resize(size, Image.LANCZOS)
    path = os.path.join(UI, name) if not name.startswith("/") else name
    im.save(path)
    return im


def flesh_base(W, H, seed, stops):
    n = value_noise(max(W, H), 6, seed, 5)[:H, :W]
    d1, _, _ = worley(max(W, H), 30, seed + 1)
    t = np.clip(n * 0.8 + (d1[:H, :W] < 2.5) * -0.2 + 0.1, 0, 1)
    return gradmap(t, stops)


# ------------------------------------------------------------------ HUD health lump
def hp_lump():
    """A pulsing grey-pink lump; 16 frames. Tinted in game by health."""
    W = H = 128
    frames = []
    r = rng(7000)
    base_balls = [(64 + r.uniform(-30, 30), 64 + r.uniform(-28, 28), r.uniform(9, 22)) for _ in range(9)]
    phases = r.uniform(0, 2 * np.pi, len(base_balls))
    stops = [(0, (110, 60, 70)), (0.5, (205, 150, 150)), (1, (245, 215, 205))]
    base = flesh_base(W, H, 7001, stops)
    for f in range(16):
        t = f / 16 * 2 * np.pi
        balls = []
        for (cx, cy, rr), ph in zip(base_balls, phases):
            k = 1.0 + 0.12 * np.sin(t + ph)
            balls.append((cx + 3 * np.cos(t + ph), cy + 3 * np.sin(t * 2 + ph), rr * k))
        h = metaballs(W, H, balls, 0.25, 7002) * 9
        # a stitched vein running across
        frames.append(shade_height(h, base, spec=1.0, shin=40))
    strip = np.concatenate(frames, 1)
    save(strip, "hp_lump.png")


# ------------------------------------------------------------------ DEATH sculpture
def death():
    W, H = 360, 240
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy = W / 2, H / 2
    ang = np.arctan2(yy - cy, (xx - cx) * 0.7)
    rr = np.hypot((xx - cx) * 0.7, yy - cy)
    spikes = 0.62 + 0.38 * np.abs(np.cos(ang * 6.5)) ** 6
    radius = 95 * spikes * (1 + (value_noise(W, 6, 7100, 3)[:H, :W] - 0.5) * 0.25)
    h = np.sqrt(np.clip(1 - (rr / radius) ** 2, 0, None)) * 40
    tm = text_mask(W, H, "DEATH", "Anton-Regular.ttf", 74)
    h = h - bevel(tm, 5) * 4.0
    base = flesh_base(W, H, 7101, [(0, (170, 160, 165)), (1, (245, 240, 238))])
    base = base * (1 - tm[..., None] * 0.85) + np.array([0.42, 0.02, 0.03]) * tm[..., None] * 0.85
    out = shade_height(np.clip(h, 0, None), base, mask=(rr < radius).astype(np.float32), spec=1.0, shin=36)
    save(out, "death.png")


# ------------------------------------------------------------------ rank letters / stamps
def clay_text(text, name, W, H, size, color, fname="Anton-Regular.ttf", pad_noise=True):
    tm = text_mask(W, H, text, fname, size)
    h = bevel(tm, 7)
    if pad_noise:
        h *= 1 + (value_noise(max(W, H), 16, 7200 + len(text), 3)[:H, :W] - 0.5) * 0.4
    base = flesh_base(W, H, 7201 + len(name), [(0, tuple(int(c * 0.5) for c in color)), (1, color)])
    out = shade_height(h * 3, base, mask=(tm > 0.5).astype(np.float32), spec=0.9, shin=28)
    # dark drop shadow
    sh = np.zeros_like(out)
    a = (tm > 0.5).astype(np.float32)
    a2 = np.roll(np.roll(a, 4, 0), 4, 1)
    sh[..., 3] = a2 * 0.7
    comp = sh.copy()
    comp[..., :3] = out[..., :3] * out[..., 3:4] + sh[..., :3] * (1 - out[..., 3:4])
    comp[..., 3] = np.maximum(out[..., 3], sh[..., 3])
    return save(comp, name)


def ranks():
    cols = {"S": (255, 220, 60), "A": (140, 255, 60), "B": (80, 200, 255), "C": (255, 140, 190), "D": (190, 180, 170)}
    for k, c in cols.items():
        clay_text(k, "rank_%s.png" % k, 120, 140, 120, c)
    clay_text("COMPLETE", "stamp_cleared.png", 300, 90, 64, (170, 255, 80))


# ------------------------------------------------------------------ logo
def logo():
    W, H = 640, 220
    tm = text_mask(W, H, "GORBINO'S\nQUEST", "Anton-Regular.ttf", 92, spacing=-12)
    h = bevel(tm, 8) * 3
    h *= 1 + (value_noise(W, 24, 7300, 3)[:H, :W] - 0.5) * 0.5
    base = flesh_base(W, H, 7301, [(0, (120, 40, 0)), (0.5, (255, 120, 20)), (1, (255, 210, 120))])
    # sucker spots on the letters
    d1, _, _ = worley(W, 120, 7302)
    spots = (d1[:H, :W] < 2.2)
    base[spots] *= 0.6
    out = shade_height(h, base, mask=(tm > 0.5).astype(np.float32), spec=1.0, shin=34)
    a = (tm > 0.5).astype(np.float32)
    outline = np.zeros_like(a)
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            outline = np.maximum(outline, np.roll(np.roll(a, dy, 0), dx, 1))
    comp = np.zeros((H, W, 4), np.float32)
    comp[..., 3] = outline
    comp[..., :3] = np.array([0.06, 0.0, 0.02])
    comp[..., :3] = out[..., :3] * a[..., None] + comp[..., :3] * (1 - a[..., None])
    save(comp, "logo.png")


# ------------------------------------------------------------------ menu tiles
def organic_bg(W, H, kind, seed):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    if kind == "worms":
        n = value_noise(max(W, H), 6, seed, 4)[:H, :W]
        t = 0.5 + 0.5 * np.sin(n * 22 + xx * 0.05)
        base = gradmap(t, [(0, (20, 40, 10)), (0.5, (110, 150, 30)), (1, (230, 240, 120))])
        h = (t ** 3) * 6
    elif kind == "flesh":
        base = flesh_base(W, H, seed, [(0, (70, 10, 20)), (0.5, (190, 60, 70)), (1, (255, 170, 150))])
        h = value_noise(max(W, H), 10, seed + 5, 4)[:H, :W] * 8
    elif kind == "veins":
        n = value_noise(max(W, H), 5, seed, 5)[:H, :W]
        t = np.abs(np.sin(n * 18))
        base = gradmap(t, [(0, (10, 20, 60)), (0.6, (40, 90, 200)), (1, (200, 230, 255))])
        h = (1 - t) * 5
    else:
        n = value_noise(max(W, H), 8, seed, 5)[:H, :W]
        base = gradmap(n, [(0, (60, 40, 10)), (1, (220, 170, 60))])
        h = n * 6
    return shade_height(h, base, mask=np.ones((H, W), np.float32), spec=0.5, shin=20)


def icon_height(kind, W, H):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy = W / 2, H / 2 - 6
    if kind == "arrow":
        m = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(m)
        d.polygon([(cx - 30, cy - 12), (cx + 4, cy - 12), (cx + 4, cy - 28), (cx + 36, cy), (cx + 4, cy + 28), (cx + 4, cy + 12), (cx - 30, cy + 12)], fill=255)
        mk = np.asarray(m).astype(np.float32) / 255
        return bevel(mk, 8) * 3, mk
    if kind == "x":
        m = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(m)
        d.line([cx - 26, cy - 26, cx + 26, cy + 26], fill=255, width=17)
        d.line([cx - 26, cy + 26, cx + 26, cy - 26], fill=255, width=17)
        mk = np.asarray(m).astype(np.float32) / 255
        return bevel(mk, 8) * 3, mk
    if kind == "ring":
        r = np.hypot(xx - cx, yy - cy)
        mk = ((r > 18) & (r < 34)).astype(np.float32)
        h = np.sqrt(np.clip(64 - (r - 26) ** 2, 0, None)) * 1.3 * mk
        return h, mk
    if kind == "gear":
        ang = np.arctan2(yy - cy, xx - cx)
        r = np.hypot(xx - cx, yy - cy)
        rad = 28 + 7 * (np.cos(ang * 8) > 0.2)
        mk = ((r < rad) & (r > 11)).astype(np.float32)
        return bevel(mk, 7) * 3, mk
    if kind == "eye":
        r = np.hypot((xx - cx) / 1.6, yy - cy)
        mk = (r < 22).astype(np.float32)
        h = np.sqrt(np.clip(484 - r ** 2, 0, None)) * 0.9
        return h, mk
    if kind == "disk":
        mk = ((np.abs(xx - cx) < 28) & (np.abs(yy - cy) < 28)).astype(np.float32)
        return bevel(mk, 6) * 3, mk
    if kind == "gorbino":
        # a little Gorbino: a glossy ball on two round feet
        h = metaballs(W, H, [(cx, cy - 2, 27), (cx - 13, cy + 27, 9), (cx + 13, cy + 27, 9)], 0.12, 7410) * 8
        return h, (h > 0).astype(np.float32)
    if kind == "face":
        # a lumpy grimacing face
        h = metaballs(W, H, [(cx, cy, 30), (cx - 16, cy - 10, 12), (cx + 16, cy - 10, 12), (cx, cy + 16, 14)], 0.3, 7400) * 8
        return h, (h > 0).astype(np.float32)
    raise ValueError(kind)


def tile(name, label, kind, bgkind, seed, icon_col):
    W = H = 128
    bg = organic_bg(W, H, bgkind, seed)
    h, mk = icon_height(kind, W, H)
    base = flesh_base(W, H, seed + 3, [(0, tuple(int(c * 0.45) for c in icon_col)), (1, icon_col)])
    ic = shade_height(h, base, mask=mk, spec=1.0, shin=36)
    out = bg.copy()
    # icon drop shadow
    sh = np.roll(np.roll(mk, 5, 0), 5, 1)
    out[..., :3] *= 1 - sh[..., None] * 0.6
    out[..., :3] = ic[..., :3] * mk[..., None] + out[..., :3] * (1 - mk[..., None])
    if kind == "eye":
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.hypot(xx - W / 2, yy - (H / 2 - 6))
        out[r < 10, :3] = np.array([0.05, 0.0, 0.0])
        out[(r < 14) & (r >= 10), :3] = np.array([0.8, 0.5, 0.0])
    if kind == "face":
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        for ex in (-13, 13):
            r = np.hypot(xx - (W / 2 + ex), yy - (H / 2 - 15))
            out[r < 8, :3] = np.array([0.95, 0.75, 0.1])
            out[(r < 8) & (np.abs(yy - (H / 2 - 15)) < 2), :3] = np.array([0.02, 0.0, 0.0])
            out[(r >= 8) & (r < 9.5), :3] = np.array([0.6, 0.05, 0.05])
        my = H / 2 + 10
        out[(np.abs(yy - my) < 6) & (np.abs(xx - W / 2) < 17), :3] = np.array([0.18, 0.0, 0.03])
        for tx in range(int(W / 2 - 15), int(W / 2 + 15), 5):
            out[(yy > my - 6) & (yy < my - 1) & (xx >= tx) & (xx < tx + 4), :3] = np.array([0.9, 0.85, 0.55])
            out[(yy > my + 1) & (yy < my + 5) & (xx >= tx + 2) & (xx < tx + 5), :3] = np.array([0.85, 0.8, 0.5])
    # label: embossed text at the bottom
    lm = text_mask(W, H, label, "Anton-Regular.ttf", 22, pos=None)
    lm = np.roll(lm, int(H * 0.36), 0)
    lh = bevel(lm, 3) * 2
    lab = shade_height(lh, (245, 240, 220), mask=(lm > 0.5).astype(np.float32), spec=0.6)
    a = (lm > 0.5).astype(np.float32)
    outl = np.zeros_like(a)
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            outl = np.maximum(outl, np.roll(np.roll(a, dy, 0), dx, 1))
    out[..., :3] = out[..., :3] * (1 - outl[..., None]) + np.array([0.04, 0.0, 0.03]) * outl[..., None]
    out[..., :3] = lab[..., :3] * a[..., None] + out[..., :3] * (1 - a[..., None])
    # hard frame
    out[:3, :, :3] = 0.04
    out[-3:, :, :3] = 0.04
    out[:, :3, :3] = 0.04
    out[:, -3:, :3] = 0.04
    out[..., 3] = 1
    save(out, "tile_%s.png" % name)


def tiles():
    tile("new", "NEW QUEST", "face", "flesh", 7500, (255, 140, 40))
    tile("continue", "CONTINUE", "arrow", "veins", 7510, (120, 255, 60))
    tile("options", "OPTIONS", "gear", "worms", 7520, (120, 180, 255))
    tile("exit", "EXIT", "x", "flesh", 7530, (130, 255, 60))
    tile("resume", "RESUME", "arrow", "worms", 7540, (255, 120, 40))
    tile("save", "SAVE", "disk", "veins", 7550, (255, 220, 60))
    tile("load", "LOAD", "eye", "gold", 7560, (240, 230, 220))
    tile("retry", "RESTART", "ring", "gold", 7570, (200, 120, 90))
    tile("quit", "QUIT", "x", "veins", 7580, (255, 60, 60))


# ------------------------------------------------------------------ menu buttons
BUTTONS = [
    ("new", "NEW QUEST", "image:icon_new_face.png", (255, 60, 60)),
    ("continue", "CONTINUE", "arrow", (120, 255, 60)),
    ("endless", "ENDLESS", "ring", (230, 80, 255)),
    ("options", "OPTIONS", "gear", (120, 180, 255)),
    ("exit", "EXIT", "x", (130, 255, 60)),
    ("resume", "RESUME", "arrow", (255, 120, 40)),
    ("save", "SAVE", "disk", (255, 220, 60)),
    ("load", "LOAD", "eye", (240, 230, 220)),
    ("retry", "RESTART", "ring", (200, 120, 90)),
    ("quit", "QUIT", "x", (255, 60, 60)),
]


def _grow(a, r):
    out = a.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out = np.maximum(out, np.roll(np.roll(a, dy, 0), dx, 1))
    return out


def clay_button(name, label, kind, icon_col, seed, hot):
    """A lumpy, glossy clay slab with the icon sculpted on the left and the
    label in the logo's orange clay letters. hot: the chosen one, lit up
    pink with a lime rim."""
    W, H = 440, 104
    # the slab: a rounded bar whose edges have been squashed lumpy by hand
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([12, 12, W - 12, H - 12], radius=34, fill=255)
    mb = np.asarray(m.filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255.0
    lump = value_noise(max(W, H), 10, seed, 3)[:H, :W] - 0.5
    slab = ((mb + lump * 0.45) > 0.5).astype(np.float32)
    h = bevel(slab, 12) * 3
    h *= 1 + (value_noise(max(W, H), 22, seed + 1, 3)[:H, :W] - 0.5) * 0.5
    if hot:
        stops = [(0, (130, 20, 60)), (0.5, (245, 80, 135)), (1, (255, 185, 205))]
    else:
        stops = [(0, (36, 6, 22)), (0.5, (105, 28, 58)), (1, (175, 80, 110))]
    base = flesh_base(W, H, seed + 2, stops)
    d1, _, _ = worley(max(W, H), 60, seed + 3)
    base[(d1[:H, :W] < 2.0)] *= 0.62
    body = shade_height(h, base, mask=slab, spec=0.9, shin=30)
    out = np.zeros((H, W, 4), np.float32)
    # soft drop shadow, and the lime rim when it's chosen
    sh = np.roll(np.roll(slab, 6, 0), 5, 1)
    out[..., 3] = sh * 0.6
    if hot:
        rim = _grow(slab, 5)
        out[..., :3] = out[..., :3] * (1 - rim[..., None]) + np.array([0.75, 1.0, 0.1]) * rim[..., None]
        out[..., 3] = np.maximum(out[..., 3], rim)
    out[..., :3] = body[..., :3] * slab[..., None] + out[..., :3] * (1 - slab[..., None])
    out[..., 3] = np.maximum(out[..., 3], slab)
    # the icon, sculpted on the left (or a supplied picture, pasted on)
    if kind.startswith("image:"):
        pic = Image.open(os.path.join(UI, kind[6:])).convert("RGBA").resize((H + 6, H + 6), Image.LANCZOS)
        pa = np.asarray(pic).astype(np.float32) / 255.0
        iw = np.zeros((H, W)); icn = np.zeros((H, W, 3))
        iw[:, 8:8 + H] = pa[3:3 + H, 3:3 + H, 3]
        icn[:, 8:8 + H] = pa[3:3 + H, 3:3 + H, :3]
        ish = np.roll(np.roll((iw > 0.5).astype(np.float32), 4, 0), 4, 1) * slab
        out[..., :3] *= 1 - ish[..., None] * 0.45
        out[..., :3] = icn * iw[..., None] + out[..., :3] * (1 - iw[..., None])
        out[..., 3] = np.maximum(out[..., 3], iw)
    else:
        _sculpt_icon(out, slab, kind, icon_col, seed, W, H)
    _clay_label(out, label, seed, hot, W, H)
    save(out, "btn_%s%s.png" % (name, "_on" if hot else ""))


def _sculpt_icon(out, slab, kind, icon_col, seed, W, H):
    ih, imk = icon_height(kind, H, H)
    ibase = flesh_base(H, H, seed + 4, [(0, tuple(int(c * 0.45) for c in icon_col)), (1, icon_col)])
    ic = shade_height(ih, ibase, mask=imk, spec=1.0, shin=36)
    iw = np.zeros((H, W)); iw[:, 14:14 + H] = imk
    icn = np.zeros((H, W, 3)); icn[:, 14:14 + H] = ic[..., :3]
    ish = np.roll(np.roll(iw, 4, 0), 4, 1) * slab
    out[..., :3] *= 1 - ish[..., None] * 0.55
    if kind == "eye":
        yy, xx = np.mgrid[0:H, 0:H].astype(np.float32)
        r = np.hypot(xx - H / 2, yy - (H / 2 - 6))
        icn[:, 14:14 + H][r < 10] = (0.05, 0.0, 0.0)
        icn[:, 14:14 + H][(r < 14) & (r >= 10)] = (0.8, 0.5, 0.0)
    if kind == "gorbino":
        # big glassy eyes and a little mouth
        yy, xx = np.mgrid[0:H, 0:H].astype(np.float32)
        sub = icn[:, 14:14 + H]
        ey = H / 2 - 14
        for ex in (-10, 10):
            r = np.hypot(xx - (H / 2 + ex), yy - ey)
            sub[r < 8.5] = (0.03, 0.02, 0.02)
            sub[r < 7] = (0.95, 0.93, 0.85)
            rp = np.hypot(xx - (H / 2 + ex + 1.5), yy - (ey + 1))
            sub[rp < 3.6] = (0.02, 0.02, 0.03)
            sub[np.hypot(xx - (H / 2 + ex - 2), yy - (ey - 3)) < 1.6] = (1, 1, 1)
        my = H / 2 + 4
        sub[(np.abs(yy - my) < 1.6) & (np.abs(xx - H / 2) < 7)] = (0.12, 0.02, 0.04)
    if kind == "face":
        yy, xx = np.mgrid[0:H, 0:H].astype(np.float32)
        sub = icn[:, 14:14 + H]
        for ex in (-13, 13):
            r = np.hypot(xx - (H / 2 + ex), yy - (H / 2 - 15))
            sub[r < 8] = (0.95, 0.75, 0.1)
            sub[(r < 8) & (np.abs(yy - (H / 2 - 15)) < 2)] = (0.02, 0.0, 0.0)
        my = H / 2 + 10
        sub[(np.abs(yy - my) < 6) & (np.abs(xx - H / 2) < 17)] = (0.18, 0.0, 0.03)
    out[..., :3] = icn * iw[..., None] + out[..., :3] * (1 - iw[..., None])


def _clay_label(out, label, seed, hot, W, H):
    # the label, in the logo's clay letters
    f = font("Anton-Regular.ttf", 56)
    tmp = Image.new("L", (W, H), 0)
    bb = ImageDraw.Draw(tmp).textbbox((0, 0), label, font=f)
    tm = text_mask(W, H, label, "Anton-Regular.ttf", 56, pos=(122 - bb[0], (H - (bb[3] - bb[1])) // 2 - bb[1] - 2))
    a = (tm > 0.5).astype(np.float32)
    th = bevel(tm, 5) * 3
    th *= 1 + (value_noise(max(W, H), 24, seed + 5, 3)[:H, :W] - 0.5) * 0.4
    if hot:
        lstops = [(0, (160, 80, 0)), (0.5, (255, 200, 50)), (1, (255, 250, 180))]
    else:
        lstops = [(0, (120, 40, 0)), (0.5, (255, 120, 20)), (1, (255, 210, 120))]
    lab = shade_height(th, flesh_base(W, H, seed + 6, lstops), mask=a, spec=1.0, shin=34)
    outl = _grow(a, 3)
    lsh = np.roll(np.roll(outl, 3, 0), 3, 1)
    out[..., :3] *= 1 - lsh[..., None] * 0.5
    out[..., :3] = out[..., :3] * (1 - outl[..., None]) + np.array([0.06, 0.0, 0.02]) * outl[..., None]
    out[..., :3] = lab[..., :3] * a[..., None] + out[..., :3] * (1 - a[..., None])
    out[..., 3] = np.maximum(out[..., 3], outl)


def buttons():
    for k, (name, label, kind, col) in enumerate(BUTTONS):
        for hot in (False, True):
            clay_button(name, label, kind, col, 7600 + k * 10, hot)


# ------------------------------------------------------------------ backgrounds, border
def menu_bg():
    W = 128
    out = organic_bg(W, W, "worms", 7600)
    out[..., :3] *= 0.55
    save(out, "menu_bg.png")
    out = organic_bg(W, W, "flesh", 7601)
    out[..., :3] *= 0.45
    save(out, "menu_bg2.png")


def border():
    """Thin noisy multicolour frame drawn around the game view."""
    W, H = 256, 144
    r = rng(7700)
    a = np.zeros((H, W, 4), np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    edge = np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy))
    thick = 3 + (value_noise(256, 16, 7701, 2)[:H, :W] * 4)
    m = edge < thick
    cols = np.array([[1, 0.2, 0.3], [0.2, 1, 0.3], [0.3, 0.4, 1], [1, 0.9, 0.2], [0.05, 0.05, 0.05]])
    pick = r.integers(0, len(cols), (H, W))
    a[m, :3] = cols[pick[m]]
    a[m, 3] = 0.9
    save(a, "border.png")


# ------------------------------------------------------------------ cursor & icon
def cursor():
    """A green pointing hand, drawn pixel by pixel."""
    rows = [
        "......GG........",
        ".....GwwG.......",
        ".....GwwG.......",
        ".....GwwG.......",
        ".....GwwGGG.....",
        ".....GwwGwwGG...",
        "..GG.GwwGwwGwG..",
        ".GwwGGwwGwwGwwG.",
        ".GwwwGwwwwwwwwG.",
        "..GwwwwwwwwwwwG.",
        "...GwwwwwwwwwwG.",
        "...GwwwwwwwwwG..",
        "....GwwwwwwwwG..",
        "....GwwwwwwwG...",
        ".....GwwwwwwG...",
        ".....GGGGGGGG...",
    ]
    S = 2
    im = Image.new("RGBA", (16 * S, 16 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "G":
                d.rectangle([x * S, y * S, x * S + S - 1, y * S + S - 1], fill=(10, 60, 0, 255))
            elif c == "w":
                g = 200 + (x * 7 + y * 3) % 50
                d.rectangle([x * S, y * S, x * S + S - 1, y * S + S - 1], fill=(40, g, 30, 255))
    im.save(os.path.join(UI, "cursor_hand.png"))


def app_icon():
    """Orange octopus head for the window / taskbar icon."""
    W = H = 256
    balls = [(128, 100, 70), (100, 70, 30), (160, 75, 28)]
    for k in range(6):
        a = np.pi * (0.15 + 0.7 * k / 5)
        for s in range(4):
            balls.append((128 + np.cos(a) * (60 + s * 22), 140 + np.sin(a) * (50 + s * 18), 16 - s * 3))
    h = metaballs(W, H, balls, 0.2, 7800) * 10
    base = flesh_base(W, H, 7801, [(0, (110, 35, 0)), (0.5, (255, 120, 20)), (1, (255, 210, 130))])
    out = shade_height(h, base, spec=1.0, shin=36)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    for ex in (-30, 30):
        r = np.hypot(xx - (128 + ex), yy - 112)
        out[r < 20, :3] = np.array([0.95, 0.9, 0.75])
        out[(np.abs(yy - 112) < 4) & (np.abs(xx - (128 + ex)) < 13), :3] = np.array([0.02, 0.0, 0.0])
        out[np.hypot(xx - (122 + ex), yy - 104) < 4, :3] = 1.0
    out[(np.abs(yy - 150) < 6) & (np.abs(xx - 128) < 26), :3] = np.array([0.25, 0.0, 0.05])
    for tx in range(106, 150, 9):
        out[(yy > 145) & (yy < 151) & (xx >= tx) & (xx < tx + 6), :3] = np.array([0.9, 0.85, 0.6])
    save(out, os.path.join(ROOT, "icon.png"), (128, 128))
    save(out, "app_icon_256.png")


def hud_jar():
    """Specimen jar for the health display: glass with highlights and
    shiny metal caps; the interior is left mostly transparent so the HUD can
    draw the fluid behind it.  Interior box: x 16..64, y 22..118 of 80x140."""
    W, H = 80, 140
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    out = np.zeros((H, W, 4), np.float32)
    # glass walls: thin rounded rim with vertical streak highlights
    inner = (xx >= 16) & (xx < 64) & (yy >= 20) & (yy < 120)
    wall = (xx >= 12) & (xx < 68) & (yy >= 18) & (yy < 122) & ~inner
    out[wall] = [0.75, 0.9, 0.85, 0.55]
    for x0, a in ((19, 0.35), (22, 0.18), (57, 0.12)):
        m = inner & (np.abs(xx - x0) < 1.2)
        out[m] = [1.0, 1.0, 1.0, a]
    out[inner & (out[..., 3] == 0)] = [0.6, 0.85, 0.8, 0.07]
    # caps: shaded cylinders in tarnished metal
    for (y0, y1) in ((4, 22), (118, 136)):
        h = np.zeros((H, W), np.float32)
        m = (xx >= 8) & (xx < 72) & (yy >= y0) & (yy < y1)
        u = (xx - 40) / 32.0
        h[m] = np.sqrt(np.clip(1 - u[m] ** 2, 0, 1)) * 8
        base = flesh_base(W, H, 7900 + y0, [(0, (60, 50, 40)), (0.5, (150, 130, 95)), (1, (220, 205, 170))])
        cap = shade_height(h, base, mask=m.astype(np.float32), spec=1.0, shin=24)
        out[m] = cap[m]
        for bx in (14, 40, 66):
            b = np.hypot(xx - bx, yy - (y0 + y1) / 2) < 2.2
            out[b] = [0.2, 0.17, 0.12, 1]
    # dark outline
    a = (out[..., 3] > 0.3).astype(np.float32)
    ol = np.zeros_like(a)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ol = np.maximum(ol, np.roll(np.roll(a, dy, 0), dx, 1))
    edge = (ol > 0) & (a == 0)
    out[edge] = [0.03, 0.02, 0.02, 1]
    save(out, "hud_jar.png")


def hud_gorb():
    """The little specimen floating in the jar: a glossy dark blob."""
    W = H = 48
    h = metaballs(W, H, [(24, 22, 15), (14, 36, 6), (24, 38, 6), (34, 36, 6)], 0.2, 7950) * 6
    base = flesh_base(W, H, 7951, [(0, (10, 20, 5)), (1, (60, 95, 30))])
    out = shade_height(h, base, spec=1.2, shin=30)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    for ex in (-6, 6):
        out[np.hypot(xx - (24 + ex), yy - 20) < 2.8, :3] = 0.02
        out[np.hypot(xx - (23 + ex), yy - 19) < 1.0, :3] = 0.9
    save(out, "hud_gorb.png")


if __name__ == "__main__":
    hud_jar()
    hud_gorb()
    death()
    ranks()
    logo()
    tiles()
    buttons()
    menu_bg()
    border()
    cursor()
    app_icon()
    print("clay ui written")
